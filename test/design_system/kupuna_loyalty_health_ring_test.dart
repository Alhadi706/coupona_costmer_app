import 'package:coupona_app/widgets/design_system/kupuna_loyalty_health_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loyalty ring always renders custom paint and numeric center', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaLoyaltyHealthRing(scorePercent: 82),
        ),
      ),
    );

    final Finder ringFinder = find.byType(KupunaLoyaltyHealthRing);
    final Finder ringPaint = find.descendant(
      of: ringFinder,
      matching: find.byType(CustomPaint),
    );
    expect(ringPaint, findsOneWidget);
    expect(find.text('82'), findsOneWidget);

    final Finder scoreText = find.text('82');
    expect(
      find.descendant(of: ringPaint, matching: scoreText),
      findsOneWidget,
    );
  });
}
