import '../models/question_attempt.dart';

/// Minimum attempts required before an estimate is shown at all.
const int kMinAttemptsForScoreEstimate = 5;

/// Rough heuristic, not an official SHSAT scaled-score prediction (the real
/// conversion tables aren't published and vary by year): maps accuracy over
/// the most recent [recentWindow] attempts linearly onto a 200-800 range.
/// Returns null until at least [minAttempts] attempts exist.
int? estimateScore(
  List<QuestionAttempt> allAttempts, {
  int recentWindow = 30,
  int minAttempts = kMinAttemptsForScoreEstimate,
}) {
  if (allAttempts.length < minAttempts) return null;
  final sorted = [...allAttempts]..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
  final recent = sorted.take(recentWindow).toList();
  final accuracy = recent.where((a) => a.correct).length / recent.length;
  final raw = 200 + accuracy * 600;
  return (raw / 10).round() * 10;
}
