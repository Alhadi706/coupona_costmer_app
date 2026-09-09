import 'package:coupona_app/screens/home_content_screen.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Discover inline map renders one marker per store from shared storesFuture',
    (tester) async {
      final stores = <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'Store One',
          'category': 'general',
          'lat': 32.8872,
          'lng': 13.1913,
        },
        {
          'id': 2,
          'name': 'Store Two',
          'category': 'general',
          'lat': 32.89,
          'lng': 13.20,
        },
        {
          'id': 3,
          'name': 'Store Three',
          'category': 'general',
          'lat': 32.88,
          'lng': 13.18,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeContentScreen(
              storesFuture: Future.value(stores),
              onOpenOffersTab: () {},
              onOpenPeerAdsTab: () {},
              onScanReceipt: () {},
              onOpenCommunity: () {},
            ),
          ),
        ),
      );

      // Wait for the shared stores future to resolve and the section to build.
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the list is rendered first (default map mode is off).
      expect(find.text('Store One'), findsOneWidget);
      expect(find.text('Store Two'), findsOneWidget);
      expect(find.text('Store Three'), findsOneWidget);

      // Toggle to the inline map view (scroll into view first).
      await tester.ensureVisible(find.byIcon(Icons.map_outlined));
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pump(const Duration(milliseconds: 300));

      // The inline map should be present.
      expect(find.byType(FlutterMap), findsOneWidget);

      // Each store with a valid lat/lng must produce a marker.
      final markerIcons = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.location_on &&
            widget.color == kGold,
      );
      expect(markerIcons, findsNWidgets(3));
    },
  );

  testWidgets(
    'Discover inline map skips stores with invalid zero coordinates',
    (tester) async {
      final stores = <Map<String, dynamic>>[
        {
          'id': 1,
          'name': 'Valid Store',
          'category': 'general',
          'lat': 32.8872,
          'lng': 13.1913,
        },
        {
          'id': 2,
          'name': 'Invalid Store',
          'category': 'general',
          'lat': 0,
          'lng': 0,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeContentScreen(
              storesFuture: Future.value(stores),
              onOpenOffersTab: () {},
              onOpenPeerAdsTab: () {},
              onScanReceipt: () {},
              onOpenCommunity: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byIcon(Icons.map_outlined));
      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pump(const Duration(milliseconds: 300));

      final markerIcons = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.location_on &&
            widget.color == kGold,
      );
      expect(markerIcons, findsOneWidget);
    },
  );
}
