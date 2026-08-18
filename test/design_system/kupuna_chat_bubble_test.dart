import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat bubble uses teal for current user message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaChatBubble(
            message: 'hello',
            isCurrentUser: true,
            senderKind: ChatSenderKind.customer,
          ),
        ),
      ),
    );

    final Container container = tester.widget<Container>(
      find.ancestor(of: find.text('hello'), matching: find.byType(Container)).first,
    );
    final BoxDecoration deco = container.decoration! as BoxDecoration;
    expect(deco.color, kTeal);
  });

  testWidgets('merchant sender avatar uses indigo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KupunaChatBubble(
            message: 'reply',
            isCurrentUser: false,
            senderKind: ChatSenderKind.merchantOrBrand,
          ),
        ),
      ),
    );

    final Container avatar = tester.widget<Container>(
      find.byType(Container).at(0),
    );
    final BoxDecoration deco = avatar.decoration! as BoxDecoration;
    expect(deco.color, kIndigo);
  });
}
