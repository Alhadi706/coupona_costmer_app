import 'package:flutter/material.dart';

const String kDisplayFontFamily = 'Cairo';
const String kBodyFontFamily = 'IBM Plex Sans Arabic';

// Color tokens (section 18-a.1)
const Color kInk = Color(0xFF16241F);
const Color kSand = Color(0xFFF3F1E8);
const Color kWhite = Color(0xFFFFFEFB);
const Color kGold = Color(0xFFD9A441);
const Color kTeal = Color(0xFF1B7A6B);
const Color kTealDark = Color(0xFF12594E);
const Color kMint = Color(0xFF7FD9C4);
const Color kIndigo = Color(0xFF263859);
const Color kIndigoLight = Color(0xFF34496E);
const Color kViolet = Color(0xFF6C3FA8);
const Color kLine = Color.fromRGBO(22, 36, 31, 0.12);
const Color kLineDark = Color.fromRGBO(255, 255, 255, 0.12);

// Radius and spacing tokens (section 18-a.4)
const double kRadiusCard = 16;
const double kRadiusCardCompact = 14;
const double kRadiusCardLarge = 18;
const double kRadiusPill = 100;
const double kRadiusHeaderBottom = 26;
const double kRadiusMerchantPanel = 26;

const double kPaddingCard = 16;
const double kPaddingCardCompact = 12;
const double kGapList = 10;
const double kGapTight = 8;
const double kBorderWidth = 1;

// Shared component tokens (section 18-b)
const double kBottomNavFontSize = 10;
const double kBottomNavInactiveAlpha = 0.5;

const double kTopTabPaddingVertical = 6;
const double kTopTabPaddingHorizontal = 12;

const double kOfferImageSize = 44;
const double kOfferTitleFontSize = 12.5;
const double kOfferSubtitleFontSize = 11;
const double kBadgeFontSize = 9;
const double kBadgePaddingVertical = 4;
const double kBadgePaddingHorizontal = 8;
const double kRadiusOfferImage = 12;

const double kChatAvatarSize = 30;
const double kRadiusBubbleTail = 4;
const double kBubbleFontSize = 12;

const double kWalletRingStrokeWidth = 10;
const double kWalletInnerInset = 16;
const double kWalletCenterNumberSize = 24;
const double kWalletCenterCaptionSize = 11;
const double kWalletLegendDotSize = 10;

const double kLoyaltyRingStrokeWidth = 10;
const double kLoyaltyInnerSizeFactor = 0.56;
const double kLoyaltyNumberFontSize = 24;

const double kCashierBadgeAlpha = 0.18;
const double kCashierButtonAlpha = 0.14;
const double kCashierScanBoxSize = 170;
const double kCashierScanRadius = 24;
const double kCashierModeTitleSize = 22;

const double kStatusPillFontSize = 9;
const double kStatusPillHorizontalPadding = 10;
const double kStatusPillVerticalPadding = 4;

// Shadow tokens (section 18-a.5)
final List<BoxShadow> kShadowFloating = <BoxShadow>[
  const BoxShadow(
    color: Color.fromRGBO(22, 36, 31, 0.32),
    offset: Offset(0, 30),
    blurRadius: 60,
    spreadRadius: -20,
  ),
];

TextStyle kDisplayTextStyle({
  double size = 24,
  FontWeight weight = FontWeight.w800,
  Color color = kInk,
  double? height,
}) {
  return TextStyle(
    fontFamily: kDisplayFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

TextStyle kBodyTextStyle({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = kInk,
  double? height,
}) {
  return TextStyle(
    fontFamily: kBodyFontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

TextStyle kPointsNumberStyle({
  double size = 24,
  FontWeight weight = FontWeight.w800,
  Color color = kGold,
}) {
  final FontWeight resolvedWeight =
      weight == FontWeight.w900 ? FontWeight.w900 : FontWeight.w800;
  return TextStyle(
    fontFamily: kDisplayFontFamily,
    fontSize: size,
    fontWeight: resolvedWeight,
    color: color,
  );
}
