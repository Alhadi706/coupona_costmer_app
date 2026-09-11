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

Future<Map<String, dynamic>> _safePointsFuture(dynamic state) async {
  try {
    return _asMap(await state.pointsFuture);
  } catch (_) {
    return const <String, dynamic>{};
  }
}

Widget buildBanner(dynamic state) {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: state.billboardAdsFuture,
    builder: (context, snapshot) {
      final billboardAds = snapshot.hasError
          ? const <Map<String, dynamic>>[]
          : (snapshot.data ?? const <Map<String, dynamic>>[]);
      return AdsBannerSlider(
        ads: billboardAds,
        height: 164,
        onAdTap: state.handleBillboardTap,
        onBookingTap: state.handleBookingBannerTap,
        onAdImpression: (ad) {
          final id = (ad['id'] ?? '').toString();
          if (id.isNotEmpty) {
            CompanyServerService.trackBillboardImpression(id).catchError(
              (_) {},
            );
          }
        },
      );
    },
  );
}
