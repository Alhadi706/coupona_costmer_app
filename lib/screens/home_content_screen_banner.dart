import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'ads_banner_slider.dart';

Widget buildTopHeader(dynamic state) {
  return FutureBuilder<Map<String, dynamic>>(
    future: _safePointsFuture(state),
    builder: (context, snapshot) {
      final pointsData = snapshot.hasError
          ? const <String, dynamic>{}
          : _asMap(snapshot.data);
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
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: kTealDark,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لا توجد إشعارات جديدة حالياً.'),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            Text(
              'كوبونا',
              style: kDisplayTextStyle(
                size: 20,
                weight: FontWeight.w900,
                color: kTealDark,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealDark, kTeal]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'رصيدك: $cashValue د.ل',
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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
      final results = snapshot.hasError
          ? const <dynamic>[]
          : (snapshot.data ?? const <dynamic>[]);
      final billboardAds = _asMapList(results.isNotEmpty ? results[0] : null);
      final customerBanners = _asMapList(
        results.length > 1 ? results[1] : null,
      );
      final combined = <Map<String, dynamic>>[
        for (final ad in [...customerBanners, ...billboardAds])
          {
            ...ad,
            'title': (ad['title']?.toString() == 'merchant test offer')
                ? 'عروض رائعة مميزة بانتظارك'
                : ad['title'],
            'description':
                (ad['description']?.toString() == 'merchant test offer')
                ? 'خصومات كبرى وعروض حصرية وفريدة لعملاء كوبونا!'
                : ad['description'],
          },
      ];
      if (combined.isNotEmpty) {
        return AdsBannerSlider(
          ads: combined,
          height: 164,
          onAdTap: state.handleBillboardTap,
          onAdImpression: (ad) {
            final id = (ad['id'] ?? '').toString();
            if (id.isNotEmpty) {
              CompanyServerService.trackBillboardImpression(
                id,
              ).catchError((_) {});
            }
          },
        );
      }
      final defaultBanners = <Map<String, dynamic>>[
        {
          'id': 'default_banner_1',
          'title': 'home_banner_title'.tr(),
          'description': 'home_banner_1'.tr(),
        },
        {
          'id': 'default_banner_2',
          'title': 'home_banner_title'.tr(),
          'description': 'home_banner_2'.tr(),
        },
        {
          'id': 'default_banner_3',
          'title': 'home_banner_title'.tr(),
          'description': 'home_banner_3'.tr(),
        },
      ];
      return AdsBannerSlider(
        ads: defaultBanners,
        height: 164,
        onAdTap: (ad) {},
      );
    },
  );
}
