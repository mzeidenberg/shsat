import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/question_repository.dart';
import '../models/question.dart';

final questionRepositoryProvider = Provider((ref) => QuestionRepository());

final questionBankProvider = FutureProvider<QuestionBank>((ref) {
  return ref.read(questionRepositoryProvider).load();
});

class QuizState {
  final Subject subject;
  final List<Question> questions;
  final int currentIndex;
  final Map<String, String> answers;
  final bool answered;

  const QuizState({
    required this.subject,
    required this.questions,
    required this.currentIndex,
    required this.answers,
    required this.answered,
  });

  Question get currentQuestion => questions[currentIndex];
  bool get isLastQuestion => currentIndex == questions.length - 1;
  bool get isComplete => currentIndex >= questions.length;
  int get score => answers.entries
      .where((e) => questions.firstWhere((q) => q.id == e.key).answerKey == e.value)
      .length;

  QuizState copyWith({
    int? currentIndex,
    Map<String, String>? answers,
    bool? answered,
  }) {
    return QuizState(
      subject: subject,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      answered: answered ?? this.answered,
    );
  }
}

class QuizController extends Notifier<QuizState?> {
  @override
  QuizState? build() => null;

  void start(Subject subject, List<Question> questions) {
    state = QuizState(
      subject: subject,
      questions: questions,
      currentIndex: 0,
      answers: const {},
      answered: false,
    );
  }

  void selectAnswer(String choiceKey) {
    final current = state;
    if (current == null || current.answered) return;
    final answers = Map<String, String>.from(current.answers);
    answers[current.currentQuestion.id] = choiceKey;
    state = current.copyWith(answers: answers, answered: true);
  }

  void next() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(currentIndex: current.currentIndex + 1, answered: false);
  }

  void reset() {
    state = null;
  }
}

final quizControllerProvider = NotifierProvider<QuizController, QuizState?>(QuizController.new);
