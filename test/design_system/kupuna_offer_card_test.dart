import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offer card shows peer badge with gold background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KupunaOfferCard(
            offer: const {
              'title': 'Peer Offer',
              'category': 'Cat',
              'sourceType': 'peer',
            },
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('فرد'), findsOneWidget);
    final Container container = tester.widget<Container>(
      find.ancestor(of: find.text('فرد'), matching: find.byType(Container)).first,
    );
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.color, kGold);
  });

  testWidgets('offer card shows brand badge with indigo background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KupunaOfferCard(
            offer: const {
              'title': 'Brand Offer',
              'category': 'Cat',
              'sourceType': 'brand',
            },
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('علامة'), findsOneWidget);
    final Container container = tester.widget<Container>(
      find.ancestor(of: find.text('علامة'), matching: find.byType(Container)).first,
    );
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.color, kIndigo);
  });

  testWidgets('merchant offer has no source badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KupunaOfferCard(
            offer: const {
              'title': 'Merchant Offer',
              'category': 'Cat',
              'sourceType': 'merchant',
            },
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('علامة'), findsNothing);
    expect(find.text('فرد'), findsNothing);
  });
}
