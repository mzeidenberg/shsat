import 'question.dart';

class QuestionAttempt {
  final String questionId;
  final Subject subject;
  final QuestionType type;
  final bool correct;
  final DateTime answeredAt;

  const QuestionAttempt({
    required this.questionId,
    required this.subject,
    required this.type,
    required this.correct,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'subject': subject.name,
        'type': type.name,
        'correct': correct,
        'answered_at': answeredAt.toIso8601String(),
      };

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) => QuestionAttempt(
        questionId: json['question_id'] as String,
        subject: (json['subject'] as String) == 'math' ? Subject.math : Subject.ela,
        type: QuestionType.values.byName(json['type'] as String),
        correct: json['correct'] as bool,
        answeredAt: DateTime.parse(json['answered_at'] as String),
      );
}
