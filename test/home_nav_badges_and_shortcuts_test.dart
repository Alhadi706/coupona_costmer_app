import 'package:coupona_app/screens/home_content_screen.dart';
import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/widgets/design_system/kupuna_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeContentScreen renders quick shortcut action buttons', (tester) async {
    bool scanned = false;
    bool openedCommunity = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeContentScreen(
            onOpenOffersTab: () {},
            onOpenPeerAdsTab: () {},
            onScanReceipt: () {
              scanned = true;
            },
            onOpenCommunity: () {
              openedCommunity = true;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('حاسبة الخصم'), findsOneWidget);
    expect(find.text('مسح الفاتورة'), findsOneWidget);
    expect(find.text('هداياي الخاصة'), findsOneWidget);
    expect(find.text('سوق المجتمع'), findsOneWidget);

    await tester.tap(find.text('مسح الفاتورة'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scanned, isTrue);

    await tester.ensureVisible(find.text('سوق المجتمع'));
    await tester.tap(find.text('سوق المجتمع'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(openedCommunity, isTrue);
  });

  testWidgets('KupunaBottomNavbar hides badge when count is 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: KupunaBottomNavbar(
            activeItem: KupunaNavItem.home,
            onTap: (_) {},
            badgeCounts: const {
              KupunaNavItem.communities: 0,
              KupunaNavItem.wallet: 3,
            },
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });
}
