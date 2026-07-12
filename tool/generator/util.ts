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
