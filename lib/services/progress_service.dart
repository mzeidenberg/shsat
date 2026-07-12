import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';

class SessionRecord {
  final Subject subject;
  final int score;
  final int total;
  final DateTime completedAt;

  const SessionRecord({
    required this.subject,
    required this.score,
    required this.total,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject.name,
        'score': score,
        'total': total,
        'completed_at': completedAt.toIso8601String(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        subject: (json['subject'] as String) == 'math' ? Subject.math : Subject.ela,
        score: json['score'] as int,
        total: json['total'] as int,
        completedAt: DateTime.parse(json['completed_at'] as String),
      );
}

class ProgressService {
  static const _historyKey = 'quiz_history';

  Future<void> recordSession(SessionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    history.add(record);
    final encoded = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }

  Future<List<SessionRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SessionRecord.fromJson(e as Map<String, dynamic>)).toList();
  }
}
