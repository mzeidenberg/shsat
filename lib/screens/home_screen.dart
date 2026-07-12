import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_repository.dart';
import '../models/question.dart';
import '../state/quiz_controller.dart';
import 'quiz_screen.dart';

const _questionsPerQuiz = 10;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bankAsync = ref.watch(questionBankProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SHSAT Tutor')),
      body: Center(
        child: bankAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load questions: $err'),
          ),
          data: (bank) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a subject to practice',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                _SubjectButton(
                  label: 'Math',
                  subject: Subject.math,
                  count: bank.forSubject(Subject.math).length,
                  onTap: () => _startQuiz(context, ref, bank, Subject.math),
                ),
                const SizedBox(height: 16),
                _SubjectButton(
                  label: 'ELA',
                  subject: Subject.ela,
                  count: bank.forSubject(Subject.ela).length,
                  onTap: () => _startQuiz(context, ref, bank, Subject.ela),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startQuiz(BuildContext context, WidgetRef ref, QuestionBank bank, Subject subject) {
    final pool = bank.forSubject(subject);
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions available for this subject yet.')),
      );
      return;
    }
    final shuffled = List.of(pool)..shuffle(Random());
    final selected = shuffled.take(_questionsPerQuiz).toList();
    ref.read(quizControllerProvider.notifier).start(subject, selected);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QuizScreen()));
  }
}

class _SubjectButton extends StatelessWidget {
  final String label;
  final Subject subject;
  final int count;
  final VoidCallback onTap;

  const _SubjectButton({
    required this.label,
    required this.subject,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: Text('$label ($count questions)'),
      ),
    );
  }
}
