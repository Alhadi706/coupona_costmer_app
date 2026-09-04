import 'package:coupona_app/screens/store_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('store page exposes overview and four content tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StoreDetailsScreen(
          store: <String, dynamic>{
            'name': 'Test Store',
            'category': 'Bakery',
            'pointValue': 0.1,
            'pointTier': 'bronze',
            'lat': 32.88,
            'lng': 13.19,
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Test Store'), findsWidgets);
    expect(find.text('store_tab_overview'), findsOneWidget);
    expect(find.text('store_tab_products'), findsWidgets);
    expect(find.text('store_tab_offers'), findsWidgets);
    expect(find.text('store_tab_rewards'), findsWidgets);
    expect(find.text('store_tab_coalitions'), findsOneWidget);
    expect(find.text('store_points_bronze'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'store_tab_products'));
    await tester.pumpAndSettle();

    expect(find.text('store_products_empty'), findsOneWidget);
  });
}
