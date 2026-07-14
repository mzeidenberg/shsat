import '../models/question.dart';
import '../models/question_attempt.dart';

/// Minimum attempts required in EACH question type before an estimate is
/// shown — avoids a composite "SHSAT score" built from just one category
/// (e.g. only Algebra), which wouldn't reflect the other three at all.
const int kMinAttemptsPerCategoryForScoreEstimate = 4;

/// How many of a type's most recent attempts feed the estimate.
const int kRecentWindowPerCategory = 30;

/// Returns, for each type still below [kMinAttemptsPerCategoryForScoreEstimate],
/// how many more attempts are needed. Empty once the estimate is unlocked.
Map<QuestionType, int> attemptsStillNeededForEstimate(
  List<QuestionAttempt> allAttempts, {
  int minAttemptsPerCategory = kMinAttemptsPerCategoryForScoreEstimate,
}) {
  final needed = <QuestionType, int>{};
  for (final type in QuestionType.values) {
    final count = allAttempts.where((a) => a.type == type).length;
    if (count < minAttemptsPerCategory) {
      needed[type] = minAttemptsPerCategory - count;
    }
  }
  return needed;
}

/// Rough heuristic, not an official SHSAT scaled-score prediction (the real
/// conversion tables aren't published and vary by year). Requires at least
/// [minAttemptsPerCategory] attempts in every question type, then combines
/// each type's accuracy over its most recent [recentWindowPerCategory]
/// attempts into a composite that weights Math and ELA 50/50 — mirroring the
/// real exam's structure — rather than pooling raw accuracy across whatever
/// mix of types happened to be practiced most recently.
int? estimateScore(
  List<QuestionAttempt> allAttempts, {
  int recentWindowPerCategory = kRecentWindowPerCategory,
  int minAttemptsPerCategory = kMinAttemptsPerCategoryForScoreEstimate,
}) {
  if (attemptsStillNeededForEstimate(
    allAttempts,
    minAttemptsPerCategory: minAttemptsPerCategory,
  ).isNotEmpty) {
    return null;
  }

  double accuracyFor(QuestionType type) {
    final typeAttempts = allAttempts.where((a) => a.type == type).toList()
      ..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
    final recent = typeAttempts.take(recentWindowPerCategory);
    return recent.where((a) => a.correct).length / recent.length;
  }

  final mathAccuracy =
      (accuracyFor(QuestionType.arithmeticWordProblem) + accuracyFor(QuestionType.algebraEquation)) / 2;
  final elaAccuracy =
      (accuracyFor(QuestionType.grammarEdit) + accuracyFor(QuestionType.readingComprehension)) / 2;
  final compositeAccuracy = (mathAccuracy + elaAccuracy) / 2;

  final raw = 200 + compositeAccuracy * 600;
  return (raw / 10).round() * 10;
}
