import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/question.dart';
import '../models/question_attempt.dart';
import '../state/practice_controller.dart';
import 'dashboard_screen.dart';
import 'practice_screen.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practice = ref.watch(practiceControllerProvider);
    final bankAsync = ref.watch(questionBankProvider);
    final attempts = practice.attempts;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: attempts.isEmpty
          ? const Center(child: Text('You haven\'t answered any questions yet.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Text(
                    '${practice.sessionScore} / ${practice.sessionTotal} correct',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('By question type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (final type in QuestionType.values) _TypeRow(type: type, attempts: attempts),
                const SizedBox(height: 24),
                bankAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (bank) {
                    final missed = attempts.where((a) => !a.correct).toList();
                    if (missed.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Review missed questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        for (final attempt in missed)
                          Builder(builder: (context) {
                            final matches =
                                bank.questions.where((q) => q.id == attempt.questionId);
                            if (matches.isEmpty) return const SizedBox.shrink();
                            final question = matches.first;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(question.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Text('Correct answer: ${question.answerKey}. '
                                        '${question.choices.firstWhere((c) => c.key == question.answerKey).text}'),
                                    const SizedBox(height: 6),
                                    Text(question.explanation, style: const TextStyle(fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(practiceControllerProvider.notifier).reset();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const PracticeScreen()));
                },
                child: const Text('Practice again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(practiceControllerProvider.notifier).reset();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const DashboardScreen()));
                },
                child: const Text('View dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final QuestionType type;
  final List<QuestionAttempt> attempts;

  const _TypeRow({required this.type, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final typeAttempts = attempts.where((a) => a.type == type).toList();
    if (typeAttempts.isEmpty) return const SizedBox.shrink();
    final correct = typeAttempts.where((a) => a.correct).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(type.label),
          Text('$correct / ${typeAttempts.length}'),
        ],
      ),
    );
  }
}
