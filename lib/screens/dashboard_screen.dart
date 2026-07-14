import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/question.dart';
import '../models/question_attempt.dart';
import '../services/score_estimator.dart';
import '../state/dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(attemptsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: attemptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load progress: $err'),
          ),
        ),
        data: (attempts) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ScoreCard(attempts: attempts),
            const SizedBox(height: 32),
            const Text('Strength by question type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final type in QuestionType.values) _TypeStrengthRow(type: type, attempts: attempts),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final List<QuestionAttempt> attempts;

  const _ScoreCard({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final score = estimateScore(attempts);
    final needed = attemptsStillNeededForEstimate(attempts);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estimated SHSAT Score', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              score == null ? 'Not enough data yet' : '$score / 800',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (score == null) ...[
              Text(
                'A reliable estimate needs at least $kMinAttemptsPerCategoryForScoreEstimate '
                'answered questions in each category (so it reflects both Math and ELA, not just '
                'whichever type you practiced most recently).',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              for (final entry in needed.entries)
                Text(
                  '• ${entry.key.label}: ${entry.value} more needed',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ] else
              const Text(
                'Rough estimate weighting Math and ELA 50/50 based on your recent answers in each '
                'category — not an official SHSAT score.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeStrengthRow extends StatelessWidget {
  final QuestionType type;
  final List<QuestionAttempt> attempts;

  const _TypeStrengthRow({required this.type, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final typeAttempts = attempts.where((a) => a.type == type).toList();
    final count = typeAttempts.length;
    final accuracy = count == 0 ? 0.0 : typeAttempts.where((a) => a.correct).length / count;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                count == 0 ? 'Not attempted yet' : '${(accuracy * 100).round()}% ($count attempted)',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: count == 0 ? 0 : accuracy,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
