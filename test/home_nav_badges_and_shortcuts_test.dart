import 'package:coupona_app/screens/home_content_screen.dart';
import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/widgets/design_system/kupuna_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeContentScreen does not render removed quick shortcut action chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeContentScreen(
            onOpenOffersTab: () {},
            onOpenPeerAdsTab: () {},
            onScanReceipt: () {},
            onOpenCommunity: () {},
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('حاسبة الخصم'), findsNothing);
    expect(find.text('مسح الفاتورة'), findsNothing);
    expect(find.text('هداياي الخاصة'), findsNothing);
    expect(find.text('عروض الزبائن'), findsNothing);
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
