import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/quiz_controller.dart';
import 'results_screen.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(quizControllerProvider);
    final bank = ref.watch(questionBankProvider).value;

    if (quiz == null || bank == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (quiz.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResultsScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = quiz.currentQuestion;
    final passage = bank.passageFor(question);
    final selectedKey = quiz.answers[question.id];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${quiz.currentIndex + 1} of ${quiz.questions.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passage != null) ...[
              Text(passage.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(passage.text, style: const TextStyle(fontSize: 15, height: 1.4)),
              const Divider(height: 32),
            ],
            Text(question.prompt, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...question.choices.map((choice) {
              final isSelected = selectedKey == choice.key;
              final isCorrectChoice = choice.key == question.answerKey;
              Color? tileColor;
              if (quiz.answered) {
                if (isCorrectChoice) {
                  tileColor = Colors.green.withValues(alpha: 0.2);
                } else if (isSelected) {
                  tileColor = Colors.red.withValues(alpha: 0.2);
                }
              }
              return Card(
                color: tileColor,
                child: ListTile(
                  title: Text('${choice.key}. ${choice.text}'),
                  onTap: quiz.answered
                      ? null
                      : () => ref.read(quizControllerProvider.notifier).selectAnswer(choice.key),
                ),
              );
            }),
            if (quiz.answered) ...[
              const SizedBox(height: 12),
              Text(
                selectedKey == question.answerKey ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selectedKey == question.answerKey ? Colors.green[800] : Colors.red[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(question.explanation, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.read(quizControllerProvider.notifier).next(),
                child: Text(quiz.isLastQuestion ? 'See results' : 'Next question'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
