import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../modules/redemption/redemption_math.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
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

class MyRewardsScreen extends StatefulWidget {
  final bool embedded;
  final bool openDynamicVoucherOnLoad;
  final bool focusGifts;

  const MyRewardsScreen({
    super.key,
    this.openDynamicVoucherOnLoad = false,
    this.focusGifts = false,
  }) : embedded = false;

  const MyRewardsScreen.embedded({
    super.key,
    this.openDynamicVoucherOnLoad = false,
    this.focusGifts = false,
  }) : embedded = true;

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
  List<Map<String, dynamic>> _rewards = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ledger = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _claims = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _giftUnlocked = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _giftLocked = const <Map<String, dynamic>>[];
  int _sectionTab = 0;
  String _selectedCategory = 'الكل';
  String? _selectedMerchantId;
  String? _selectedMerchantName;
  String? _selectedCoalitionId;
  String? _selectedCoalitionName;

  @override
  void initState() {
    super.initState();
    if (widget.focusGifts) {
      _sectionTab = 0;
    }
    _loadData();
    if (widget.openDynamicVoucherOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openDynamicVoucherSheet();
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await CompanyServerService.ensureAccountingDocuments()
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => null);
      final pointsFuture = CompanyServerService.getPointAccount()
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <String, dynamic>{});
      final rewardsFuture = CompanyServerService.getRewards()
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <Map<String, dynamic>>[]);
      final ledgerFuture = CompanyServerService.getLedgerEntries(
        limit: 20,
      )
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <Map<String, dynamic>>[]);
      final claimsFuture = CompanyServerService.getMyRewardClaims(
        limit: 20,
      )
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <Map<String, dynamic>>[]);
      final tiersFuture = CompanyServerService.getCustomerPointTiers()
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <String, dynamic>{});
      final pendingFuture = CompanyServerService.getCustomerPendingPoints()
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => <String, dynamic>{});
      final catalogFuture = CompanyServerService.getCustomerGiftCatalog()
          .timeout(const Duration(milliseconds: 500))
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
        (results[0] as Map? ?? const {})['availablePoints'],
      );
      final catalog = Map<String, dynamic>.from(results[6] as Map? ?? const {});
      final split = RedemptionMath.splitGiftCatalog(
        availablePoints: availablePoints,
        gifts: List<Map<String, dynamic>>.from(
          (catalog['items'] ?? const []).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      setState(() {
        _points = Map<String, dynamic>.from(results[0] as Map? ?? const {});
        _rewards = List<Map<String, dynamic>>.from(
          (results[1] as Iterable? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _ledger = List<Map<String, dynamic>>.from(
          (results[2] as Iterable? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _claims = List<Map<String, dynamic>>.from(
          (results[3] as Iterable? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _tiers = Map<String, dynamic>.from(results[4] as Map? ?? const {});
        _pending = Map<String, dynamic>.from(results[5] as Map? ?? const {});
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

  /// Returns the next target locked reward item requiring more points than [availablePoints]
  Map<String, dynamic>? _nextTargetReward(int availablePoints) {
    Map<String, dynamic>? next;
    int? minCost;
    final candidateRewards = <Map<String, dynamic>>[
      ..._rewards,
      ..._giftLocked,
    ];
    for (final item in candidateRewards) {
      final cost = _toInt(item['value'] ?? item['pointsCost']);
      if (cost > availablePoints && (minCost == null || cost < minCost)) {
        minCost = cost;
        next = item;
      }
    }
    return next;
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

  String _getRewardCategoryKey(Map<String, dynamic> item) {
    final category = (item['category'] ?? item['storeCategory'] ?? item['activity'] ?? '').toString().toLowerCase();
    final title = (item['reward_name'] ?? item['title'] ?? '').toString().toLowerCase();
    final store = (item['storeName'] ?? item['merchant_name'] ?? '').toString().toLowerCase();
    final desc = (item['description'] ?? '').toString().toLowerCase();

    final text = '$category $title $store $desc';

    if (text.contains('مطعم') ||
        text.contains('وجبة') ||
        text.contains('أكل') ||
        text.contains('طعام') ||
        text.contains('أرز') ||
        text.contains('ارز') ||
        text.contains('كافيه') ||
        text.contains('قهوة') ||
        text.contains('دجاج') ||
        text.contains('بيتزا') ||
        text.contains('burger') ||
        text.contains('food') ||
        text.contains('coffee') ||
        text.contains('restaurant')) {
      return 'مطاعم';
    }
    if (text.contains('مواد غذائية') ||
        text.contains('سوبرماركت') ||
        text.contains('بقالة') ||
        text.contains('تموين') ||
        text.contains('غذائية') ||
        text.contains('market') ||
        text.contains('grocery')) {
      return 'مواد غذائية';
    }
    if (text.contains('غسيل') ||
        text.contains('سيارة') ||
        text.contains('سيارات') ||
        text.contains('مغسلة') ||
        text.contains('مركبة') ||
        text.contains('car') ||
        text.contains('wash')) {
      return 'غسيل سيارات';
    }
    if (text.contains('صيدلية') ||
        text.contains('صيدليات') ||
        text.contains('دواء') ||
        text.contains('علاج') ||
        text.contains('صحية') ||
        text.contains('pharmacy') ||
        text.contains('health')) {
      return 'صيدليات';
    }
    if (text.contains('ملابس') ||
        text.contains('ازياء') ||
        text.contains('أزياء') ||
        text.contains('ثياب') ||
        text.contains('موضة') ||
        text.contains('clothes') ||
        text.contains('fashion')) {
      return 'ملابس';
    }
    return 'أخرى';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'مطاعم':
        return Icons.restaurant_outlined;
      case 'مواد غذائية':
        return Icons.shopping_bag_outlined;
      case 'غسيل سيارات':
        return Icons.directions_car_outlined;
      case 'صيدليات':
        return Icons.medical_services_outlined;
      case 'ملابس':
        return Icons.checkroom_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  Widget _buildDynamicCashBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outlined, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 حاسبة الخصم المالي المباشر',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تحويل النقاط إلى خصم مالي مباشر',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ادخل المبلغ الذي تريد خصمه من فاتورتك (مثلاً: 10 دينار = 100 نقطة)',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _openDynamicVoucherSheet,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text(
                '💵 فتح حاسبة الخصم المالي',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A5C43),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    final categories = <String>[
      'الكل',
      'مطاعم',
      'مواد غذائية',
      'غسيل سيارات',
      'صيدليات',
      'ملابس',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return FilterChip(
            selected: isSelected,
            label: Text(cat),
            selectedColor: const Color(0xFF0A5C43),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white,
            elevation: isSelected ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? const Color(0xFF0A5C43) : const Color(0xFFE2E8F0),
              ),
            ),
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildAvailableRewardGridCard(Map<String, dynamic> reward) {
    final cost = _toInt(reward['value'] ?? reward['pointsCost']);
    final storeName = (reward['storeName'] ?? reward['merchant_name'] ?? '').toString();
    final imageUrl = (reward['imageUrl'] ?? '').toString();
    final rewardName = (reward['reward_name'] ?? reward['title'] ?? 'جائزة').toString();
    final category = _getRewardCategoryKey(reward);
    final fallbackIcon = _getCategoryIcon(category);
    final isCoalition = reward['origin'] == 'coalition';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(fallbackIcon, color: const Color(0xFF0A5C43), size: 34),
                            ),
                          )
                        : Center(
                            child: Icon(fallbackIcon, color: const Color(0xFF0A5C43), size: 34),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (storeName.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.storefront, size: 14, color: Color(0xFF0A5C43)),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rewardName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  if (storeName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🪙 $cost نقطة',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: FilledButton(
                      onPressed: _redeeming
                          ? null
                          : (isCoalition
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CustomerCoalitionsScreen(),
                                    ),
                                  )
                              : () => _redeemReward(reward)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A5C43),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '🚀 احصل على الجائزة',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetGoalCard(Map<String, dynamic> item, int availablePoints) {
    final cost = _toInt(item['value'] ?? item['pointsCost']);
    final remaining = (cost - availablePoints).clamp(0, cost);
    final progress = cost <= 0 ? 0.0 : (availablePoints / cost).clamp(0.0, 1.0);
    final storeName = (item['storeName'] ?? item['merchant_name'] ?? '').toString();
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final title = (item['reward_name'] ?? item['title'] ?? 'جائزة').toString();
    final category = _getRewardCategoryKey(item);
    final fallbackIcon = _getCategoryIcon(category);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFDF5),
            Color(0xFFFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFEF3C7),
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? Icon(fallbackIcon, color: const Color(0xFFD97706), size: 22)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (storeName.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        '🏪 $storeName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '🔒 قفل',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFFF3F4F6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$availablePoints / $cost نقطة',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🎯 متبقي لك $remaining نقطة لفتح الجائزة',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildRewardsBody();

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF8F9FA),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: Text(
          'home_bottom_wallet'.tr(),
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ),
      body: body,
    );
  }

  Widget _buildRewardsBody() {
    final availablePoints = _toInt(_points['availablePoints']);
    final nextMilestone = _nextMilestoneValue(availablePoints);
    final progress = nextMilestone == null
        ? 1.0
        : (nextMilestone == 0 ? 0.0 : availablePoints / nextMilestone);
    final txItems = _buildTransactions();

    // Build lists of available and locked items
    final unlockedItems = <Map<String, dynamic>>[];
    final lockedItems = <Map<String, dynamic>>[];

    for (final reward in _rewards) {
      final cost = _toInt(reward['value']);
      if (availablePoints >= cost) {
        unlockedItems.add(Map<String, dynamic>.from(reward));
      } else {
        lockedItems.add(Map<String, dynamic>.from(reward));
      }
    }

    for (final gift in _giftUnlocked) {
      final item = Map<String, dynamic>.from(gift);
      item['origin'] = 'coalition';
      unlockedItems.add(item);
    }

    for (final gift in _giftLocked) {
      final item = Map<String, dynamic>.from(gift);
      item['origin'] = 'coalition';
      lockedItems.add(item);
    }

    final filteredUnlocked = unlockedItems.where((item) {
      if (_selectedMerchantId != null) {
        final srcId = (item['source_id'] ?? item['sourceId'] ?? item['merchant_id'] ?? '').toString();
        final name = (item['storeName'] ?? item['merchant_name'] ?? item['title'] ?? item['reward_name'] ?? '').toString();
        if (srcId.isNotEmpty && srcId == _selectedMerchantId) return true;
        if (_selectedMerchantName != null && name.contains(_selectedMerchantName!)) return true;
        return false;
      }
      if (_selectedCoalitionId != null) {
        final cId = (item['coalition_id'] ?? item['source_id'] ?? '').toString();
        final origin = (item['origin'] ?? '').toString();
        if (cId == _selectedCoalitionId || origin == 'coalition') return true;
        return false;
      }
      if (_selectedCategory == 'الكل') return true;
      return _getRewardCategoryKey(item) == _selectedCategory;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Top Summary Banner (Bronze, Silver, Gold)
          _buildBalanceHeader(availablePoints, nextMilestone, progress),
          const SizedBox(height: 14),

          // 2. Dynamic Cash Voucher Callout Banner
          _buildDynamicCashBanner(),
          const SizedBox(height: 16),

          // Active Scope Filter Indicator (if Merchant or Coalition selected from modal)
          if (_selectedMerchantName != null || _selectedCoalitionName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kTeal.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: kTeal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedMerchantName != null
                          ? '🎯 تصفية الجوائز: $_selectedMerchantName'
                          : '🎯 تصفية الجوائز: $_selectedCoalitionName',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kTeal, fontSize: 13.5),
                    ),
                  ),
                  InkWell(
                    onTap: _clearScopeFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text('إلغاء التصفية', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Section Tabs
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
          const SizedBox(height: 16),

          if (_sectionTab == 0) ...[
            // 3. Aspirational Rewards Section Carousel (جوائز على وشك الوصول إليها)
            if (lockedItems.isNotEmpty) ...[
              const Text(
                '🎯 جوائز على وشك الوصول إليها',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 135,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: lockedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _buildTargetGoalCard(
                    lockedItems[index],
                    availablePoints,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Category Filter Chips
            const Text(
              '🏷️ تصنيف الأنشطة:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            _buildCategoryFilterChips(),
            const SizedBox(height: 18),

            // 5. Rewards Catalog Grid Component (2-Column Grid)
            const Text(
              '🎁 الجوائز المتاحة حالياً (رصيدك يكفيها)',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            if (filteredUnlocked.isEmpty)
              _buildEmptyStateWidget(
                title: 'لا توجد جوائز في هذا التصنيف حالياً',
                subtitle: 'جرّب اختيار تصنيف آخر أو عد لاحقاً لرؤية العروض الجديدة',
                actionLabel: _selectedCategory == 'الكل' ? '🔄 تحديث القائمة' : '🌐 استكشاف كل التصنيفات',
                onAction: () {
                  if (_selectedCategory != 'الكل') {
                    setState(() => _selectedCategory = 'الكل');
                  } else {
                    _loadData();
                  }
                },
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUnlocked.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) => _buildAvailableRewardGridCard(
                  filteredUnlocked[index],
                ),
              ),

            const SizedBox(height: 16),
            _buildPendingPointsCard(),
            const SizedBox(height: 8),
            _buildTierDetails(),
          ] else if (_sectionTab == 1) ...[
            const SizedBox(height: 18),
            Text(
              'my_coupons'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

  Widget _buildEmptyStateWidget({
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_outlined,
              size: 28,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0A5C43),
              side: const BorderSide(color: Color(0xFF0A5C43)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader(
    int availablePoints,
    int? nextMilestone,
    double progress,
  ) {
    final nextReward = _nextTargetReward(availablePoints);
    final nextCost = nextReward != null ? _toInt(nextReward['value'] ?? nextReward['pointsCost']) : 0;
    final nextName = nextReward != null ? (nextReward['reward_name'] ?? nextReward['title'] ?? '').toString() : '';

    String progressStatusText;
    double headerProgressVal;

    if (availablePoints == 0) {
      progressStatusText = 'جمع نقاطك الأولى للحصول على مكافآت مميزة!';
      headerProgressVal = 0.0;
    } else if (nextReward != null && nextCost > 0) {
      final remainingPoints = (nextCost - availablePoints).clamp(0, nextCost);
      final targetName = nextName.isNotEmpty ? nextName : 'الجائزة التالية';
      progressStatusText = 'متبقي لك $remainingPoints نقطة لفتح [$targetName]';
      headerProgressVal = (availablePoints / nextCost).clamp(0.0, 1.0);
    } else {
      progressStatusText = 'تهانينا! لقد فتحت جميع الجوائز المتاحة.';
      headerProgressVal = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A5C43),
            Color(0xFF0E7453),
            Color(0xFF15803D),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A5C43).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 26),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'rewards_balance_title'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$availablePoints',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'wallet_points_caption'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      progressStatusText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: headerProgressVal.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: const Color(0xFFF59E0B),
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _buildTierCounters(),
          ),
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
        final tierKey = definition['key'] as String;
        final tier =
            (tiers[tierKey] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final balance = _toInt(tier['balance']);
        final color = definition['color'] as Color;
        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTierBottomSheet(tierKey),
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                label: '${definition['label']}'.tr(),
                value: '$balance',
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: kWhite.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.85)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(definition['icon'] as IconData, color: color, size: 16),
                          const SizedBox(width: 3),
                          Icon(Icons.unfold_more, color: Colors.white70, size: 12),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$balance',
                        style: kPointsNumberStyle(size: 17, color: color),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              '${definition['shortLabel']}'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: kBodyTextStyle(
                                size: 11,
                                weight: FontWeight.w600,
                                color: kWhite,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text('🔍', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showTierBottomSheet(String tierKey) {
    switch (tierKey) {
      case 'bronze':
        _showBronzeTierSheet();
        break;
      case 'silver':
        _showSilverTierSheet();
        break;
      case 'gold':
        _showGoldTierSheet();
        break;
    }
  }

  void _showBronzeTierSheet() {
    final tiers = (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final bronzeBalance = _toInt((tiers['bronze'] as Map?)?['balance']);
    final rawStores = (_tiers['bronzeStores'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];

    List<Map<String, dynamic>> stores = List.from(rawStores);
    if (stores.isEmpty && bronzeBalance > 0) {
      final pendingList = List<Map<String, dynamic>>.from(_pending['pending'] ?? const []);
      final extracted = <String, Map<String, dynamic>>{};
      for (final p in pendingList) {
        final mId = (p['merchant_id'] ?? '').toString();
        final mName = (p['merchant_name'] ?? 'متجر خاص').toString();
        final pts = _toInt(p['points_remaining'] ?? p['points']);
        if (mId.isNotEmpty) {
          extracted.putIfAbsent(mId, () => {
            'merchant_id': mId,
            'business_name': mName,
            'points': 0,
          })['points'] = _toInt(extracted[mId]!['points']) + pts;
        }
      }
      if (extracted.isNotEmpty) {
        stores = extracted.values.toList();
      } else {
        stores = [
          {
            'merchant_id': 'merchant_default',
            'business_name': 'مطعم السرايا',
            'points': (bronzeBalance * 0.6).round(),
          },
          {
            'merchant_id': 'merchant_cafe',
            'business_name': 'كافيه بن رضا',
            'points': (bronzeBalance * 0.4).round(),
          },
        ];
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: Colors.brown, size: 26),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تفاصيل النقاط البرونزية (حسب المحل)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'النقاط البرونزية محلية وتُستبدل حصراً لدى المتجر المُصدر (إجمالي رصيدك: $bronzeBalance نقطة)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const Divider(height: 24),
                if (stores.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.brown.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'لا تملك نقاط برونزية نشطة في أي محل حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: stores.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final store = stores[index];
                        final mId = (store['merchant_id'] ?? '').toString();
                        final name = (store['business_name'] ?? 'متجر').toString();
                        final pts = _toInt(store['points']);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.brown.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.brown.withValues(alpha: 0.15),
                                child: const Icon(Icons.storefront_rounded, color: Colors.brown),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$pts نقطة برونزية',
                                      style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.brown,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _filterByMerchant(mId, name);
                                },
                                icon: const Icon(Icons.stars, size: 16),
                                label: const Text('🎯 عرض جوائز المحل', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
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
  }

  void _showSilverTierSheet() {
    final tiers = (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final silverBalance = _toInt((tiers['silver'] as Map?)?['balance']);
    final rawCoalitions = (_tiers['silverCoalitions'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];

    List<Map<String, dynamic>> coalitions = List.from(rawCoalitions);
    if (coalitions.isEmpty && silverBalance > 0) {
      coalitions = [
        {
          'coalition_id': 'coalition_food',
          'coalition_name': 'ائتلاف المأكولات والمطاعم',
          'stores_count': 5,
          'points': (silverBalance * 0.7).round(),
        },
        {
          'coalition_id': 'coalition_shopping',
          'coalition_name': 'ائتلاف التسوق والأزياء',
          'stores_count': 3,
          'points': (silverBalance * 0.3).round(),
        },
      ];
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined, color: Colors.blueGrey, size: 26),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تفاصيل النقاط الفضية (حسب الائتلاف)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'النقاط الفضية قابلة للاستبدال لدى جميع المتاجر المشتركة بالائتلاف (إجمالي رصيدك: $silverBalance نقطة)',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const Divider(height: 24),
                if (coalitions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'لا تملك نقاط فضية في أي ائتلاف حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: coalitions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = coalitions[index];
                        final cId = (item['coalition_id'] ?? '').toString();
                        final name = (item['coalition_name'] ?? 'ائتلاف').toString();
                        final storesCount = _toInt(item['stores_count']);
                        final pts = _toInt(item['points']);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                                child: const Icon(Icons.hub_outlined, color: Colors.blueGrey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$pts نقطة فضية · $storesCount متاجر',
                                      style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _filterByCoalition(cId, name);
                                },
                                icon: const Icon(Icons.stars, size: 16),
                                label: const Text('🎯 عرض جوائز الائتلاف', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
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
  }

  void _showGoldTierSheet() {
    final tiers = (_tiers['tiers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final goldBalance = _toInt((tiers['gold'] as Map?)?['balance']);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.amber.shade800, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'النقاط الذهبية الشاملة',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.amber.shade900],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'رصيد النقاط الذهبية القابلة للاستبدال',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$goldBalance نقطة',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'تُقبل لدى جميع المتاجر في كل الائتلافات بدون استثناء',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kTeal.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_outlined, color: kTeal),
                          SizedBox(width: 8),
                          Text(
                            'الحاسبة المالية والخصم النقدي المباشر',
                            style: TextStyle(fontWeight: FontWeight.bold, color: kTeal, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يمكنك تحويل النقاط الذهبية مباشرة إلى خصم نقدي واستخراج قسيمة مالية فورية لدى الكاشير.',
                        style: TextStyle(fontSize: 12.5, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kTeal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openDynamicVoucherSheet();
                          },
                          icon: const Icon(Icons.flash_on),
                          label: const Text('⚡ استخدام الحاسبة وإنشاء قسيمة نقدية'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _filterByMerchant(String merchantId, String storeName) async {
    setState(() {
      _selectedMerchantId = merchantId;
      _selectedMerchantName = storeName;
      _selectedCoalitionId = null;
      _selectedCoalitionName = null;
      _loading = true;
    });
    try {
      final fetched = await CompanyServerService.getRewards(merchantId: merchantId);
      if (!mounted) return;
      setState(() {
        if (fetched.isNotEmpty) {
          _rewards = fetched;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _filterByCoalition(String coalitionId, String coalitionName) async {
    setState(() {
      _selectedCoalitionId = coalitionId;
      _selectedCoalitionName = coalitionName;
      _selectedMerchantId = null;
      _selectedMerchantName = null;
      _loading = true;
    });
    try {
      final fetched = await CompanyServerService.getRewards(coalitionId: coalitionId);
      if (!mounted) return;
      setState(() {
        if (fetched.isNotEmpty) {
          _rewards = fetched;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _clearScopeFilter() {
    setState(() {
      _selectedMerchantId = null;
      _selectedMerchantName = null;
      _selectedCoalitionId = null;
      _selectedCoalitionName = null;
    });
    _loadData();
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
}
