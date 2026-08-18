import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'kupuna_bottom_navbar.dart';
import 'kupuna_cashier_mode_screen_wrapper.dart';
import 'kupuna_chat_bubble.dart';
import 'kupuna_dual_wallet_rings.dart';
import 'kupuna_loyalty_health_ring.dart';
import 'kupuna_offer_card.dart';
import 'kupuna_status_pill.dart';
import 'kupuna_top_tabs.dart';

class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() => _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  int _tab = 0;
  KupunaNavItem _nav = KupunaNavItem.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System Gallery')),
      bottomNavigationBar: KupunaBottomNavbar(
        activeItem: _nav,
        onTap: (item) => setState(() => _nav = item),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kPaddingCard),
        children: [
          KupunaTopTabs(
            tabs: const ['اكتشف', 'العروض', 'إعلانات الأفراد'],
            activeIndex: _tab,
            onSelect: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: kGapList),
          KupunaOfferCard(
            offer: const {'title': 'عرض علامة', 'category': 'خصم', 'sourceType': 'brand'},
            onTap: () {},
          ),
          const SizedBox(height: kGapTight),
          KupunaOfferCard(
            offer: const {'title': 'إعلان فرد', 'category': 'من المجتمع', 'sourceType': 'peer'},
            onTap: () {},
          ),
          const SizedBox(height: kGapList),
          const KupunaChatBubble(
            message: 'مرحبًا! هذا مثال فقاعة عضو.',
            isCurrentUser: false,
            senderKind: ChatSenderKind.customer,
          ),
          const SizedBox(height: kGapTight),
          const KupunaChatBubble(
            message: 'تم استلام الرسالة.',
            isCurrentUser: true,
            senderKind: ChatSenderKind.merchantOrBrand,
          ),
          const SizedBox(height: kGapList),
          const KupunaDualWalletRings(
            merchantPoints: 420,
            brandPoints: 180,
          ),
          const SizedBox(height: kGapList),
          Container(
            padding: const EdgeInsets.all(kPaddingCardCompact),
            decoration: BoxDecoration(
              color: kIndigo,
              borderRadius: BorderRadius.circular(kRadiusCard),
            ),
            child: const Center(
              child: KupunaLoyaltyHealthRing(scorePercent: 78),
            ),
          ),
          const SizedBox(height: kGapList),
          const Row(
            children: [
              KupunaStatusPill(kind: StatusPillKind.pending),
              SizedBox(width: kGapTight),
              KupunaStatusPill(kind: StatusPillKind.approvedTeal),
              SizedBox(width: kGapTight),
              KupunaStatusPill(kind: StatusPillKind.rejected),
            ],
          ),
          const SizedBox(height: kGapList),
          SizedBox(
            height: 280,
            child: KupunaCashierModeScreenWrapper(
              storeName: 'Store Demo',
              onGrantPoints: _noop,
              onRedeemReward: _noop,
              body: SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}
