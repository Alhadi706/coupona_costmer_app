import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_top_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('top tabs render active tab with ink background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KupunaTopTabs(
            tabs: const ['A', 'B'],
            activeIndex: 1,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final Finder activeContainerFinder = find.ancestor(
      of: find.text('B'),
      matching: find.byType(AnimatedContainer),
    );
    final AnimatedContainer activeContainer =
        tester.widget<AnimatedContainer>(activeContainerFinder.first);
    final BoxDecoration deco = activeContainer.decoration! as BoxDecoration;
    expect(deco.color, kInk);
  });
}
