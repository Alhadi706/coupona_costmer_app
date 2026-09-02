import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../modules/redemption/redemption_math.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_top_tabs.dart';
import 'customer_coalitions_screen.dart';

bool shouldAddClaimTransaction(
  Map<String, dynamic> claim,
  Iterable<Map<String, dynamic>> ledger,
) {
  final claimReference = (claim['reference'] ?? 'reward_claim:${claim['id'] ?? ''}').toString();
  return !ledger.any((entry) => (entry['reference'] ?? '').toString() == claimReference);
}

class _TxEntry {
  final DateTime date;
  final String label;
  final int points;

  const _TxEntry({
    required this.date,
    required this.label,
    required this.points,
  });
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
    canvas.drawArc(
      ringRect,
      -math.pi / 2,
      progress.clamp(0.0, 1.0) * math.pi * 2,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _PointsRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MyRewardsScreen extends StatefulWidget {
  final bool embedded;

  const MyRewardsScreen({super.key}) : embedded = false;

  const MyRewardsScreen.embedded({super.key}) : embedded = true;

  @override
  State<MyRewardsScreen> createState() => _MyRewardsScreenState();
}

class _MyRewardsScreenState extends State<MyRewardsScreen> {
  final Map<String, String> _rewardClaimRequestIds = <String, String>{};
  bool _loading = true;
  bool _redeeming = false;
  bool _creatingDynamicVoucher = false;
  final TextEditingController _dynamicVoucherController =
      TextEditingController();
  Map<String, dynamic> _points = const <String, dynamic>{};
  Map<String, dynamic> _tiers = const <String, dynamic>{};
  Map<String, dynamic> _pending = const <String, dynamic>{};
  Map<String, dynamic> _giftCatalog = const <String, dynamic>{};
  List<Map<String, dynamic>> _rewards = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _claims = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _giftUnlocked = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _giftLocked = const <Map<String, dynamic>>[];
  int _sectionTab = 0;
  int _rewardTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await CompanyServerService.ensureAccountingDocuments().catchError(
        (_) => null,
      );
      final pointsFuture = CompanyServerService.getPointAccount().catchError(
        (_) => <String, dynamic>{},
      );
      final rewardsFuture = CompanyServerService.getRewards().catchError(
        (_) => <Map<String, dynamic>>[],
      );
      final ledgerFuture = CompanyServerService.getLedgerEntries(
        limit: 20,
      ).catchError((_) => <Map<String, dynamic>>[]);
      final claimsFuture = CompanyServerService.getMyRewardClaims(
        limit: 20,
      ).catchError((_) => <Map<String, dynamic>>[]);
      final tiersFuture = CompanyServerService.getCustomerPointTiers()
          .catchError((_) => <String, dynamic>{});
      final pendingFuture = CompanyServerService.getCustomerPendingPoints()
          .catchError((_) => <String, dynamic>{});
      final catalogFuture = CompanyServerService.getCustomerGiftCatalog()
          .catchError((_) => <String, dynamic>{});
      final results = await Future.wait<dynamic>([
        pointsFuture,
        rewardsFuture,
        ledgerFuture,
        claimsFuture,
        tiersFuture,
        pendingFuture,
        catalogFuture,
      ]);

      if (!mounted) return;
      final availablePoints = _toInt(
        (results[0] as Map<String, dynamic>)['availablePoints'],
      );
      final catalog = (results[6] as Map<String, dynamic>);
      final split = RedemptionMath.splitGiftCatalog(
        availablePoints: availablePoints,
        gifts: List<Map<String, dynamic>>.from(
          (catalog['items'] ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      setState(() {
        _points = (results[0] as Map<String, dynamic>);
        _rewards = (results[1] as List<Map<String, dynamic>>);
        _ledger = (results[2] as List<Map<String, dynamic>>);
        _claims = (results[3] as List<Map<String, dynamic>>);
        _tiers = (results[4] as Map<String, dynamic>);
        _pending = (results[5] as Map<String, dynamic>);
        _giftCatalog = catalog;
        _giftUnlocked = List<Map<String, dynamic>>.from(
          split['unlocked'] as List,
        );
        _giftLocked = List<Map<String, dynamic>>.from(split['locked'] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'rewards_load_error'.tr(namedArgs: {'error': e.toString()}),
          ),
        ),
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
    final rewardId = (claim['rewardId'] ?? '').toString();
    final sourceId = (claim['sourceId'] ?? '').toString();
    final pointsCost = _toInt(claim['pointsCost']);
    if (rewardId.isNotEmpty) {
      for (final reward in _rewards) {
        if ((reward['id'] ?? '').toString() == rewardId) {
          return (reward['reward_name'] ?? '').toString();
        }
      }
    }
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
      final date =
          DateTime.tryParse((entry['createdAt'] ?? '').toString()) ??
          DateTime.now();
      final label = type == 'pointsEarned'
          ? 'tx_receipt_scan_approved'.tr()
          : ((type == 'pointsRedeemed' || type == 'rewardClaimCreated')
                ? 'tx_reward_redeemed_generic'.tr()
                : _formatLedgerType(type));
      items.add(_TxEntry(date: date, label: label, points: points));
    }
    for (final claim in _claims) {
      if (!shouldAddClaimTransaction(claim, _ledger)) continue;
      final pointsCost = _toInt(claim['pointsCost']);
      if (pointsCost <= 0) continue;
      final date =
          DateTime.tryParse((claim['createdAt'] ?? '').toString()) ??
          DateTime.now();
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

  Future<void> _createDynamicVoucher() async {
    final amount = double.tryParse(_dynamicVoucherController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    setState(() => _creatingDynamicVoucher = true);
    try {
      final result = await CompanyServerService.createDynamicVoucher(
        cashValueLyD: amount,
      );
      if (!mounted) return;
      final voucher =
          result['voucher'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final qrCode = (voucher['qrCode'] ?? '').toString();
      final pointsUsed = _toInt(voucher['pointsUsed']);
      final cashValue = (voucher['cashValueLyD'] is num)
          ? (voucher['cashValueLyD'] as num).toDouble()
          : amount;
      _dynamicVoucherController.clear();
      await _loadData();
      _showDynamicVoucherDialog(
        qrCode: qrCode,
        pointsUsed: pointsUsed,
        cashValueLyD: cashValue,
        tier: (voucher['tier'] ?? 'bronze').toString(),
        message: (voucher['message'] ?? 'جاهز للاستخدام لدى الكاشير')
            .toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل إنشاء القسيمة: $e')));
    } finally {
      if (mounted) setState(() => _creatingDynamicVoucher = false);
    }
  }

  void _showDynamicVoucherDialog({
    required String qrCode,
    required int pointsUsed,
    required double cashValueLyD,
    required String tier,
    required String message,
  }) {
    if (qrCode.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'قسيمة مخصصة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: kTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                QrImageView(data: qrCode, size: 220),
                const SizedBox(height: 10),
                Text(
                  'المبلغ: ${cashValueLyD.toStringAsFixed(2)} د.ل',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('النقاط المستهلكة: $pointsUsed نقطة'),
                Text('الطبقة: ${tier.toUpperCase()}'),
                const SizedBox(height: 12),
                SelectableText(
                  qrCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _redeemReward(Map<String, dynamic> reward) async {
    if (_redeeming) return;
    final requiredPoints = _toInt(reward['value']);
    final currentPoints = _toInt(_points['availablePoints']);
    if (requiredPoints <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('reward_invalid_value'.tr())));
      return;
    }
    if (currentPoints < requiredPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('reward_insufficient_points'.tr())),
      );
      return;
    }

    setState(() => _redeeming = true);
    final rewardId = (reward['id'] ?? '').toString();
    final requestId = _rewardClaimRequestIds.putIfAbsent(rewardId, () => const Uuid().v4());
    try {
      final rewardKind = (reward['kind'] ?? 'digital').toString();
      final claim = await CompanyServerService.createRewardClaim(
        pointsCost: requiredPoints,
        rewardId: rewardId,
        sourceType: (reward['sourceType'] ?? 'system').toString(),
        sourceId: (reward['sourceId'] ?? reward['id'] ?? '').toString(),
        rewardKind: rewardKind,
        idempotencyKey: requestId,
      );
      _rewardClaimRequestIds.remove(rewardId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'reward_redeemed_success'.tr(
              namedArgs: {
                'reward': '${reward['reward_name'] ?? 'reward_generic'.tr()}',
              },
            ),
          ),
        ),
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
        SnackBar(
          content: Text(
            'reward_redeem_error'.tr(namedArgs: {'error': e.toString()}),
          ),
        ),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatClaimStatus(status),
                  style: const TextStyle(color: kTeal),
                ),
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTeal,
                    ),
                  ),
                ],
                if (expiresAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'coupon_expires_at'.tr(
                        namedArgs: {'value': expiresAt.split('T').first},
                      ),
                    ),
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
    final lowerName = rewardName.toLowerCase();
    final fallbackIcon =
        lowerName.contains('coffee') || rewardName.contains('قهوة')
        ? Icons.local_cafe_outlined
        : (lowerName.contains('meal') || rewardName.contains('وجبة')
              ? Icons.restaurant_outlined
              : (lowerName.contains('car') ||
                        lowerName.contains('vehicle') ||
                        rewardName.contains('سيارة') ||
                        rewardName.contains('سياره') ||
                        rewardName.contains('مركبة')
                    ? Icons.directions_car_outlined
                    : Icons.card_giftcard_outlined));

    return Container(
      width: 208,
      height: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? kSand : kWhite,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(
          color: locked ? kLine : kTeal.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 88,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kLine,
                  borderRadius: BorderRadius.circular(kRadiusOfferImage),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
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
                    child: const Center(
                      child: Icon(Icons.lock_rounded, color: kWhite, size: 26),
                    ),
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
                style: kBodyTextStyle(
                  size: 11,
                  color: kTeal,
                  weight: FontWeight.w600,
                ),
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
                    style: kBodyTextStyle(
                      size: 11,
                      weight: FontWeight.w700,
                      color: kGold,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'redeem_points_value'.tr(namedArgs: {'value': '$cost'}),
              style: kBodyTextStyle(
                size: 11,
                color: kTeal,
                weight: FontWeight.w700,
              ),
            ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'reward_locked_points_needed'.tr(
                  namedArgs: {'value': '$remaining'},
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kBodyTextStyle(
                  size: 10.5,
                  color: kInk.withValues(alpha: 0.6),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: cost <= 0
                        ? 0
                        : (availablePoints / cost).clamp(0.0, 1.0),
                    minHeight: 5,
                    color: locked ? kGold : kTeal,
                    backgroundColor: kLine,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locked
                      ? 'reward_progress'.tr(
                          namedArgs: {
                            'available': '$availablePoints',
                            'cost': '$cost',
                          },
                        )
                      : 'reward_reached'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kBodyTextStyle(
                    size: 10,
                    color: locked ? kInk.withValues(alpha: 0.65) : kTeal,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if ((reward['expiresAt'] ?? '').toString().isNotEmpty)
            Text(
              'reward_expires'.tr(
                namedArgs: {
                  'date': (reward['expiresAt'] ?? '')
                      .toString()
                      .split('T')
                      .first,
                },
              ),
              style: kBodyTextStyle(
                size: 10,
                color: kInk.withValues(alpha: 0.6),
              ),
            ),
          if (reward['drawEnabled'] == true)
            Text(
              'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاطك المكتسبة من مشترياتك العادية.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: kBodyTextStyle(
                size: 10,
                color: kInk.withValues(alpha: 0.72),
                weight: FontWeight.w700,
              ),
            ),
          if (!locked &&
              (reward['pickupInstructions'] ?? '').toString().isNotEmpty)
            Text(
              'reward_pickup'.tr(
                namedArgs: {
                  'instructions': (reward['pickupInstructions'] ?? '')
                      .toString(),
                },
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kBodyTextStyle(
                size: 10,
                color: kTeal,
                weight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: locked
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock, size: 14),
                    label: Text(
                      'reward_locked_label'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
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

  String _rewardKindKey(dynamic raw, {String? rewardName}) {
    final value = (raw ?? '').toString().toLowerCase();
    final name = (rewardName ?? '').toString().toLowerCase();
    if (value.isEmpty) {
      if (name.contains('car') ||
          name.contains('vehicle') ||
          name.contains('سيارة') ||
          name.contains('سياره') ||
          name.contains('مركبة')) {
        return 'physical';
      }
      return 'physical';
    }
    if (value.contains('digital') ||
        value.contains('voucher') ||
        value.contains('coupon') ||
        value.contains('code')) {
      return 'digital';
    }
    if (value.contains('physical') ||
        value.contains('pickup') ||
        value.contains('product') ||
        value.contains('vehicle') ||
        value.contains('car') ||
        value.contains('gift') ||
        name.contains('car') ||
        name.contains('vehicle') ||
        name.contains('سيارة') ||
        name.contains('سياره') ||
        name.contains('مركبة')) {
      return 'physical';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildRewardsBody();

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('home_bottom_wallet'.tr()),
      ),
      body: body,
    );
  }

  Widget _buildRewardsBody() {
    final availablePoints = _toInt(_points['availablePoints']);
    final visibleRewards = _rewards.where((reward) {
      if (_rewardTab == 0) return true;
      final rewardKind = _rewardKindKey(
        reward['kind'],
        rewardName: (reward['reward_name'] ?? '').toString(),
      );
      return rewardKind == (_rewardTab == 1 ? 'digital' : 'physical');
    }).toList();
    final nextMilestone = _nextMilestoneValue(availablePoints);
    final progress = nextMilestone == null
        ? 1.0
        : (nextMilestone == 0 ? 0.0 : availablePoints / nextMilestone);
    final txItems = _buildTransactions();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildBalanceHeader(availablePoints, nextMilestone, progress),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: <ButtonSegment<int>>[
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.card_giftcard_outlined),
                label: Text('rewards_section_rewards'.tr()),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text('rewards_section_coupons'.tr()),
              ),
              ButtonSegment(
                value: 2,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text('rewards_section_history'.tr()),
              ),
            ],
            selected: <int>{_sectionTab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _sectionTab = selection.first),
          ),
          const SizedBox(height: 18),
          if (_sectionTab == 0) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'available_rewards'.tr(),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openDynamicVoucherSheet,
                  icon: const Icon(Icons.currency_exchange, size: 18),
                  label: Text('rewards_cash_voucher'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KupunaTopTabs(
              tabs: <String>[
                'rewards_filter_all'.tr(),
                'rewards_filter_digital'.tr(),
                'rewards_filter_physical'.tr(),
              ],
              activeIndex: _rewardTab,
              onSelect: (index) => setState(() => _rewardTab = index),
            ),
            const SizedBox(height: 12),
            if (visibleRewards.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('no_rewards_available_now'.tr()),
                ),
              )
            else
              SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visibleRewards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) =>
                      _buildRewardCard(visibleRewards[index], availablePoints),
                ),
              ),
            const SizedBox(height: 14),
            _buildGiftCatalogSection(),
            _buildPendingPointsCard(),
            const SizedBox(height: 8),
            _buildTierDetails(),
          ] else if (_sectionTab == 1) ...[
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
                    leading: Icon(
                      Icons.confirmation_number_outlined,
                      color: _claimStatusColor(status),
                    ),
                    title: Text(_claimRewardLabel(claim)),
                    subtitle: Text(_formatClaimStatus(status)),
                    trailing:
                        (status == 'pending_pickup' || status == 'used') &&
                            ((claim['pickupQrCode'] ?? '')
                                    .toString()
                                    .isNotEmpty ||
                                (claim['digitalCode'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                        ? const Icon(Icons.qr_code_2, color: kTeal)
                        : null,
                    onTap:
                        (status == 'pending_pickup' || status == 'used') &&
                            ((claim['pickupQrCode'] ?? '')
                                    .toString()
                                    .isNotEmpty ||
                                (claim['digitalCode'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                        ? () => _showCouponDialog(
                            rewardName: _claimRewardLabel(claim),
                            rewardKind: (claim['rewardKind'] ?? 'digital')
                                .toString(),
                            pickupQrCode: (claim['pickupQrCode'] ?? '')
                                .toString(),
                            digitalCode: (claim['digitalCode'] ?? '')
                                .toString(),
                            status: status,
                            expiresAt: (claim['expiresAt'] ?? '').toString(),
                          )
                        : null,
                  ),
                );
              }),
          ] else ...[
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
                      isEarn
                          ? Icons.receipt_long_outlined
                          : Icons.card_giftcard_outlined,
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
        ],
      ),
    );
  }

  Widget _buildBalanceHeader(
    int availablePoints,
    int? nextMilestone,
    double progress,
  ) {
    final remaining = nextMilestone == null
        ? 0
        : (nextMilestone - availablePoints).clamp(0, nextMilestone);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTealDark,
        borderRadius: BorderRadius.circular(kRadiusCardLarge),
        boxShadow: kShadowFloating,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: _PointsRingPainter(progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$availablePoints',
                          style: kPointsNumberStyle(size: 28, color: kWhite),
                        ),
                        Text(
                          'wallet_points_caption'.tr(),
                          style: kBodyTextStyle(
                            size: 12,
                            color: kWhite.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'rewards_balance_title'.tr(),
                      style: kDisplayTextStyle(size: 18, color: kWhite),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextMilestone == null
                          ? 'wallet_all_rewards_unlocked'.tr()
                          : 'wallet_points_to_next_reward'.tr(
                              namedArgs: {'value': '$remaining'},
                            ),
                      style: kBodyTextStyle(
                        size: 13,
                        weight: FontWeight.w600,
                        color: kGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 7,
                        color: kGold,
                        backgroundColor: kWhite.withValues(alpha: 0.18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildTierCounters(),
        ],
      ),
    );
  }

  void _openDynamicVoucherSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(child: _buildDynamicVoucherCard()),
        ),
      ),
    );
  }

  Widget _buildTierDetails() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline, color: kTeal),
        title: Text(
          'wallet_tier_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Text('wallet_bronze_scope'.tr()),
          const SizedBox(height: 6),
          Text('wallet_silver_scope'.tr()),
          const SizedBox(height: 6),
          Text('wallet_gold_scope'.tr()),
        ],
      ),
    );
  }

  Widget _buildTierCounters() {
    final tiers =
        (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final definitions = <Map<String, dynamic>>[
      {
        'key': 'bronze',
        'label': 'wallet_bronze_points',
        'shortLabel': 'rewards_tier_bronze_short',
        'scope': 'wallet_bronze_scope',
        'icon': Icons.workspace_premium_outlined,
        'color': Colors.brown,
      },
      {
        'key': 'silver',
        'label': 'wallet_silver_points',
        'shortLabel': 'rewards_tier_silver_short',
        'scope': 'wallet_silver_scope',
        'icon': Icons.workspace_premium_outlined,
        'color': Colors.blueGrey,
      },
      {
        'key': 'gold',
        'label': 'wallet_gold_points',
        'shortLabel': 'rewards_tier_gold_short',
        'scope': 'wallet_gold_scope',
        'icon': Icons.workspace_premium_outlined,
        'color': Colors.amber.shade800,
      },
    ];
    return Row(
      children: definitions.map((definition) {
        final tier =
            (tiers[definition['key']] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final balance = _toInt(tier['balance']);
        final color = definition['color'] as Color;
        return Expanded(
          child: Semantics(
            label: '${definition['label']}'.tr(),
            value: '$balance',
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              decoration: BoxDecoration(
                color: kWhite.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.85)),
              ),
              child: Column(
                children: [
                  Icon(definition['icon'] as IconData, color: color, size: 18),
                  const SizedBox(height: 3),
                  Text(
                    '$balance',
                    style: kPointsNumberStyle(size: 17, color: color),
                  ),
                  Text(
                    '${definition['shortLabel']}'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kBodyTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: kWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingPointsCard() {
    final pending = List<dynamic>.from(_pending['pending'] ?? const []);
    if (pending.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'wallet_pending_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'wallet_pending_description'.tr(
                namedArgs: {'points': '${_pending['total_points'] ?? 0}'},
              ),
            ),
            const SizedBox(height: 8),
            ...pending.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_top, color: Colors.orange),
                title: Text('${item['merchant_name'] ?? 'merchant'}'),
                subtitle: Text(
                  'wallet_pending_item'.tr(
                    namedArgs: {
                      'points': '${item['points_remaining'] ?? 0}',
                      'tier': '${item['tier'] ?? ''}',
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicVoucherCard() {
    final availablePoints = _toInt(_points['availablePoints']);
    final amountText = _dynamicVoucherController.text.trim();
    final previewAmount = double.tryParse(amountText) ?? 0;
    final requiredPoints = RedemptionMath.pointsRequiredForCash(previewAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حاسبة الاستبدال المالي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dynamicVoucherController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'مثال: 25',
                      labelText: 'المبلغ بالـ LYD',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: FilledButton(
                    onPressed: _creatingDynamicVoucher
                        ? null
                        : _createDynamicVoucher,
                    child: _creatingDynamicVoucher
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('استبدال'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                previewAmount > 0
                    ? 'النقاط المطلوبة: $requiredPoints نقطة • الرصيد المتاح: $availablePoints نقطة'
                    : 'أدخل المبلغ المطلوب لتحويله إلى نقاط استبدال.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftCatalogSection() {
    if (_giftCatalog.isEmpty && _giftUnlocked.isEmpty && _giftLocked.isEmpty) {
      return const SizedBox.shrink();
    }

    final unlockedItems = _giftUnlocked
        .where((gift) => gift['origin'] == 'coalition')
        .toList();
    final lockedItems = _giftLocked
        .where((gift) => gift['origin'] == 'coalition')
        .toList();
    if (unlockedItems.isEmpty && lockedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'rewards_coalition_gifts'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (unlockedItems.isNotEmpty) ...[
              const Text(
                'متاح الآن',
                style: TextStyle(fontWeight: FontWeight.w700, color: kTeal),
              ),
              const SizedBox(height: 8),
              ...unlockedItems.map(
                (gift) => _buildGiftRow(gift, unlocked: true),
              ),
              const SizedBox(height: 10),
            ],
            if (lockedItems.isNotEmpty) ...[
              const Text(
                'هدايا مستهدفة',
                style: TextStyle(fontWeight: FontWeight.w700, color: kGold),
              ),
              const SizedBox(height: 8),
              ...lockedItems.map(
                (gift) => _buildGiftRow(gift, unlocked: false),
              ),
            ],
            if (unlockedItems.isEmpty && lockedItems.isEmpty)
              const Text('لا توجد هدايا حالياً.'),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftRow(Map<String, dynamic> gift, {required bool unlocked}) {
    final title = (gift['title'] ?? 'هدية').toString();
    final pointsCost = _toInt(gift['pointsCost']);
    final remaining = _toInt(gift['remainingPoints']);
    final progress = (gift['progress'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = (gift['imageUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked
            ? kTeal.withValues(alpha: 0.04)
            : kGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? kTeal.withValues(alpha: 0.25)
              : kGold.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kLine,
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl.isEmpty
                ? const Icon(Icons.card_giftcard_outlined, color: kTeal)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'التكلفة: $pointsCost نقطة',
                  style: const TextStyle(fontSize: 12),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    color: kGold,
                    backgroundColor: kLine,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'متبقي لك $remaining نقطة للحصول عليها',
                    style: const TextStyle(color: kGold, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: unlocked
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerCoalitionsScreen(),
                    ),
                  )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: unlocked ? kTeal : Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: Text(unlocked ? 'احصل عليها' : 'مغلق'),
          ),
        ],
      ),
    );
  }
}
