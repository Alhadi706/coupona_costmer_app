import 'package:coupona_app/screens/home_content_screen.dart';
import 'package:coupona_app/screens/home_screen.dart';
import 'package:coupona_app/screens/ads_banner_slider.dart';
import 'package:coupona_app/widgets/design_system/kupuna_top_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('customer home has the required five-item navigation', (
    tester,
  ) async {
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

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.map((item) => item.label), <String>[
      'Home',
      'Map',
      'Communities',
      'Wallet',
      'My Account',
    ]);
  });

  testWidgets('scan invoice action is only shown on the customer home tab', (
    tester,
  ) async {
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

    expect(find.byType(FloatingActionButton), findsOneWidget);

    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      4,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('customer home has a rotating banner and three required tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        HomeContentScreen(
          onOpenOffersTab: () {},
          onOpenPeerAdsTab: () {},
          onOpenMap: () {},
          onOpenRewards: () {},
          onOpenCommunity: () {},
          onScanReceipt: () {},
          billboardAdsLoader: () async => <Map<String, dynamic>>[],
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
    expect(find.text('home_view_rewards'), findsOneWidget);
    expect(find.text('home_coalition_network'), findsOneWidget);
    expect(find.text('home_quick_scan'), findsNothing);
    expect(find.text('home_quick_map'), findsNothing);
    expect(find.text('home_quick_community'), findsNothing);

    await tester.tap(find.text('home_banner_next'));
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('approved billboard ad replaces the default customer banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        HomeContentScreen(
          onOpenOffersTab: () {},
          onOpenPeerAdsTab: () {},
          onOpenMap: () {},
          onOpenRewards: () {},
          onOpenCommunity: () {},
          onScanReceipt: () {},
          billboardAdsLoader: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'approved-ad-1',
              'description': 'إعلان معتمد للزبون',
              'imageUrl': '/api/billboard-ads/approved-ad-1/image',
            },
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AdsBannerSlider), findsOneWidget);
    expect(find.text('إعلان معتمد للزبون'), findsOneWidget);
    expect(find.text('1/3'), findsNothing);
  });
}
