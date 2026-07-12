import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/progress_service.dart';
import '../state/quiz_controller.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final quiz = ref.read(quizControllerProvider);
    if (quiz == null) {
      return const Scaffold(body: Center(child: Text('No quiz results to show.')));
    }

    if (!_saved) {
      _saved = true;
      ProgressService().recordSession(SessionRecord(
        subject: quiz.subject,
        score: quiz.score,
        total: quiz.questions.length,
        completedAt: DateTime.now(),
      ));
    }

    final missed = quiz.questions.where((q) => quiz.answers[q.id] != q.answerKey).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(
              '${quiz.score} / ${quiz.questions.length} correct',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          if (missed.isNotEmpty) ...[
            const Text('Review missed questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...missed.map((q) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Correct answer: ${q.answerKey}. '
                            '${q.choices.firstWhere((c) => c.key == q.answerKey).text}'),
                        const SizedBox(height: 6),
                        Text(q.explanation, style: const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref.read(quizControllerProvider.notifier).reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}
