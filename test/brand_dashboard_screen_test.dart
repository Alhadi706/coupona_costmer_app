import 'package:coupona_app/screens/brand_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand dashboard renders core FMCG sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BrandDashboardScreen(
          embedded: false,
          offersLoader: () async => <Map<String, dynamic>>[],
          invoicesLoader: ({int limit = 20}) async => <Map<String, dynamic>>[],
          profileLoader: () async => <String, dynamic>{'pointValue': 5.0},
          productsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{'name': 'منتج اختبار', 'barcode': '123'},
          ],
          communityLoader: () async => <Map<String, dynamic>>[],
          rewardsLoader: () async => <Map<String, dynamic>>[],
          reportsLoader: () async => <Map<String, dynamic>>[],
          analyticsLoader: () async => <String, dynamic>{
            'matchedSales': 2500,
            'matchedCustomers': 120,
            'distributionHeatmap': <Map<String, dynamic>>[
              <String, dynamic>{'label': 'Tripoli', 'latitude': 32.8872, 'longitude': 13.1913, 'value': '1200'},
            ],
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('لوحة'), findsWidgets);
    expect(find.text('التحليلات'), findsOneWidget);
    expect(find.text('المكافآت'), findsOneWidget);
    expect(find.text('الإدارة'), findsOneWidget);

    await tester.tap(find.text('التحليلات'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Brand analytics'), findsOneWidget);

    await tester.tap(find.text('المكافآت'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('مكافآت'), findsWidgets);

    await tester.tap(find.text('الإدارة'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('جودة'), findsWidgets);
    expect(find.textContaining('مجتمع'), findsWidgets);
  });
}
