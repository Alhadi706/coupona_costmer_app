import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status pill pending uses gold background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaStatusPill(kind: StatusPillKind.pending),
        ),
      ),
    );

    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.color, kGold);
    expect(find.text('معلّقة'), findsOneWidget);
  });

  testWidgets('status pill approved mint uses mint background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaStatusPill(kind: StatusPillKind.approvedMint),
        ),
      ),
    );

    final Container container = tester.widget<Container>(find.byType(Container));
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.color, kMint);
  });
}
