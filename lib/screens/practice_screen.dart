import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_repository.dart';
import '../models/question.dart';
import '../state/practice_controller.dart';
import 'session_summary_screen.dart';

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practice = ref.watch(practiceControllerProvider);
    final bankAsync = ref.watch(questionBankProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          practice.sessionTotal == 0
              ? 'Practice'
              : '${practice.sessionScore} / ${practice.sessionTotal} this session',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionSummaryScreen()),
            ),
            child: const Text('Finish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: bankAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load questions: $err'),
          ),
        ),
        data: (bank) {
          if (practice.currentQuestion == null) {
            return _TypeChooser(
              bank: bank,
              onPick: (type) =>
                  ref.read(practiceControllerProvider.notifier).pickType(type, bank),
            );
          }
          return _QuestionView(bank: bank, practice: practice, ref: ref);
        },
      ),
    );
  }
}

class _TypeChooser extends StatelessWidget {
  final QuestionBank bank;
  final ValueChanged<QuestionType> onPick;

  const _TypeChooser({required this.bank, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a question type to practice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            for (final subject in Subject.values) ...[
              Text(
                subject == Subject.math ? 'Math' : 'ELA',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final type in QuestionType.values.where((t) => t.subject == subject))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 280,
                    child: ElevatedButton(
                      onPressed: bank.forType(type).isEmpty ? null : () => onPick(type),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text('${type.label} (${bank.forType(type).length})'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final QuestionBank bank;
  final PracticeState practice;
  final WidgetRef ref;

  const _QuestionView({required this.bank, required this.practice, required this.ref});

  @override
  Widget build(BuildContext context) {
    final question = practice.currentQuestion!;
    final passage = bank.passageFor(question);
    final selectedKey = practice.selectedChoiceKey;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.type.label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
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
            if (practice.answered) {
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
                onTap: practice.answered
                    ? null
                    : () => ref.read(practiceControllerProvider.notifier).selectAnswer(choice.key),
              ),
            );
          }),
          if (practice.answered) ...[
            const SizedBox(height: 12),
            Text(
              practice.isCorrect ? 'Correct!' : 'Incorrect',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: practice.isCorrect ? Colors.green[800] : Colors.red[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(question.explanation, style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
            SizedBox(
              width: 280,
              child: ElevatedButton(
                onPressed: bank.forType(question.type).isEmpty
                    ? null
                    : () => ref
                        .read(practiceControllerProvider.notifier)
                        .pickType(question.type, bank),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text('Another ${question.type.label} question'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Or choose a different type', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            for (final type in QuestionType.values.where((t) => t != question.type))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 280,
                  child: OutlinedButton(
                    onPressed: bank.forType(type).isEmpty
                        ? null
                        : () => ref.read(practiceControllerProvider.notifier).pickType(type, bank),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text('${type.label} (${bank.forType(type).length})'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
