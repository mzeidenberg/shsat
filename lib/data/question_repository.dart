import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';

class QuestionBank {
  final List<Question> questions;
  final Map<String, Passage> passagesById;

  const QuestionBank({required this.questions, required this.passagesById});

  List<Question> forSubject(Subject subject) =>
      questions.where((q) => q.subject == subject).toList();

  List<Question> forType(QuestionType type) =>
      questions.where((q) => q.type == type).toList();

  Passage? passageFor(Question question) =>
      question.passageId == null ? null : passagesById[question.passageId];
}

class QuestionRepository {
  static const _files = <String>[
    'assets/questions/math/arithmetic_word_problem.json',
    'assets/questions/math/algebra_equation.json',
    'assets/questions/ela/grammar_edit.json',
    'assets/questions/ela/reading_comprehension.json',
  ];
  static const _passagesFile = 'assets/questions/ela/passages.json';

  Future<QuestionBank> load() async {
    final questions = <Question>[];
    for (final path in _files) {
      final raw = await _tryLoad(path);
      if (raw == null) continue;
      final list = jsonDecode(raw) as List;
      questions.addAll(list.map((e) => Question.fromJson(e as Map<String, dynamic>)));
    }

    final passages = <String, Passage>{};
    final rawPassages = await _tryLoad(_passagesFile);
    if (rawPassages != null) {
      final list = jsonDecode(rawPassages) as List;
      for (final e in list) {
        final passage = Passage.fromJson(e as Map<String, dynamic>);
        passages[passage.id] = passage;
      }
    }

    return QuestionBank(questions: questions, passagesById: passages);
  }

  Future<String?> _tryLoad(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return null;
    }
  }
}
