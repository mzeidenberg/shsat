import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/question_attempt.dart';
import '../services/progress_service.dart';

final progressServiceProvider = Provider<ProgressService>((ref) => ProgressService());

final attemptsProvider = FutureProvider.autoDispose<List<QuestionAttempt>>((ref) {
  return ref.read(progressServiceProvider).loadAttempts();
});
