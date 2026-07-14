import { createHash } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import type { Choice } from "./types.js";

export function contentHash(prompt: string, choices: Choice[]): string {
  const normalized = JSON.stringify({
    prompt: prompt.trim().toLowerCase().replace(/\s+/g, " "),
    choices: choices
      .map((c) => c.text.trim().toLowerCase().replace(/\s+/g, " "))
      .sort(),
  });
  return "sha256:" + createHash("sha256").update(normalized).digest("hex");
}

export async function readJsonArray<T>(path: string): Promise<T[]> {
  try {
    const raw = await readFile(path, "utf-8");
    return JSON.parse(raw) as T[];
  } catch (err: any) {
    if (err.code === "ENOENT") return [];
    throw err;
  }
}

export async function writeJsonArray<T>(path: string, items: T[]): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, JSON.stringify(items, null, 2) + "\n", "utf-8");
}

/**
 * Detects text corrupted by leaked model-internal artifacts: HTML/XML-ish
 * closing tags (`</p>`, `</passage>`, `</parameter>`) and leaked JSON/dict
 * fragments (e.g. `', 'title':'...`, `};{`) that occasionally bleed into
 * generated content. Observed in ~35% of a large passage-generation batch.
 */
export function hasLeakedArtifact(text: string): boolean {
  return (
    /<\//.test(text) ||
    /\};\{/.test(text) ||
    /['"]\s*,\s*['"]?\s*$/.test(text.trimEnd()) ||
    /['"]\s*,\s*['"]\w+['"]?\s*:/.test(text)
  );
}

/** For longer prose (passages): flags text that stops mid-sentence rather
 * than ending on terminal punctuation — a sign of truncated generation. */
export function looksTruncated(text: string): boolean {
  const trimmed = text.trim();
  return trimmed.length > 0 && !/[.!?"'”’)]$/.test(trimmed);
}

const STOPWORDS = new Set([
  "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for", "with",
  "is", "are", "was", "were", "this", "that", "these", "those", "it", "its",
  "as", "by", "from", "at", "be", "has", "have", "had", "which", "what",
  "how", "why", "their", "them", "they", "does", "did", "than", "then",
  "into", "about", "over", "when", "who", "whom", "such", "each", "based",
  "according", "passage", "author", "best", "most", "likely", "following",
  "question", "answer", "choice", "choices", "would", "could", "should",
  "not", "also", "more", "some", "any", "all", "one", "two", "can", "will",
]);

/** Words appearing 2+ times in [text], excluding common stopwords and short
 * words — a cheap proxy for "what this text is actually about". */
export function significantWords(text: string): Set<string> {
  const counts = new Map<string, number>();
  for (const raw of text.toLowerCase().match(/[a-z]+/g) ?? []) {
    if (raw.length < 4 || STOPWORDS.has(raw)) continue;
    counts.set(raw, (counts.get(raw) ?? 0) + 1);
  }
  return new Set([...counts.entries()].filter(([, c]) => c >= 2).map(([w]) => w));
}

/**
 * Checks that [questionText] (prompt + explanation) actually engages with
 * [passageText] rather than being about an unrelated topic — a real failure
 * mode observed where the model wrote a reading-comprehension question about
 * an entirely different subject than the passage it was paired with (e.g. a
 * "keystone species" question about beavers attached to a passage about
 * earthworms). Requires at least [minOverlap] shared significant words;
 * skips the check (returns true) if the passage is too short to have any,
 * since that's not this function's failure mode to catch.
 */
export function sharesTopicWithPassage(
  questionText: string,
  passageText: string,
  minOverlap = 2
): boolean {
  const passageWords = significantWords(passageText);
  if (passageWords.size === 0) return true;
  const questionWords = questionText.toLowerCase().match(/[a-z]+/g) ?? [];
  const overlap = questionWords.filter((w) => passageWords.has(w)).length;
  return overlap >= minOverlap;
}
