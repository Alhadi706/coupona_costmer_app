import 'package:coupona_app/screens/home_content_screen.dart';
import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/widgets/design_system/kupuna_top_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('customer home has the required five-item navigation', (tester) async {
    await tester.pumpWidget(
      app(
        const HomeScreen(
          phone: '0500000000',
          age: '25',
          gender: 'M',
          initialRoleOverride: 'customer',
        ),
      ),
    );
    await tester.pump();

    final nav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.items.map((item) => item.label), <String>[
      'Home',
      'Wallet',
      'Communities',
      'Reports',
      'My Account',
    ]);
  });

  testWidgets('customer home has a rotating banner and three required tabs', (tester) async {
    await tester.pumpWidget(
      app(
        HomeContentScreen(
          onOpenOffersTab: () {},
          onOpenPeerAdsTab: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1/3'), findsOneWidget);
    final tabs = tester.widget<KupunaTopTabs>(find.byType(KupunaTopTabs));
    expect(tabs.tabs, <String>[
      'home_tab_discover',
      'home_tab_offers',
      'home_tab_peer_ads',
    ]);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);
  });
}