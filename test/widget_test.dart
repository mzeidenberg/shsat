import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shsat_tutor/main.dart';

void main() {
  testWidgets('Home screen shows subject choices', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShsatTutorApp()));
    await tester.pumpAndSettle();

    expect(find.text('SHSAT Tutor'), findsOneWidget);
    expect(find.text('Choose a subject to practice'), findsOneWidget);
  });
}
