import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shsat_tutor/data/question_repository.dart';
import 'package:shsat_tutor/main.dart';
import 'package:shsat_tutor/state/practice_controller.dart';

void main() {
  testWidgets('Home screen shows practice and dashboard entry points', (WidgetTester tester) async {
    // Override with a small fake bank instead of loading the real (large,
    // ever-growing) bundled question set — this test is about the home
    // screen's UI, not asset loading, and shouldn't slow down or become
    // flaky as the content library grows.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionBankProvider.overrideWith(
            (ref) async => const QuestionBank(questions: [], passagesById: {}),
          ),
        ],
        child: const ShsatTutorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHSAT Tutor'), findsOneWidget);
    expect(find.text('Start Practicing'), findsOneWidget);
    expect(find.text('View Dashboard'), findsOneWidget);
  });
}
