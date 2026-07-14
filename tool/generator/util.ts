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
