import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom navbar highlights active customer tab in teal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: KupunaBottomNavbar(
            activeItem: KupunaNavItem.wallet,
            onTap: (_) {},
          ),
        ),
      ),
    );

    final Text walletText = tester.widget<Text>(find.text('المحفظة'));
    final TextStyle style = walletText.style!;
    expect(style.color, kTeal);
    expect(style.fontWeight, FontWeight.w700);
  });

  testWidgets('bottom navbar renders red badge overlays when count > 0', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: KupunaBottomNavbar(
            activeItem: KupunaNavItem.home,
            onTap: (_) {},
            badgeCounts: const {
              KupunaNavItem.communities: 5,
              KupunaNavItem.wallet: 12,
            },
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
