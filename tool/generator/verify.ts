import Anthropic from "@anthropic-ai/sdk";
import type { Choice } from "./types.js";

/** Evaluates a restricted arithmetic expression (digits, + - * / ( ) . and whitespace only). */
export function evalArithmetic(expr: string): number {
  if (!/^[\d+\-*/().\s]+$/.test(expr)) {
    throw new Error(`Unsafe or invalid check_expression: ${expr}`);
  }
  // eslint-disable-next-line no-new-func
  const value = Function(`"use strict"; return (${expr});`)();
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`check_expression did not evaluate to a finite number: ${expr}`);
  }
  return value;
}

function parseNumericChoice(text: string): number | null {
  const match = text.replace(/[,$%\s]/g, "").match(/-?\d+(\.\d+)?/);
  return match ? Number(match[0]) : null;
}

/** Confirms the check_expression's numeric result matches the labeled correct choice. */
export function deterministicMathCheck(
  checkExpression: string,
  choices: Choice[],
  answerKey: string
): boolean {
  const correctChoice = choices.find((c) => c.key === answerKey);
  if (!correctChoice) return false;
  const expected = parseNumericChoice(correctChoice.text);
  if (expected === null) return false;
  const actual = evalArithmetic(checkExpression);
  return Math.abs(actual - expected) < 1e-6;
}

/** Independent second-pass LLM check: solves from prompt+choices alone, no access to the
 * generator's reasoning, and reports whether it agrees with answer_key. */
export async function verifyWithIndependentModel(
  client: Anthropic,
  model: string,
  prompt: string,
  choices: Choice[],
  answerKey: string,
  passageText?: string
): Promise<boolean> {
  const choiceLines = choices.map((c) => `${c.key}. ${c.text}`).join("\n");
  const userText = passageText
    ? `Passage:\n${passageText}\n\nQuestion:\n${prompt}\n\n${choiceLines}`
    : `Question:\n${prompt}\n\n${choiceLines}`;

  const response = await client.messages.create({
    model,
    max_tokens: 1024,
    system:
      "Solve this multiple-choice SHSAT practice question yourself and pick the single best " +
      "answer. Think it through, then call the report_answer tool with only the final letter.",
    messages: [{ role: "user", content: userText }],
    tools: [
      {
        name: "report_answer",
        description: "Report the final chosen answer letter.",
        input_schema: {
          type: "object",
          properties: {
            answer_key: { type: "string", description: "The letter of the chosen answer, e.g. A" },
          },
          required: ["answer_key"],
        },
      },
    ],
    tool_choice: { type: "tool", name: "report_answer" },
  });

  const toolUse = response.content.find((block) => block.type === "tool_use");
  if (!toolUse || toolUse.type !== "tool_use") return false;
  const input = toolUse.input as { answer_key: string };
  return input.answer_key.trim().toUpperCase() === answerKey.trim().toUpperCase();
}
