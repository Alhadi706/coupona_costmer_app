import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_offer_card.dart';
import 'home_content_screen_discover.dart';

extension StreamStartWithFuture<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}

String _sanitizeOfferTitle(dynamic rawTitle, dynamic rawDescription) {
  final t = rawTitle?.toString() ?? '';
  final d = rawDescription?.toString() ?? '';
  if (t == 'merchant test offer' || d == 'merchant test offer') {
    return 'عرض ترويجي لعملاء كوبونا المميزين';
  }
  if (d.isNotEmpty && d != 'null') return d;
  if (t.isNotEmpty && t != 'null') return t;
  return 'new_offer'.tr();
}

Widget buildOffersList(dynamic state, {required String heading, required String emptyKey, required String? sourceType, required VoidCallback? onHeaderAction}) {
  return HomeContentSectionCard(
    title: heading,
    subtitle: 'home_list_live_subtitle'.tr(),
    action: onHeaderAction == null ? null : TextButton(onPressed: onHeaderAction, child: Text('home_open_tab'.tr())),
    child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.periodic(const Duration(seconds: 8)).asyncMap((_) => CompanyServerService.getOffers()).startWithFuture(CompanyServerService.getOffers()),
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
        }
        final keyword = state.searchController.text.trim().toLowerCase();
        final rows = snapshot.data!.where((row) {
          final title = (row['description'] ?? row['title'] ?? '').toString().toLowerCase();
          final category = (row['category'] ?? '').toString().toLowerCase();
          final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '').toString().toLowerCase();
          if (sourceType != null && !ownerType.contains(sourceType)) return false;
          if (keyword.isEmpty) return true;
          return title.contains(keyword) || category.contains(keyword);
        }).toList(growable: false);
        if (rows.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(emptyKey.tr()));
        }
        return Column(
          children: rows.take(6).map((offer) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KupunaOfferCard(
              offer: <String, dynamic>{
                ...offer,
                'title': _sanitizeOfferTitle(offer['title'], offer['description']),
                'subtitle': (offer['category'] ?? '').toString(),
              },
            ),
          )).toList(growable: false),
        );
      },
    ),
  );
}

Widget buildPeerAdsList(dynamic state) {
  return HomeContentSectionCard(
    title: 'home_peer_ads_section_title'.tr(),
    subtitle: 'home_peer_ads_section_subtitle'.tr(),
    action: TextButton(onPressed: state.widget.onOpenPeerAdsTab, child: Text('home_open_tab'.tr())),
    child: StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.periodic(const Duration(seconds: 8)).asyncMap((_) => CompanyServerService.getOffers()).startWithFuture(CompanyServerService.getOffers()),
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
        }
        final keyword = state.searchController.text.trim().toLowerCase();
        final rows = snapshot.data!.where((row) {
          final ownerType = (row['ownerType'] ?? row['sourceType'] ?? '').toString().toLowerCase();
          final title = (row['description'] ?? row['title'] ?? '').toString().toLowerCase();
          final category = (row['category'] ?? '').toString().toLowerCase();
          final isPeer = ownerType.contains('peer') || ownerType.contains('individual');
          if (!isPeer) return false;
          if (keyword.isEmpty) return true;
          return title.contains(keyword) || category.contains(keyword);
        }).toList(growable: false);
        if (rows.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('home_peer_ads_empty'.tr()));
        }
        return Column(
          children: rows.take(6).map((offer) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KupunaOfferCard(
              offer: <String, dynamic>{
                ...offer,
                'title': _sanitizeOfferTitle(offer['title'], offer['content'] ?? offer['description']),
                'subtitle': (offer['targetValue'] ?? offer['category'] ?? '').toString(),
                'sourceType': 'peer',
              },
            ),
          )).toList(growable: false),
        );
      },
    ),
  );
}

Widget buildBrandPointsBreakdown(dynamic state) {
  return FutureBuilder<Map<String, dynamic>>(
    future: (state.sourcesFuture as Future<Map<String, dynamic>>?),
    builder: (context, snapshot) {
      final payload = snapshot.data ?? const <String, dynamic>{};
      final brands = payload['brandSources'] is List ? List<Map<String, dynamic>>.from(payload['brandSources'] as List) : <Map<String, dynamic>>[];
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()));
      }
      if (brands.isEmpty) {
        return HomeContentSectionCard(
          title: 'نقاط العلامات التجارية',
          subtitle: 'تفكيك مصدر النقاط من البراندات المشتركة.',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('لا توجد نقاط علامات تجارية مسجلة حالياً', style: TextStyle(color: kInk.withValues(alpha: 0.6), fontSize: 13)),
          ),
        );
      }
      return HomeContentSectionCard(
        title: 'نقاط العلامات التجارية',
        subtitle: 'تفكيك مصدر النقاط من البراندات المشتركة.',
        child: Column(
          children: brands.map((brand) {
            final active = _toInt(brand['activePoints']);
            final lifetime = _toInt(brand['lifetimePoints']);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: kMint, child: Icon(Icons.verified_outlined, color: kTeal)),
              title: Text((brand['sourceName'] ?? 'Brand').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('إجمالي مكتسب: $lifetime نقطة'),
              trailing: Text('$active نقطة', style: const TextStyle(color: kTeal, fontWeight: FontWeight.w900)),
            );
          }).toList(),
        ),
      );
    },
  );
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}
