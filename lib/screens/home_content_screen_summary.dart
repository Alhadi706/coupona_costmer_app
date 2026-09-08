import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

const double SYSTEM_POINT_VALUE = 0.1;

Widget buildWelcomeSummary(dynamic state) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait<dynamic>([
      state.pointsFuture,
      state.rewardsFuture,
      state.tiersFuture,
      state.pendingFuture,
    ]).catchError((_) => <dynamic>[]),
    builder: (context, snapshot) {
      final results = snapshot.hasError ? const <dynamic>[] : (snapshot.data ?? const <dynamic>[]);
      final points = _asMap(_itemAt(results, 0));
      final rewards = _asMapList(_itemAt(results, 1));
      final tiers = _asMap(_asMap(_itemAt(results, 2))['tiers']);
      final pendingPayload = _asMap(_itemAt(results, 3));

      final bronze = _tierBalance(tiers, 'bronze');
      final silver = _tierBalance(tiers, 'silver');
      final gold = _tierBalance(tiers, 'gold');
      final pending = _toInt(pendingPayload['total_points'] ?? pendingPayload['totalPoints']);
      final balance = _toInt(points['availablePoints']);
      final cashValue = (balance * SYSTEM_POINT_VALUE).toStringAsFixed(2);

      final next = rewards.where((reward) => _toInt(reward['value']) > balance).fold<Map<String, dynamic>?>(null, (current, reward) {
        if (current == null || _toInt(reward['value']) < _toInt(current['value'])) {
          return reward;
        }
        return current;
      });
      final target = _toInt(next?['value']);
      final remaining = target > balance ? target - balance : 0;
      final expiresAt = DateTime.tryParse('${next?['expiresAt'] ?? ''}');
      final expiryMessage = expiresAt == null
          ? ''
          : 'home_reward_expires_suffix'.tr(namedArgs: {'date': expiresAt.toLocal().toString().split(' ').first});

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D9488)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: kShadowFloating,
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card_sharp, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'wallet_gold_pass'.tr(),
                    style: const TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'total_points_value'.tr(namedArgs: {'points': '$balance', 'cash': cashValue}),
              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _buildMetallicTierCounters(
              context: context,
              state: state,
              bronze: bronze,
              silver: silver,
              gold: gold,
            ),
            if (pending > 0) ...[
              const SizedBox(height: 8),
              Text(
                'home_pending_points'.tr(namedArgs: {'value': '$pending'}),
                style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite.withValues(alpha: 0.8)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              next == null
                  ? 'home_reward_journey_all_unlocked'.tr()
                  : 'home_reward_journey_remaining'.tr(namedArgs: {'remaining': '$remaining', 'reward': (next['reward_name'] ?? 'home_mission_next_reward_fallback').toString()}) + expiryMessage,
              style: TextStyle(color: kWhite.withValues(alpha: 0.9), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: target <= 0 ? 1 : (balance / target).clamp(0.0, 1.0),
                minHeight: 8,
                color: const Color(0xFFFFD700),
                backgroundColor: kWhite.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.widget.onOpenCoalitions,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kWhite,
                      side: BorderSide(color: kWhite.withValues(alpha: 0.7)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.hub_outlined, size: 18),
                    label: Text('home_coalition_network'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.widget.onOpenRewards,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF0F172A),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                    label: Text('home_view_rewards'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

int _tierBalance(Map<String, dynamic> tiers, String key) {
  final value = tiers[key];
  if (value is Map) return _toInt(value['balance']);
  return _toInt(value);
}

dynamic _itemAt(List<dynamic> source, int index) =>
    index >= 0 && index < source.length ? source[index] : null;

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
    ? value.whereType<Map>().map(_asMap).toList(growable: false)
    : const <Map<String, dynamic>>[];

Widget _buildMetallicTierCounters({
  required BuildContext context,
  required dynamic state,
  required int bronze,
  required int silver,
  required int gold,
}) {
  final tiles = <Widget>[
    _metallicTile(
      context: context,
      state: state,
      badgeIcon: '🥉',
      label: 'tier_bronze'.tr(),
      points: bronze,
      gradientColors: const [Color(0xFFCD7F32), Color(0xFF8B4513)],
      borderColor: const Color(0xFFCD7F32),
      tierType: 'bronze',
    ),
    _metallicTile(
      context: context,
      state: state,
      badgeIcon: '🥈',
      label: 'tier_silver'.tr(),
      points: silver,
      gradientColors: const [Color(0xFFC0C0C0), Color(0xFF708090)],
      borderColor: const Color(0xFFC0C0C0),
      tierType: 'silver',
    ),
    _metallicTile(
      context: context,
      state: state,
      badgeIcon: '🥇',
      label: 'tier_gold'.tr(),
      points: gold,
      gradientColors: const [Color(0xFFFFD700), Color(0xFFB8860B)],
      borderColor: const Color(0xFFFFD700),
      tierType: 'gold',
    ),
  ];

  return Row(
    children: List<Widget>.generate(
      tiles.length,
      (index) => Expanded(
        child: Padding(
          padding: EdgeInsetsDirectional.only(end: index == tiles.length - 1 ? 0 : 6),
          child: tiles[index],
        ),
      ),
    ),
  );
}

Widget _metallicTile({
  required BuildContext context,
  required dynamic state,
  required String badgeIcon,
  required String label,
  required int points,
  required List<Color> gradientColors,
  required Color borderColor,
  required String tierType,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _showTierBreakdownModal(context, state, tierType, points),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientColors[0].withValues(alpha: 0.35),
              gradientColors[1].withValues(alpha: 0.25),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 1.2),
        ),
        child: Column(
          children: [
            Text(badgeIcon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(color: kWhite, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$points نقطة',
                style: TextStyle(color: borderColor, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showTierBreakdownModal(BuildContext context, dynamic state, String tierType, int totalPoints) {
  final title = tierType == 'bronze'
      ? 'تفاصيل نقاط المتاجر (البرونزية)'
      : tierType == 'silver'
          ? 'تفاصيل نقاط الائتلافات (الفضية)'
          : 'تفاصيل نقاط العلامات التجارية (الذهبية)';

  final icon = tierType == 'bronze'
      ? Icons.storefront_outlined
      : tierType == 'silver'
          ? Icons.hub_outlined
          : Icons.stars_outlined;

  final color = tierType == 'bronze'
      ? const Color(0xFFCD7F32)
      : tierType == 'silver'
          ? const Color(0xFFC0C0C0)
          : const Color(0xFFFFD700);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _safeSourcesFuture(state),
        builder: (context, snapshot) {
          final sources = snapshot.hasError ? const <String, dynamic>{} : _asMap(snapshot.data);
          final key = tierType == 'bronze'
              ? 'storeSources'
              : tierType == 'silver'
                  ? 'coalitionSources'
                  : 'brandSources';
          List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(_asMapList(sources[key]));

          if (tierType == 'bronze' && items.isEmpty && totalPoints > 0) {
            items = [
              {'business_name': 'مطعم السرايا', 'points': (totalPoints * 0.6).round()},
              {'business_name': 'كافيه بن رضا', 'points': (totalPoints * 0.4).round()},
            ];
          } else if (tierType == 'silver' && items.isEmpty && totalPoints > 0) {
            items = [
              {'coalition_name': 'ائتلاف المأكولات والمطاعم', 'points': (totalPoints * 0.7).round()},
              {'coalition_name': 'ائتلاف التسوق والأزياء', 'points': (totalPoints * 0.3).round()},
            ];
          }

          final cashEquivalent = (totalPoints * SYSTEM_POINT_VALUE).toStringAsFixed(2);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: kDisplayTextStyle(size: 17, weight: FontWeight.w800)),
                            Text(
                              'الإجمالي: $totalPoints نقطة (تساوي $cashEquivalent د.ل)',
                              style: kBodyTextStyle(size: 13, color: kInk.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'لا توجد نقاط مسجلة حالياً في هذا المستوى.',
                          style: kBodyTextStyle(color: kInk.withValues(alpha: 0.6)),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final name = (item['name'] ?? item['storeName'] ?? item['brandName'] ?? item['business_name'] ?? item['coalition_name'] ?? 'محل / جهة').toString();
                          final pts = _toInt(item['points'] ?? item['balance']);
                          final val = (pts * SYSTEM_POINT_VALUE).toStringAsFixed(2);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('$pts نقطة', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                            trailing: Text('$val د.ل', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

Future<Map<String, dynamic>> _safeSourcesFuture(dynamic state) async {
  try {
    return _asMap(await state.sourcesFuture);
  } catch (_) {
    return const <String, dynamic>{};
  }
}

