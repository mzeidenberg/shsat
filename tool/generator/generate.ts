import Anthropic from "@anthropic-ai/sdk";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { Choice, Passage, Question, QuestionType, Subject } from "./types.js";
import { buildInstruction, SYSTEM_PROMPT } from "./prompts.js";
import { contentHash, readJsonArray, writeJsonArray } from "./util.js";
import { deterministicMathCheck, verifyWithIndependentModel } from "./verify.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const STAGING_DIR = join(ROOT, "tool", "generator", "staging");
const ASSETS_DIR = join(ROOT, "assets", "questions");

const GENERATOR_MODEL = process.env.GENERATOR_MODEL ?? "claude-sonnet-5";
const VERIFIER_MODEL = process.env.VERIFIER_MODEL ?? "claude-opus-4-8";

const MATH_TYPES: QuestionType[] = ["arithmetic_word_problem", "algebra_equation"];

interface RawQuestion {
  prompt: string;
  choices: Choice[];
  answer_key: string;
  explanation: string;
  difficulty: "easy" | "medium" | "hard";
  check_expression?: string;
}

function parseArgs() {
  const args = process.argv.slice(2);
  const get = (flag: string) => {
    const idx = args.indexOf(flag);
    return idx >= 0 ? args[idx + 1] : undefined;
  };
  const subject = get("--subject") as Subject | undefined;
  const type = get("--type") as QuestionType | undefined;
  const count = Number(get("--count") ?? "10");
  if (!subject || !type) {
    console.error("Usage: npm run generate -- --subject <math|ela> --type <type> --count <n>");
    process.exit(1);
  }
  return { subject, type, count };
}

function questionSchema(type: QuestionType) {
  const choiceSchema = {
    type: "object",
    properties: { key: { type: "string" }, text: { type: "string" } },
    required: ["key", "text"],
  };
  const base = {
    type: "object",
    properties: {
      prompt: { type: "string" },
      choices: { type: "array", items: choiceSchema, minItems: 4, maxItems: 4 },
      answer_key: { type: "string" },
      explanation: { type: "string" },
      difficulty: { type: "string", enum: ["easy", "medium", "hard"] },
      ...(MATH_TYPES.includes(type) ? { check_expression: { type: "string" } } : {}),
    },
    required: [
      "prompt",
      "choices",
      "answer_key",
      "explanation",
      "difficulty",
      ...(MATH_TYPES.includes(type) ? ["check_expression"] : []),
    ],
  };

  if (type === "reading_comprehension") {
    return {
      type: "object",
      properties: {
        passage: {
          type: "object",
          properties: { title: { type: "string" }, text: { type: "string" } },
          required: ["title", "text"],
        },
        questions: { type: "array", items: base },
      },
      required: ["passage", "questions"],
    };
  }

  return {
    type: "object",
    properties: { questions: { type: "array", items: base } },
    required: ["questions"],
  };
}

async function generateBatch(
  client: Anthropic,
  subject: Subject,
  type: QuestionType,
  count: number
): Promise<{ passage?: { title: string; text: string }; raw: RawQuestion[] }> {
  const response = await client.messages.create({
    model: GENERATOR_MODEL,
    max_tokens: 8192,
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: buildInstruction(type, count) }],
    tools: [
      {
        name: "emit_batch",
        description: "Emit the generated batch of questions.",
        input_schema: questionSchema(type) as Anthropic.Tool.InputSchema,
      },
    ],
    tool_choice: { type: "tool", name: "emit_batch" },
  });

  const toolUse = response.content.find((b) => b.type === "tool_use");
  if (!toolUse || toolUse.type !== "tool_use") {
    throw new Error("Model did not return a tool call");
  }
  const input = toolUse.input as any;
  if (type === "reading_comprehension") {
    return { passage: input.passage, raw: input.questions ?? [] };
  }
  return { raw: input.questions ?? [] };
}

async function nextSeq(subject: Subject, type: QuestionType): Promise<number> {
  const staging = await readJsonArray<Question>(join(STAGING_DIR, `${subject}-${type}.json`));
  const shipped = await readJsonArray<Question>(join(ASSETS_DIR, subject, `${type}.json`));
  return staging.length + shipped.length;
}

async function existingHashes(subject: Subject, type: QuestionType): Promise<Set<string>> {
  const staging = await readJsonArray<Question>(join(STAGING_DIR, `${subject}-${type}.json`));
  const shipped = await readJsonArray<Question>(join(ASSETS_DIR, subject, `${type}.json`));
  return new Set([...staging, ...shipped].map((q) => q.metadata.content_hash));
}

async function main() {
  const { subject, type, count } = parseArgs();
  const client = new Anthropic();

  console.log(`Generating ${count} ${subject}/${type} question(s) with ${GENERATOR_MODEL}...`);
  const { passage, raw } = await generateBatch(client, subject, type, count);

  const seenHashes = await existingHashes(subject, type);
  let seq = await nextSeq(subject, type);

  let passageId: string | null = null;
  if (type === "reading_comprehension" && passage) {
    const passages = await readJsonArray<Passage>(join(ASSETS_DIR, "ela", "passages.json"));
    const stagingPassages = await readJsonArray<Passage>(join(STAGING_DIR, "ela-passages.json"));
    const passageSeq = passages.length + stagingPassages.length;
    passageId = `ela-passage-${String(passageSeq).padStart(6, "0")}`;
    stagingPassages.push({
      id: passageId,
      title: passage.title,
      text: passage.text,
      word_count: passage.text.trim().split(/\s+/).length,
    });
    await writeJsonArray(join(STAGING_DIR, "ela-passages.json"), stagingPassages);
    console.log(`  wrote 1 new passage -> staging/ela-passages.json (${passageId})`);
  }

  const staged: Question[] = await readJsonArray(join(STAGING_DIR, `${subject}-${type}.json`));
  let added = 0;
  let skippedDup = 0;
  let failedDeterministic = 0;
  let failedVerifier = 0;

  for (const q of raw) {
    const malformed =
      !q.prompt ||
      !Array.isArray(q.choices) ||
      q.choices.length !== 4 ||
      q.choices.some((c) => !c.key || !c.text) ||
      !q.answer_key ||
      !q.explanation;
    if (malformed) {
      console.warn("  skipping malformed question from model output");
      continue;
    }

    const hash = contentHash(q.prompt, q.choices);
    if (seenHashes.has(hash)) {
      skippedDup++;
      continue;
    }
    seenHashes.add(hash);

    let deterministicOk: boolean | null = null;
    if (MATH_TYPES.includes(type) && q.check_expression) {
      try {
        deterministicOk = deterministicMathCheck(q.check_expression, q.choices, q.answer_key);
      } catch (err) {
        console.warn(`  deterministic check errored: ${(err as Error).message}`);
        deterministicOk = false;
      }
      if (!deterministicOk) failedDeterministic++;
    }

    const verifierAgreed = await verifyWithIndependentModel(
      client,
      VERIFIER_MODEL,
      q.prompt,
      q.choices,
      q.answer_key,
      passage?.text
    );
    if (!verifierAgreed) failedVerifier++;

    const id = `${subject}-${type}-${String(seq).padStart(6, "0")}`;
    seq++;

    const question: Question = {
      id,
      subject,
      type,
      difficulty: q.difficulty,
      passage_id: passageId,
      prompt: q.prompt,
      choices: q.choices,
      answer_key: q.answer_key,
      explanation: q.explanation,
      ...(q.check_expression ? { check_expression: q.check_expression } : {}),
      metadata: {
        content_hash: hash,
        generator_model: GENERATOR_MODEL,
        generated_at: new Date().toISOString(),
        verifier_model: VERIFIER_MODEL,
        deterministic_check_passed: deterministicOk,
        verifier_agreed: verifierAgreed,
        reviewed: false,
        reviewer: null,
      },
    };
    staged.push(question);
    added++;
  }

  await writeJsonArray(join(STAGING_DIR, `${subject}-${type}.json`), staged);

  console.log(
    `Done. Added ${added} new question(s) to staging/${subject}-${type}.json ` +
      `(skipped ${skippedDup} duplicate(s), ${failedDeterministic} failed deterministic check, ` +
      `${failedVerifier} failed independent verifier).`
  );
  console.log("Review each entry, set metadata.reviewed = true for correct ones, then run:");
  console.log(`  npm run promote -- --subject ${subject} --type ${type}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
