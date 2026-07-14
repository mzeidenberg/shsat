class Choice {
  final String key;
  final String text;

  const Choice({required this.key, required this.text});

  factory Choice.fromJson(Map<String, dynamic> json) =>
      Choice(key: json['key'] as String, text: json['text'] as String);
}

enum Subject { math, ela }

enum QuestionType {
  arithmeticWordProblem,
  algebraEquation,
  grammarEdit,
  readingComprehension,
}

QuestionType questionTypeFromJson(String value) {
  switch (value) {
    case 'arithmetic_word_problem':
      return QuestionType.arithmeticWordProblem;
    case 'algebra_equation':
      return QuestionType.algebraEquation;
    case 'grammar_edit':
      return QuestionType.grammarEdit;
    case 'reading_comprehension':
      return QuestionType.readingComprehension;
    default:
      throw ArgumentError('Unknown question type: $value');
  }
}

extension QuestionTypeLabel on QuestionType {
  String get label => switch (this) {
        QuestionType.arithmeticWordProblem => 'Arithmetic Word Problems',
        QuestionType.algebraEquation => 'Algebra Equations',
        QuestionType.grammarEdit => 'Grammar & Editing',
        QuestionType.readingComprehension => 'Reading Comprehension',
      };

  Subject get subject => switch (this) {
        QuestionType.arithmeticWordProblem || QuestionType.algebraEquation => Subject.math,
        QuestionType.grammarEdit || QuestionType.readingComprehension => Subject.ela,
      };
}

class Question {
  final String id;
  final Subject subject;
  final QuestionType type;
  final String difficulty;
  final String? passageId;
  final String prompt;
  final List<Choice> choices;
  final String answerKey;
  final String explanation;

  const Question({
    required this.id,
    required this.subject,
    required this.type,
    required this.difficulty,
    required this.passageId,
    required this.prompt,
    required this.choices,
    required this.answerKey,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      subject: (json['subject'] as String) == 'math' ? Subject.math : Subject.ela,
      type: questionTypeFromJson(json['type'] as String),
      difficulty: json['difficulty'] as String,
      passageId: json['passage_id'] as String?,
      prompt: json['prompt'] as String,
      choices: (json['choices'] as List)
          .map((c) => Choice.fromJson(c as Map<String, dynamic>))
          .toList(),
      answerKey: json['answer_key'] as String,
      explanation: json['explanation'] as String,
    );
  }
}

class Passage {
  final String id;
  final String title;
  final String text;

  const Passage({required this.id, required this.title, required this.text});

  factory Passage.fromJson(Map<String, dynamic> json) => Passage(
        id: json['id'] as String,
        title: json['title'] as String,
        text: json['text'] as String,
      );
}
