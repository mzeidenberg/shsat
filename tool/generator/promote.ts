import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { Passage, Question, QuestionType, Subject } from "./types.js";
import { readJsonArray, writeJsonArray } from "./util.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const STAGING_DIR = join(ROOT, "tool", "generator", "staging");
const ASSETS_DIR = join(ROOT, "assets", "questions");

function parseArgs() {
  const args = process.argv.slice(2);
  const get = (flag: string) => {
    const idx = args.indexOf(flag);
    return idx >= 0 ? args[idx + 1] : undefined;
  };
  const subject = get("--subject") as Subject | undefined;
  const type = get("--type") as QuestionType | undefined;
  if (!subject || !type) {
    console.error("Usage: npm run promote -- --subject <math|ela> --type <type>");
    process.exit(1);
  }
  return { subject, type };
}

async function main() {
  const { subject, type } = parseArgs();

  const stagingPath = join(STAGING_DIR, `${subject}-${type}.json`);
  const assetsPath = join(ASSETS_DIR, subject, `${type}.json`);

  const staged = await readJsonArray<Question>(stagingPath);
  const shipped = await readJsonArray<Question>(assetsPath);

  const toPromote = staged.filter((q) => q.metadata.reviewed);
  const remaining = staged.filter((q) => !q.metadata.reviewed);

  if (toPromote.length === 0) {
    console.log(`No reviewed questions found in staging/${subject}-${type}.json. Nothing to do.`);
    return;
  }

  const shippedHashes = new Set(shipped.map((q) => q.metadata.content_hash));
  const newlyShipped = toPromote.filter((q) => !shippedHashes.has(q.metadata.content_hash));
  const merged = [...shipped, ...newlyShipped].sort((a, b) => a.id.localeCompare(b.id));

  await writeJsonArray(assetsPath, merged);
  await writeJsonArray(stagingPath, remaining);

  if (type === "reading_comprehension") {
    const stagingPassagesPath = join(STAGING_DIR, "ela-passages.json");
    const assetsPassagesPath = join(ASSETS_DIR, "ela", "passages.json");
    const stagingPassages = await readJsonArray<Passage>(stagingPassagesPath);
    const assetsPassages = await readJsonArray<Passage>(assetsPassagesPath);

    const promotedPassageIds = new Set(newlyShipped.map((q) => q.passage_id).filter(Boolean));
    const passagesToPromote = stagingPassages.filter((p) => promotedPassageIds.has(p.id));
    const remainingPassages = stagingPassages.filter((p) => !promotedPassageIds.has(p.id));
    const existingPassageIds = new Set(assetsPassages.map((p) => p.id));
    const newlyShippedPassages = passagesToPromote.filter((p) => !existingPassageIds.has(p.id));

    await writeJsonArray(assetsPassagesPath, [...assetsPassages, ...newlyShippedPassages]);
    await writeJsonArray(stagingPassagesPath, remainingPassages);
    console.log(`  promoted ${newlyShippedPassages.length} passage(s)`);
  }

  console.log(
    `Promoted ${newlyShipped.length} question(s) to assets/questions/${subject}/${type}.json ` +
      `(${toPromote.length - newlyShipped.length} were already shipped).`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
