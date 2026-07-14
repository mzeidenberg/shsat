import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { Passage, Question, QuestionType } from "./types.js";
import { hasLeakedArtifact, looksTruncated, readJsonArray } from "./util.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ASSETS_DIR = join(ROOT, "assets", "questions");

const EXPECTED_SUBJECT: Record<QuestionType, "math" | "ela"> = {
  arithmetic_word_problem: "math",
  algebra_equation: "math",
  grammar_edit: "ela",
  reading_comprehension: "ela",
};

const FILES: Array<{ subject: "math" | "ela"; type: QuestionType }> = [
  { subject: "math", type: "arithmetic_word_problem" },
  { subject: "math", type: "algebra_equation" },
  { subject: "ela", type: "grammar_edit" },
  { subject: "ela", type: "reading_comprehension" },
];

async function main() {
  const errors: string[] = [];

  const passages = await readJsonArray<Passage>(join(ASSETS_DIR, "ela", "passages.json"));
  const passageIds = new Set(passages.map((p) => p.id));

  for (const p of passages) {
    const where = `passage/${p.id}`;
    if (!p.title?.trim()) errors.push(`${where}: blank title`);
    if (!p.text?.trim()) errors.push(`${where}: blank text`);
    if (hasLeakedArtifact(p.title ?? "")) errors.push(`${where}: title has a leaked artifact`);
    if (hasLeakedArtifact(p.text ?? "")) errors.push(`${where}: text has a leaked artifact`);
    if (looksTruncated(p.text ?? "")) errors.push(`${where}: text looks truncated (no terminal punctuation)`);
  }

  const allQuestions: Question[] = [];
  for (const { subject, type } of FILES) {
    const questions = await readJsonArray<Question>(join(ASSETS_DIR, subject, `${type}.json`));
    allQuestions.push(...questions);

    for (const q of questions) {
      const where = `${type}/${q.id}`;

      if (q.subject !== EXPECTED_SUBJECT[type]) {
        errors.push(`${where}: subject "${q.subject}" doesn't match expected "${EXPECTED_SUBJECT[type]}"`);
      }
      if (q.type !== type) {
        errors.push(`${where}: type field "${q.type}" doesn't match file's type "${type}"`);
      }
      if (!q.prompt?.trim()) errors.push(`${where}: blank prompt`);
      if (!q.explanation?.trim()) errors.push(`${where}: blank explanation`);
      if (!["easy", "medium", "hard"].includes(q.difficulty)) {
        errors.push(`${where}: invalid difficulty "${q.difficulty}"`);
      }
      if (hasLeakedArtifact(q.prompt ?? "")) errors.push(`${where}: prompt has a leaked artifact`);
      if (hasLeakedArtifact(q.explanation ?? "")) errors.push(`${where}: explanation has a leaked artifact`);

      if (!Array.isArray(q.choices) || q.choices.length !== 4) {
        errors.push(`${where}: expected exactly 4 choices, got ${q.choices?.length ?? "none"}`);
      } else {
        const keys = q.choices.map((c) => c.key);
        const expectedKeys = ["A", "B", "C", "D"];
        if (!expectedKeys.every((k) => keys.includes(k)) || new Set(keys).size !== 4) {
          errors.push(`${where}: choice keys are not exactly {A,B,C,D}, got [${keys.join(",")}]`);
        }
        if (q.choices.some((c) => !c.text?.trim())) {
          errors.push(`${where}: a choice has blank text`);
        }
        if (q.choices.some((c) => hasLeakedArtifact(c.text ?? ""))) {
          errors.push(`${where}: a choice has a leaked artifact`);
        }
        if (!keys.includes(q.answer_key)) {
          errors.push(`${where}: answer_key "${q.answer_key}" doesn't match any choice key`);
        }
      }

      if (type === "reading_comprehension") {
        if (!q.passage_id) {
          errors.push(`${where}: reading_comprehension question missing passage_id`);
        } else if (!passageIds.has(q.passage_id)) {
          errors.push(`${where}: passage_id "${q.passage_id}" doesn't exist in passages.json`);
        }
      } else if (q.passage_id) {
        errors.push(`${where}: non-reading-comprehension question unexpectedly has a passage_id`);
      }
    }
  }

  const idCounts = new Map<string, number>();
  const hashCounts = new Map<string, number>();
  for (const q of allQuestions) {
    idCounts.set(q.id, (idCounts.get(q.id) ?? 0) + 1);
    const hash = q.metadata?.content_hash;
    if (hash) hashCounts.set(hash, (hashCounts.get(hash) ?? 0) + 1);
  }
  for (const [id, count] of idCounts) {
    if (count > 1) errors.push(`duplicate question id "${id}" appears ${count} times`);
  }
  for (const [hash, count] of hashCounts) {
    if (count > 1) errors.push(`duplicate content_hash ${hash} appears ${count} times (near-identical questions)`);
  }

  const passageIdCounts = new Map<string, number>();
  for (const p of passages) {
    passageIdCounts.set(p.id, (passageIdCounts.get(p.id) ?? 0) + 1);
  }
  for (const [id, count] of passageIdCounts) {
    if (count > 1) errors.push(`duplicate passage id "${id}" appears ${count} times`);
  }

  const referencedPassageIds = new Set(
    allQuestions.filter((q) => q.passage_id).map((q) => q.passage_id as string)
  );
  for (const p of passages) {
    if (!referencedPassageIds.has(p.id)) {
      errors.push(`passage "${p.id}" is not referenced by any promoted question (orphaned)`);
    }
  }

  console.log(`Checked ${allQuestions.length} questions across ${FILES.length} files, ${passages.length} passages.`);
  if (errors.length === 0) {
    console.log("No issues found.");
    return;
  }

  console.error(`\n${errors.length} issue(s) found:`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
