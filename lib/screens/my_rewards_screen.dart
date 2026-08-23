import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';

class _TxEntry {
  final DateTime date;
  final String label;
  final int points;

  const _TxEntry({required this.date, required this.label, required this.points});
}

class _PointsRingPainter extends CustomPainter {
  final double progress;

  const _PointsRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - kLoyaltyRingStrokeWidth;
    final Rect ringRect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kLoyaltyRingStrokeWidth
      ..strokeCap = StrokeCap.round
      ..color = kLine;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kLoyaltyRingStrokeWidth
      ..strokeCap = StrokeCap.round
      ..color = kGold;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(ringRect, -math.pi / 2, progress.clamp(0.0, 1.0) * math.pi * 2, false, arc);
  }

  @override
  bool shouldRepaint(covariant _PointsRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MyRewardsScreen extends StatefulWidget {
  const MyRewardsScreen({super.key});

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  bool _loading = true;
  bool _redeeming = false;
  Map<String, dynamic> _points = const <String, dynamic>{};
  List<Map<String, dynamic>> _rewards = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _claims = const <Map<String, dynamic>>[];
  int _rewardTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await CompanyServerService.ensureAccountingDocuments();
      final results = await Future.wait<dynamic>([
        CompanyServerService.getPointAccount(),
        CompanyServerService.getRewards(),
        CompanyServerService.getLedgerEntries(limit: 20),
        CompanyServerService.getMyRewardClaims(limit: 20),
      ]);

      if (!mounted) return;
      setState(() {
        _points = (results[0] as Map<String, dynamic>);
        _rewards = (results[1] as List<Map<String, dynamic>>);
        _ledger = (results[2] as List<Map<String, dynamic>>);
        _claims = (results[3] as List<Map<String, dynamic>>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('rewards_load_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatLedgerType(String type) {
    switch (type) {
      case 'cashbackEarned':
        return 'ledger_cashback_earned'.tr();
      case 'pointsEarned':
        return 'ledger_points_earned'.tr();
      case 'pointsRedeemed':
        return 'ledger_points_redeemed'.tr();
      default:
        return type;
    }
  }

  /// Returns the smallest reward value strictly greater than [availablePoints],
  /// or null if every known reward is already unlocked.
  int? _nextMilestoneValue(int availablePoints) {
    int? next;
    for (final reward in _rewards) {
      final value = _toInt(reward['value']);
      if (value > availablePoints && (next == null || value < next)) {
        next = value;
      }
    }
    return next;
  }

  String? _resolveClaimRewardName(Map<String, dynamic> claim) {
    final sourceId = (claim['sourceId'] ?? '').toString();
    final pointsCost = _toInt(claim['pointsCost']);
    if (sourceId.isEmpty) return null;
    for (final reward in _rewards) {
      if ((reward['id'] ?? '').toString() == sourceId) {
        return (reward['reward_name'] ?? '').toString();
      }
    }
    for (final reward in _rewards) {
      final rewardSourceId = (reward['sourceId'] ?? '').toString();
      if (rewardSourceId.isNotEmpty &&
          rewardSourceId == sourceId &&
          _toInt(reward['value']) == pointsCost) {
        return (reward['reward_name'] ?? '').toString();
      }
    }
    return null;
  }

  String _claimRewardLabel(Map<String, dynamic> claim) {
    final name = _resolveClaimRewardName(claim);
    if (name != null && name.isNotEmpty) return name;
    final points = _toInt(claim['pointsCost']);
    return 'coupon_value_label'.tr(namedArgs: {'value': '$points'});
  }

  List<_TxEntry> _buildTransactions() {
    final List<_TxEntry> items = [];
    for (final entry in _ledger) {
      final points = _toInt(entry['points']);
      if (points == 0) continue;
      final type = (entry['type'] ?? '').toString();
      final date = DateTime.tryParse((entry['createdAt'] ?? '').toString()) ?? DateTime.now();
      final label = type == 'pointsEarned'
          ? 'tx_receipt_scan_approved'.tr()
          : (type == 'pointsRedeemed' ? 'tx_reward_redeemed_generic'.tr() : _formatLedgerType(type));
      items.add(_TxEntry(date: date, label: label, points: points));
    }
    for (final claim in _claims) {
      final pointsCost = _toInt(claim['pointsCost']);
      if (pointsCost <= 0) continue;
      final date = DateTime.tryParse((claim['createdAt'] ?? '').toString()) ?? DateTime.now();
      final rewardName = _resolveClaimRewardName(claim);
      final label = (rewardName != null && rewardName.isNotEmpty)
          ? 'tx_reward_redeemed'.tr(namedArgs: {'reward': rewardName})
          : 'tx_reward_redeemed_generic'.tr();
      items.add(_TxEntry(date: date, label: label, points: -pointsCost));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items.take(20).toList();
  }

  String _formatTxDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _redeemReward(Map<String, dynamic> reward) async {
    if (_redeeming) return;
    final requiredPoints = _toInt(reward['value']);
    final currentPoints = _toInt(_points['availablePoints']);
    if (requiredPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_invalid_value'.tr())),
      );
      return;
    }
    if (currentPoints < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_insufficient_points'.tr())),
      );
      return;
    }

    setState(() => _redeeming = true);
    try {
      final rewardKind = (reward['kind'] ?? 'digital').toString();
      final claim = await CompanyServerService.createRewardClaim(
        pointsCost: requiredPoints,
        rewardId: (reward['id'] ?? '').toString(),
        sourceType: (reward['sourceType'] ?? 'system').toString(),
        sourceId: (reward['sourceId'] ?? reward['id'] ?? '').toString(),
        rewardKind: rewardKind,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_redeemed_success'.tr(
          namedArgs: {'reward': '${reward['reward_name'] ?? 'reward_generic'.tr()}'},
        ))),
      );
      await _loadData();
      if (!mounted) return;
      _showCouponDialog(
        rewardName: (reward['reward_name'] ?? '').toString(),
        rewardKind: rewardKind,
        pickupQrCode: (claim['pickupQrCode'] ?? '').toString(),
        digitalCode: (claim['digitalCode'] ?? '').toString(),
        status: (claim['status'] ?? '').toString(),
        expiresAt: (claim['expiresAt'] ?? '').toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_redeem_error'.tr(namedArgs: {'error': e.toString()}))),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _formatClaimStatus(String status) {
    switch (status) {
      case 'pending_pickup':
        return 'coupon_status_pending_pickup'.tr();
      case 'used':
      case 'redeemed':
        return 'coupon_status_used'.tr();
      case 'expired':
        return 'coupon_status_expired'.tr();
      case 'refunded_as_points':
        return 'coupon_status_refunded_as_points'.tr();
      default:
        return status;
    }
  }

  Color _claimStatusColor(String status) {
    switch (status) {
      case 'pending_pickup':
        return kGold;
      case 'used':
      case 'redeemed':
        return kTeal;
      case 'expired':
      case 'refunded_as_points':
        return Colors.grey;
      default:
        return kTeal;
    }
  }

  void _showCouponDialog({
    required String rewardName,
    required String rewardKind,
    required String pickupQrCode,
    required String digitalCode,
    required String status,
    required String expiresAt,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  rewardName.isEmpty ? 'reward_generic'.tr() : rewardName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_formatClaimStatus(status), style: const TextStyle(color: kTeal)),
                const SizedBox(height: 16),
                if (rewardKind == 'physical' && pickupQrCode.isNotEmpty) ...[
                  QrImageView(data: pickupQrCode, size: 220),
                  const SizedBox(height: 10),
                  Text('coupon_qr_hint'.tr(), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SelectableText(pickupQrCode),
                ] else if (digitalCode.isNotEmpty) ...[
                  Text('coupon_digital_code_label'.tr()),
                  const SizedBox(height: 8),
                  SelectableText(
                    digitalCode,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTeal),
                  ),
                ],
                if (expiresAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('coupon_expires_at'.tr(namedArgs: {'value': expiresAt.split('T').first})),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    label: Text('close'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward, int availablePoints) {
    final cost = _toInt(reward['value']);
    final locked = availablePoints < cost;
    final remaining = (cost - availablePoints).clamp(0, cost);
    final storeName = (reward['storeName'] ?? '').toString();
    final imageUrl = (reward['imageUrl'] ?? '').toString();
    final rewardName = (reward['reward_name'] ?? '').toString();
    final fallbackIcon = rewardName.toLowerCase().contains('coffee') || rewardName.contains('قهوة')
      ? Icons.local_cafe_outlined
      : (rewardName.toLowerCase().contains('meal') || rewardName.contains('وجبة')
        ? Icons.restaurant_outlined
        : Icons.card_giftcard_outlined);

    return Container(
      width: 168,
      height: 236,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked ? kSand : kWhite,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: locked ? kLine : kTeal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kLine,
                  borderRadius: BorderRadius.circular(kRadiusOfferImage),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? Center(child: Icon(fallbackIcon, color: kTeal, size: 28))
                    : null,
              ),
              if (locked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(kRadiusOfferImage),
                    ),
                    child: const Center(child: Icon(Icons.lock_rounded, color: kWhite, size: 26)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rewardName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kBodyTextStyle(size: 13, weight: FontWeight.w700),
          ),
          if (storeName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kBodyTextStyle(size: 11, color: kTeal, weight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 6),
          if (locked)
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: kGold),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'reward_locked_label'.tr(),
                    style: kBodyTextStyle(size: 11, weight: FontWeight.w700, color: kGold),
                  ),
                ),
              ],
            )
          else
            Text(
              'redeem_points_value'.tr(namedArgs: {'value': '$cost'}),
              style: kBodyTextStyle(size: 11, color: kTeal, weight: FontWeight.w700),
            ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'reward_locked_points_needed'.tr(namedArgs: {'value': '$remaining'}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kBodyTextStyle(size: 10.5, color: kInk.withValues(alpha: 0.6)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: cost <= 0 ? 0 : (availablePoints / cost).clamp(0.0, 1.0), minHeight: 5, color: locked ? kGold : kTeal, backgroundColor: kLine)),
                const SizedBox(height: 3),
                Text(locked ? 'جمعت $availablePoints من $cost نقطة' : 'مبروك، وصلت إلى الجائزة!', maxLines: 1, overflow: TextOverflow.ellipsis, style: kBodyTextStyle(size: 10, color: locked ? kInk.withValues(alpha: 0.65) : kTeal, weight: FontWeight.w700)),
              ],
            ),
          ),
          if ((reward['expiresAt'] ?? '').toString().isNotEmpty)
            Text('تنتهي: ${(reward['expiresAt'] ?? '').toString().split('T').first}', style: kBodyTextStyle(size: 10, color: kInk.withValues(alpha: 0.6))),
          if (!locked && (reward['pickupInstructions'] ?? '').toString().isNotEmpty)
            Text('الاستلام: ${(reward['pickupInstructions'] ?? '').toString()}', maxLines: 2, overflow: TextOverflow.ellipsis, style: kBodyTextStyle(size: 10, color: kTeal, weight: FontWeight.w600)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: locked
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock, size: 14),
                    label: Text('reward_locked_label'.tr(), style: const TextStyle(fontSize: 12)),
                  )
                : ElevatedButton(
                    onPressed: _redeeming ? null : () => _redeemReward(reward),
                    child: Text(
                      'redeem_points_value'.tr(namedArgs: {'value': '$cost'}),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availablePoints = _toInt(_points['availablePoints']);
    final kind = _rewardTab == 0 ? 'digital' : 'physical';
    final visibleRewards = _rewards.where((reward) {
      final rewardKind = (reward['kind'] ?? 'digital').toString().toLowerCase();
      return rewardKind == kind;
    }).toList();
    final nextMilestone = _nextMilestoneValue(availablePoints);
    final progress = nextMilestone == null
        ? 1.0
        : (nextMilestone == 0 ? 0.0 : availablePoints / nextMilestone);
    final txItems = _buildTransactions();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'your_points_balance'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: _PointsRingPainter(progress),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$availablePoints', style: kPointsNumberStyle(size: 34, color: kTeal)),
                            Text(
                              'wallet_points_caption'.tr(),
                              style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nextMilestone == null
                        ? 'wallet_all_rewards_unlocked'.tr()
                        : 'wallet_points_to_next_reward'.tr(
                            namedArgs: {'value': '${(nextMilestone - availablePoints).clamp(0, nextMilestone)}'},
                          ),
                    textAlign: TextAlign.center,
                    style: kBodyTextStyle(size: 13, weight: FontWeight.w600, color: kGold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          KupunaTopTabs(
            tabs: const <String>['رقمي', 'مادي'],
            activeIndex: _rewardTab,
            onSelect: (index) => setState(() => _rewardTab = index),
          ),
          const SizedBox(height: 10),
          Text(
            'available_rewards'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (visibleRewards.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('no_rewards_available_now'.tr()),
              ),
            )
          else
            SizedBox(
              height: 236,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visibleRewards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _buildRewardCard(visibleRewards[index], availablePoints),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'my_coupons'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_claims.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('no_coupons_yet'.tr()),
              ),
            )
          else
            ..._claims.map((claim) {
              final status = (claim['status'] ?? '').toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.confirmation_number_outlined, color: _claimStatusColor(status)),
                  title: Text(_claimRewardLabel(claim)),
                  subtitle: Text(_formatClaimStatus(status)),
                  trailing: (status == 'pending_pickup' || status == 'used') &&
                          ((claim['pickupQrCode'] ?? '').toString().isNotEmpty ||
                              (claim['digitalCode'] ?? '').toString().isNotEmpty)
                      ? const Icon(Icons.qr_code_2, color: kTeal)
                      : null,
                  onTap: (status == 'pending_pickup' || status == 'used') &&
                          ((claim['pickupQrCode'] ?? '').toString().isNotEmpty ||
                              (claim['digitalCode'] ?? '').toString().isNotEmpty)
                      ? () => _showCouponDialog(
                            rewardName: _claimRewardLabel(claim),
                            rewardKind: (claim['rewardKind'] ?? 'digital').toString(),
                            pickupQrCode: (claim['pickupQrCode'] ?? '').toString(),
                            digitalCode: (claim['digitalCode'] ?? '').toString(),
                            status: status,
                            expiresAt: (claim['expiresAt'] ?? '').toString(),
                          )
                      : null,
                ),
              );
            }),
          const SizedBox(height: 18),
          Text(
            'transactions_log'.tr(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (txItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('no_log_entries_yet'.tr()),
              ),
            )
          else
            ...txItems.map((tx) {
              final isEarn = tx.points >= 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isEarn ? Icons.receipt_long_outlined : Icons.card_giftcard_outlined,
                    color: isEarn ? kTeal : Colors.redAccent,
                  ),
                  title: Text(tx.label),
                  subtitle: Text(_formatTxDate(tx.date)),
                  trailing: Text(
                    isEarn ? '+${tx.points}' : '${tx.points}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEarn ? kTeal : Colors.redAccent,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

