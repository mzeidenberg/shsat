import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/question_attempt.dart';

class ProgressService {
  static const _attemptsKey = 'question_attempts';

  Future<void> recordAttempt(QuestionAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = await loadAttempts()..add(attempt);
    final encoded = jsonEncode(attempts.map((a) => a.toJson()).toList());
    await prefs.setString(_attemptsKey, encoded);
  }

  Future<List<QuestionAttempt>> loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_attemptsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => QuestionAttempt.fromJson(e as Map<String, dynamic>)).toList();
  }
}
