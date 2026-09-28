# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`shsat_tutor` is a Flutter app (Material 3, Riverpod state management) that lets a student
practice for the NYC SHSAT exam. There is no backend — questions ship as bundled JSON assets
and all progress is stored locally via `shared_preferences`. A separate TypeScript pipeline
under `tool/generator/` is used offline to generate, verify, and ship new questions into those
JSON assets; it is not part of the running app.

## Commands

### App (run from repo root)

```bash
flutter pub get                 # install/update Dart deps
flutter analyze                 # static analysis (uses flutter_lints defaults, no custom rules)
flutter test                    # run all tests
flutter test test/widget_test.dart --plain-name "Home screen shows practice and dashboard entry points"  # single test
```

Run the web dev server via the launch config in `.claude/launch.json` (name `shsat-tutor-web`,
`flutter run -d web-server --web-port 8765`) — use the Browser pane / `preview_start` tooling
rather than invoking `flutter run` directly in Bash, so the app can be driven and screenshotted.

**Note on `flutter test`**: `test/widget_test.dart` overrides `questionBankProvider` with a tiny
in-memory `QuestionBank` instead of loading the real bundled asset set. Loading the real
(large, ever-growing) question bank through Flutter's test asset-bundle mechanism hangs
indefinitely — always override `questionBankProvider` in new widget tests rather than letting
them load the real assets.

### Question generator/verifier pipeline (run from `tool/generator/`)

```bash
npm install
npm run generate -- --subject <math|ela> --type <arithmetic_word_problem|algebra_equation|grammar_edit|reading_comprehension> --count <n>
npm run promote -- --subject <math|ela> --type <type>
npm run verify-assets
```

Auth: the generator uses `new Anthropic()` with no explicit API key, which picks up credentials
from the `ant` CLI's stored auth profile (`ant auth login`) — do not add an `ANTHROPIC_API_KEY`
requirement back in.

`bulk_generate.sh <subject> <type> <target_total> <per_call_count>` loops `npm run generate`
until shipped+staged reaches a target count; useful for growing a thin category without manual
repetition.

## Architecture

### Content pipeline: staging → review → shipped assets

New questions never go directly into the app's asset bundle. The flow is:

1. `generate.ts` calls the generator model (`GENERATOR_MODEL`, default `claude-sonnet-5`) to
   produce a batch, runs it through validation (see below), then an independent verifier model
   (`VERIFIER_MODEL`, default `claude-opus-4-8`) that re-solves each question from scratch and
   reports whether it agrees with the labeled answer. Output (with full metadata: content hash,
   both models, verifier/deterministic-check results, `reviewed: false`) is appended to
   `tool/generator/staging/<subject>-<type>.json` (and `staging/ela-passages.json` for
   reading-comprehension passages).
2. A human (or an agreed policy — e.g. auto-mark `reviewed=true` when `verifier_agreed==true`
   and `deterministic_check_passed != false`) sets `metadata.reviewed = true` on staged entries
   that are good to ship.
3. `promote.ts` moves `reviewed: true` staged questions (deduped by `content_hash`) into
   `assets/questions/<subject>/<type>.json`, and for reading comprehension also promotes any
   newly-referenced passage into `assets/questions/ela/passages.json`.
4. `verify_assets.ts` is a standalone integrity checker over the shipped assets only — run it
   after any manual edit to the JSON under `assets/questions/`. It hard-fails (`errors`, exit 1)
   on structural problems: blank/leaked-artifact/truncated text, wrong subject/type, malformed
   choices, invalid `answer_key`, duplicate question/passage IDs, duplicate content hashes,
   orphaned passages. It also emits non-fatal `warnings` for the passage/question topic-overlap
   heuristic (`sharesTopicWithPassage` in `util.ts`) — that heuristic has a real false-positive
   rate on legitimately-matching but paraphrased questions, so it is signal for manual/LLM
   review, not proof of a bug; don't promote a warning to a hard error without re-validating.

Question IDs (`<subject>-<type>-NNNNNN`) and passage IDs (`ela-passage-NNNNNN`) are assigned by
`nextSeq`/`idSeq` in `generate.ts` from the **highest existing numeric suffix** across staging +
shipped, not from a count — this is deliberate, since count-based numbering collides with valid
IDs whenever any shipped item has ever been deleted (e.g. during a content cleanup) and leaves a
gap. Do not revert to count-based numbering.

`check_expression` (math types only) is a JS-evaluable arithmetic expression used by
`deterministicMathCheck` in `verify.ts` to confirm the labeled answer is numerically correct; it
is generator/staging-only metadata and is never read by the Flutter app.

### Flutter app structure

- `lib/models/question.dart` — `Question`, `Choice`, `Passage`, `Subject`/`QuestionType` enums,
  and a `QuestionTypeLabel` extension (`.label` human-readable name, `.subject` Math/ELA
  derivation) used throughout the UI so screens don't need a `Question` in hand to describe a
  type.
- `lib/data/question_repository.dart` — `QuestionRepository.load()` reads all four
  `assets/questions/<subject>/<type>.json` files plus `passages.json` from the asset bundle into
  an in-memory `QuestionBank` (`forSubject`, `forType`, `passageFor`). This is the only place
  that touches the JSON assets at runtime; the Dart `Question.fromJson` intentionally ignores
  the generator's `metadata`/`check_expression` fields.
- `lib/state/practice_controller.dart` — `questionBankProvider` (`FutureProvider` loading the
  bank once) and `practiceControllerProvider` (`NotifierProvider<PracticeController,
  PracticeState>`) drive the open-ended practice loop: pick any type at any time, answer,
  pick again — there is no fixed quiz length or fixed question count. `PracticeState` is always
  constructed fresh at each transition (not copied) because `currentQuestion` needs to be
  nullable-and-settable-to-null (chooser state) — a generic `copyWith` can't express that.
  Each answer is recorded immediately via `ProgressService().recordAttempt(...)`, not batched at
  session end, so the dashboard reflects practice in real time.
- `lib/services/progress_service.dart` — persists `QuestionAttempt` history to
  `shared_preferences` under key `question_attempts`, read-modify-write-whole-list on every
  answer (fine at expected local-single-user scale).
- `lib/services/score_estimator.dart` — pure functions over attempt history, not app state.
  `estimateScore` requires at least `kMinAttemptsPerCategoryForScoreEstimate` (4) attempts in
  **every** `QuestionType` before returning a score (returns `null` otherwise) — this is
  deliberate: a composite score from only one or two categories wouldn't reflect the real exam.
  When unlocked, it computes each type's accuracy over its most recent
  `kRecentWindowPerCategory` (30) attempts, averages the two Math types and the two ELA types
  separately, then combines Math/ELA 50/50 — mirroring the real exam's subject split rather than
  pooling raw accuracy across whatever mix of types was practiced most recently.
  `attemptsStillNeededForEstimate` drives the "N more needed" messaging in the dashboard.
- `lib/state/dashboard_controller.dart` (`attemptsProvider`, `FutureProvider.autoDispose`) and
  `lib/screens/dashboard_screen.dart` — the score card plus an all-time per-type accuracy
  breakdown. `attemptsProvider` **must stay `.autoDispose`**: `DashboardScreen` is pushed as a
  fresh route each visit, and a cached `FutureProvider` would go stale as attempts are recorded
  mid-session.
- `lib/screens/practice_screen.dart` — single screen, two states (`_TypeChooser` when
  `currentQuestion == null`, `_QuestionView` otherwise); after answering, both "another question
  of this type" and "switch to a different type" are offered inline on the same screen, each
  labeled with the live remaining-question count for that type (`bank.forType(type).length`).
- `lib/screens/session_summary_screen.dart` — reached via the "Finish" AppBar action; summarizes
  the current session's attempts only (session state lives in `PracticeController`, reset on
  "Practice again").

### Known content-quality issues to watch for

The question bank is 100% AI-generated (generator model writes, a different verifier model
independently re-solves and checks agreement) — there is no real SHSAT content in this repo.
Past integrity bugs found and fixed by hardening the pipeline (see `hasLeakedArtifact`,
`looksTruncated`, `sharesTopicWithPassage` in `util.ts`, and the malformed-batch/oversized-batch
guards in `generate.ts`): leaked model-internal JSON/HTML fragments bleeding into prompt/choice
text, degenerate massively-oversized batches, and reading-comprehension questions paired with a
passage on a different topic than the question actually asks about. When adding new validation,
prefer wiring it into both `generate.ts` (reject before shipping) and `verify_assets.ts` (catch
anything already shipped) rather than just one.
