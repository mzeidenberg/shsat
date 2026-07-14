import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_repository.dart';
import '../models/question.dart';
import '../models/question_attempt.dart';
import '../services/progress_service.dart';

final questionRepositoryProvider = Provider((ref) => QuestionRepository());

final questionBankProvider = FutureProvider<QuestionBank>((ref) {
  return ref.read(questionRepositoryProvider).load();
});

class PracticeState {
  final Question? currentQuestion;
  final String? selectedChoiceKey;
  final bool answered;
  final List<QuestionAttempt> attempts;
  final Map<QuestionType, Set<String>> askedIdsByType;

  const PracticeState({
    this.currentQuestion,
    this.selectedChoiceKey,
    this.answered = false,
    this.attempts = const [],
    this.askedIdsByType = const {},
  });

  bool get isCorrect =>
      currentQuestion != null && selectedChoiceKey == currentQuestion!.answerKey;
  int get sessionScore => attempts.where((a) => a.correct).length;
  int get sessionTotal => attempts.length;
}

class PracticeController extends Notifier<PracticeState> {
  @override
  PracticeState build() => const PracticeState();

  void pickType(QuestionType type, QuestionBank bank) {
    final pool = bank.forType(type);
    if (pool.isEmpty) return;
    final asked = state.askedIdsByType[type] ?? const <String>{};
    var candidates = pool.where((q) => !asked.contains(q.id)).toList();
    if (candidates.isEmpty) candidates = pool;
    final chosen = candidates[Random().nextInt(candidates.length)];
    state = PracticeState(
      currentQuestion: chosen,
      answered: false,
      attempts: state.attempts,
      askedIdsByType: state.askedIdsByType,
    );
  }

  Future<void> selectAnswer(String choiceKey) async {
    final question = state.currentQuestion;
    if (question == null || state.answered) return;

    final attempt = QuestionAttempt(
      questionId: question.id,
      subject: question.subject,
      type: question.type,
      correct: choiceKey == question.answerKey,
      answeredAt: DateTime.now(),
    );

    final updatedAsked = Map<QuestionType, Set<String>>.from(state.askedIdsByType);
    updatedAsked[question.type] = {...(updatedAsked[question.type] ?? const {}), question.id};

    state = PracticeState(
      currentQuestion: question,
      selectedChoiceKey: choiceKey,
      answered: true,
      attempts: [...state.attempts, attempt],
      askedIdsByType: updatedAsked,
    );

    await ProgressService().recordAttempt(attempt);
  }

  void reset() => state = const PracticeState();
}

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState>(PracticeController.new);
