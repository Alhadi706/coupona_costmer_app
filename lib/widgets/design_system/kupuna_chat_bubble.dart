import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

enum ChatSenderKind {
  customer,
  merchantOrBrand,
}

class KupunaChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final ChatSenderKind senderKind;

  const KupunaChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.senderKind = ChatSenderKind.customer,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(kRadiusCardCompact),
            topRight: Radius.circular(kRadiusCardCompact),
            bottomLeft: Radius.circular(kRadiusBubbleTail),
            bottomRight: Radius.circular(kRadiusCardCompact),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(kRadiusCardCompact),
            topRight: Radius.circular(kRadiusCardCompact),
            bottomLeft: Radius.circular(kRadiusCardCompact),
            bottomRight: Radius.circular(kRadiusBubbleTail),
          );

    final Color avatarColor =
        senderKind == ChatSenderKind.merchantOrBrand ? kIndigo : kGold;

    final Widget avatar = Container(
      width: kChatAvatarSize,
      height: kChatAvatarSize,
      decoration: BoxDecoration(
        color: avatarColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        senderKind == ChatSenderKind.merchantOrBrand ? Icons.storefront : Icons.person,
        size: 16,
        color: kWhite,
      ),
    );

    final Widget bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.all(kPaddingCardCompact),
        decoration: BoxDecoration(
          color: isCurrentUser ? kTeal : kWhite,
          borderRadius: radius,
          border: isCurrentUser
              ? null
              : Border.all(color: kLine, width: kBorderWidth),
        ),
        child: Text(
          message,
          style: kBodyTextStyle(
            size: kBubbleFontSize,
            weight: FontWeight.w400,
            color: isCurrentUser ? kWhite : kInk,
          ),
        ),
      ),
    );

    final List<Widget> rowChildren = isCurrentUser
        ? <Widget>[bubble, const SizedBox(width: kGapTight), avatar]
        : <Widget>[avatar, const SizedBox(width: kGapTight), bubble];

    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: rowChildren,
    );
  }
}
