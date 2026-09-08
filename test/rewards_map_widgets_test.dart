import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coupona_app/widgets/home_rewards_path_widget.dart';
import 'package:coupona_app/widgets/full_rewards_map_modal.dart';
import 'package:coupona_app/widgets/map_node_widget.dart';
import 'package:coupona_app/widgets/map_path_painter.dart';
import 'package:coupona_app/widgets/map_background_decorations.dart';

void main() {
  final sampleRewards = [
    {'reward_name': 'خصم 10%', 'value': 50, 'storeName': 'المتجر الرئيسي'},
    {'reward_name': 'قسيمة 20 د.ل', 'value': 100, 'storeName': 'سوبرماركت البركة'},
    {'reward_name': 'هدية فاخرة', 'value': 250, 'storeName': 'سوق الخضار'},
    {'reward_name': 'جائزة كبرى', 'value': 500, 'storeName': 'الشركة العامة'},
  ];

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  testWidgets('HomeRewardsPathWidget renders without overflow or clipping', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        HomeRewardsPathWidget(
          balance: 41,
          rewards: sampleRewards,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of path nodes & custom painter
    expect(find.byType(HomeRewardsPathWidget), findsOneWidget);
    expect(find.byType(MapNodeWidget), findsNWidgets(4));
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HomePathPainter),
      findsOneWidget,
    );
  });

  testWidgets('FullRewardsMapScreen renders light themed map with background decorations', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        SizedBox(
          height: 800,
          child: FullRewardsMapScreen(
            balance: 41,
            rewards: sampleRewards,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FullRewardsMapScreen), findsOneWidget);
    expect(find.byType(MapBackgroundDecorations), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is MapPathPainter),
      findsOneWidget,
    );
    expect(find.byType(MapNodeWidget), findsWidgets);
  });
}
