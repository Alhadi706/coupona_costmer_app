import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';
import 'ads_banner_slider.dart';
import 'customer_coalitions_screen.dart';
import 'customer_gifts_screen.dart';
import 'customer_offers_screen.dart';
import 'home_content_screen_discover.dart';
import 'home_content_screen_offers.dart';
import 'my_rewards_screen.dart';
import 'wallet_engine_screen.dart';

Widget buildTopHeader(dynamic state) {
  return FutureBuilder<Map<String, dynamic>>(
    future: _safePointsFuture(state),
    builder: (context, snapshot) {
      final pointsData = snapshot.hasError ? const <String, dynamic>{} : _asMap(snapshot.data);
      final points = _toInt(pointsData['availablePoints']);
      final cashValue = (points * 0.1).toStringAsFixed(2);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, color: kTealDark),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا توجد إشعارات جديدة حالياً.')),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(
              'كوبونا',
              style: kDisplayTextStyle(size: 20, weight: FontWeight.w900, color: kTealDark),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kTealDark, kTeal],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'رصيدك: $cashValue د.ل',
                style: const TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.person_outline, color: kTealDark),
              onPressed: () {
                try {
                  Scaffold.of(context).openDrawer();
                } catch (_) {}
              },
            ),
          ],
        ),
      );
    },
  );
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
    ? value.whereType<Map>().map(_asMap).toList(growable: false)
    : const <Map<String, dynamic>>[];

Future<Map<String, dynamic>> _safePointsFuture(dynamic state) async {
  try {
    return _asMap(await state.pointsFuture);
  } catch (_) {
    return const <String, dynamic>{};
  }
}

Widget buildBanner(dynamic state) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait<dynamic>([
      state.billboardAdsFuture,
      state.customerBannersFuture,
    ]).catchError((_) => <dynamic>[]),
    builder: (context, snapshot) {
      final results = snapshot.hasError ? const <dynamic>[] : (snapshot.data ?? const <dynamic>[]);
      final billboardAds = _asMapList(results.isNotEmpty ? results[0] : null);
      final customerBanners = _asMapList(results.length > 1 ? results[1] : null);
      final combined = <Map<String, dynamic>>[
        for (final ad in [...customerBanners, ...billboardAds])
          {
            ...ad,
            'title': (ad['title']?.toString() == 'merchant test offer')
                ? 'عروض رائعة مميزة بانتظارك'
                : ad['title'],
            'description': (ad['description']?.toString() == 'merchant test offer')
                ? 'خصومات كبرى وعروض حصرية وفريدة لعملاء كوبونا!'
                : ad['description'],
          }
      ];
      if (combined.isNotEmpty) {
        return AdsBannerSlider(
          ads: combined,
          height: 164,
          onAdTap: state.handleBillboardTap,
          onAdImpression: (ad) {
            final id = (ad['id'] ?? '').toString();
            if (id.isNotEmpty) {
              CompanyServerService.trackBillboardImpression(id).catchError((_) {});
            }
          },
        );
      }
      final defaultBanners = <Map<String, dynamic>>[
        {'id': 'default_banner_1', 'title': 'home_banner_title'.tr(), 'description': 'home_banner_1'.tr()},
        {'id': 'default_banner_2', 'title': 'home_banner_title'.tr(), 'description': 'home_banner_2'.tr()},
        {'id': 'default_banner_3', 'title': 'home_banner_title'.tr(), 'description': 'home_banner_3'.tr()},
      ];
      return AdsBannerSlider(ads: defaultBanners, height: 164, onAdTap: (ad) {});
    },
  );
}

Widget buildQuickShortcutActions(dynamic state) {
  final actions = <_ShortcutItem>[
    _ShortcutItem(icon: Icons.calculate_outlined, label: "حاسبة الخصم", color: kTeal, onTap: () {
      Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => const MyRewardsScreen(openDynamicVoucherOnLoad: true)));
    }),
    _ShortcutItem(icon: Icons.camera_alt_outlined, label: "مسح الفاتورة", color: const Color(0xFFE53935), onTap: () {
      state.widget.onScanReceipt?.call();
    }),
    _ShortcutItem(icon: Icons.card_giftcard_outlined, label: "هداياي الخاصة", color: kGold, onTap: () {
      Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => const CustomerGiftsScreen()));
    }),
    _ShortcutItem(icon: Icons.local_offer_outlined, label: "عروض الزبائن", color: const Color(0xFF6D4C41), onTap: () {
      if (state.widget.onOpenCustomerOffers != null) {
        state.widget.onOpenCustomerOffers!();
        return;
      }
      Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => const CustomerOffersScreen()));
    }),
    _ShortcutItem(icon: Icons.storefront_outlined, label: "سوق المجتمع", color: const Color(0xFF1E88E5), onTap: () {
      state.widget.onOpenCommunity?.call();
    }),
    _ShortcutItem(icon: Icons.account_balance_wallet_outlined, label: 'home_bottom_wallet'.tr(), color: const Color(0xFF7C3AED), onTap: () {
      Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => const WalletEngineScreen()));
    }),
    _ShortcutItem(icon: Icons.hub_outlined, label: 'home_coalition_network'.tr(), color: const Color(0xFF0D9488), onTap: () {
      if (state.widget.onOpenCoalitions != null) {
        state.widget.onOpenCoalitions!();
        return;
      }
      Navigator.of(state.context).push(MaterialPageRoute(builder: (_) => const CustomerCoalitionsScreen()));
    }),
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: actions.map((item) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 10),
        child: Material(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 20, color: item.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      )).toList(),
    ),
  );
}

Widget buildSearchBar(dynamic state) {
  return Material(
    elevation: 1,
    borderRadius: BorderRadius.circular(14),
    child: TextField(
      controller: state.searchController,
      onChanged: state.handleSearchChanged,
      decoration: InputDecoration(
        hintText: 'home_search_hint'.tr(),
        prefixIcon: const Icon(Icons.search, color: kTeal),
        filled: true,
        fillColor: kWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

Widget buildTopTabs(dynamic state) {
  return KupunaTopTabs(
    tabs: <String>['home_tab_discover'.tr(), 'home_tab_offers'.tr(), 'home_tab_peer_ads'.tr()],
    activeIndex: state.activeTab,
    onSelect: state.handleTabChanged,
  );
}

Widget buildTabBody(dynamic state) {
  switch (state.activeTab) {
    case 1:
      return buildOffersList(state, heading: 'home_offers_section_title'.tr(), sourceType: 'brand', emptyKey: 'home_offers_empty', onHeaderAction: state.widget.onOpenOffersTab);
    case 2:
      return buildPeerAdsList(state);
    default:
      return buildDiscoverTab(state);
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutItem({required this.icon, required this.label, required this.color, required this.onTap});
}
