import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../services/export_download.dart';
import '../theme/design_tokens.dart';
import '../widgets/analytics_map_panel.dart';
import '../widgets/design_system/kupuna_loyalty_health_ring.dart';
import '../widgets/design_system/kupuna_offer_card.dart';
import '../widgets/design_system/kupuna_status_pill.dart';
import '../widgets/reward_creation_dialog.dart';
import 'map_picker_screen.dart';
import 'add_coupon_screen.dart';
import 'community_screen.dart';
import 'cashier_dashboard_screen.dart';
import 'merchant_campaign_screen.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';
import 'login_screen.dart';
import 'merchant_invoices_screen.dart';
import 'merchant_networks_screen.dart';

// Theme constants for Merchant Dashboard Light Theme Overhaul
const Color kMerchantBg = Color(0xFFF4F6F8);
const Color kMerchantCardBg = Colors.white;
const Color kMerchantPrimary = Color(0xFF0A5C43); // Brand Green
const Color kMerchantPrimaryDark = Color(0xFF063B2B);
const Color kMerchantPrimaryLight = Color(0xFFE6F4F0);
const Color kMerchantTextDark = Color(0xFF1A202C); // Dark Charcoal
const Color kMerchantTextMuted = Color(0xFF718096);
const Color kMerchantBorder = Color(0xFFE2E8F0);
const Color kMerchantGold = Color(0xFFD9A441);
const Color kMerchantBlue = Color(0xFF2B6CB0);

typedef MerchantDashboardLoader =
    Future<List<dynamic>> Function({required String range, String? branchId});
typedef MerchantAnalyticsLoader =
    Future<Map<String, dynamic>> Function({
      required String range,
      String? branchId,
    });
typedef MerchantPendingPointsLoader = Future<Map<String, dynamic>> Function();

bool hasActiveCashierAssociation(Map<String, dynamic> roles) {
  final cashierRows = (roles['cashier'] as List?) ?? const <dynamic>[];
  return cashierRows.any((row) => row is Map && row['isActive'] == true);
}

class MerchantDashboardScreen extends StatefulWidget {
  final bool embedded;
  final int initialTab;
  final MerchantDashboardLoader? dashboardLoader;
  final MerchantAnalyticsLoader? analyticsLoader;
  final MerchantPendingPointsLoader? pendingPointsLoader;
  final Future<Map<String, dynamic>> Function(String branchId)?
  rewardFundingLoader;

  const MerchantDashboardScreen({
    super.key,
    this.embedded = false,
    this.initialTab = 0,
    this.dashboardLoader,
    this.analyticsLoader,
    this.pendingPointsLoader,
    this.rewardFundingLoader,
  });

  const MerchantDashboardScreen.embedded({
    super.key,
    this.initialTab = 0,
    this.dashboardLoader,
    this.analyticsLoader,
    this.pendingPointsLoader,
    this.rewardFundingLoader,
  }) : embedded = true;

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final TextEditingController _branchNameController = TextEditingController();
  final TextEditingController _branchAddressController =
      TextEditingController();
  final TextEditingController _branchLocationController =
      TextEditingController();
  final TextEditingController _managerBranchIdController =
      TextEditingController();
  final TextEditingController _managerUserIdController =
      TextEditingController();
  final TextEditingController _cashierBranchIdController =
      TextEditingController();
  final TextEditingController _cashierUserIdController =
      TextEditingController();
  final TextEditingController _cashbackController = TextEditingController();

  bool _canReviewInvoices = false;
  bool _canCreateOffers = false;
  bool _canManageGroup = false;
  bool _canViewReports = false;
  bool _canViewSettlements = false;
  bool _canAddCashiers = false;
  bool _canReplyReports = false;

  bool _loading = true;
  bool _savingCashback = false;
  String? _error;
  bool _sessionExpired = false;
  String? _result;
  double? _branchLatitude;
  double? _branchLongitude;
  String _analyticsRange = '30d';
  late int _merchantTabIndex;
  int _commandCenterTabIndex = 0;
  String _analyticsBranchId = '';
  double? _currentCashbackPercentage;
  bool _loadingAnalytics = false;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _claims = <Map<String, dynamic>>[];
  String _rewardFilter = 'all';
  Map<String, dynamic> _loyalty = const <String, dynamic>{};
  Map<String, dynamic> _analytics = const <String, dynamic>{};
  Map<String, dynamic> _roles = const <String, dynamic>{};
  Map<String, dynamic> _merchantProfile = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _merchantTabIndex = widget.initialTab;
    _load();
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchLocationController.dispose();
    _managerBranchIdController.dispose();
    _managerUserIdController.dispose();
    _cashierBranchIdController.dispose();
    _cashierUserIdController.dispose();
    _cashbackController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessionExpired = false;
    });
    try {
      final branchId = _analyticsBranchId.isEmpty ? null : _analyticsBranchId;
      final results = widget.dashboardLoader != null
          ? await widget.dashboardLoader!(
              range: _analyticsRange,
              branchId: branchId,
            )
          : await Future.wait<dynamic>(<Future<dynamic>>[
              CompanyServerService.getMerchantBranches(),
              CompanyServerService.getMerchantLoyaltyHealth(),
              CompanyServerService.getMyInvoices(limit: 20),
              CompanyServerService.getMerchantProfile(),
              CompanyServerService.getOffers(),
              CompanyServerService.getMerchantRewards(),
              CompanyServerService.getMyRoles(),
              CompanyServerService.getMerchantAnalytics(
                range: _analyticsRange,
                branchId: branchId,
              ).catchError((_) => <String, dynamic>{}),
            ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(
        results[3] as Map<dynamic, dynamic>,
      );
      final cashbackRaw =
          profile['cashback_percentage'] ?? profile['cashbackPercentage'];
      final cashbackPercentage = cashbackRaw == null
          ? 5.0
          : double.tryParse(cashbackRaw.toString()) ?? 5.0;
      final rawAnalytics = results[7];
      final rawClaims = results.length > 8 ? results[8] : null;

      setState(() {
        _branches = List<Map<String, dynamic>>.from(
          results[0] as List<dynamic>,
        );
        _loyalty = Map<String, dynamic>.from(
          results[1] as Map<dynamic, dynamic>,
        );
        _invoices = List<Map<String, dynamic>>.from(
          results[2] as List<dynamic>,
        );
        _offers = List<Map<String, dynamic>>.from(results[4] as List<dynamic>);
        _merchantRewards = List<Map<String, dynamic>>.from(
          results[5] as List<dynamic>,
        );
        _roles = Map<String, dynamic>.from(results[6] as Map<dynamic, dynamic>);
        _merchantProfile = profile;
        _analytics = rawAnalytics is Map
            ? Map<String, dynamic>.from(rawAnalytics)
            : const <String, dynamic>{};
        _claims = rawClaims is List
            ? List<Map<String, dynamic>>.from(rawClaims)
            : <Map<String, dynamic>>[];
        _currentCashbackPercentage = cashbackPercentage;
        _cashbackController.text = cashbackPercentage.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _sessionExpired =
            e.toString().contains('401') ||
            e.toString().toLowerCase().contains('invalid token');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadAnalytics() async {
    setState(() {
      _loadingAnalytics = true;
    });
    try {
      final branchId = _analyticsBranchId.isEmpty ? null : _analyticsBranchId;
      final data =
          await (widget.analyticsLoader ??
              CompanyServerService.getMerchantAnalytics)(
            range: _analyticsRange,
            branchId: branchId,
          );
      if (!mounted) return;
      setState(() {
        _analytics = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAnalytics = false;
        });
      }
    }
  }

  StatusPillKind _branchStatusToPill(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().toLowerCase();
    if (status == 'active') {
      return StatusPillKind.approvedMint;
    }
    if (status == 'pending' || status == 'under_review') {
      return StatusPillKind.pending;
    }
    return StatusPillKind.rejected;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Map<String, dynamic>? _merchantSubscription() {
    final subscriptions =
        (_roles['subscriptions'] as List?) ?? const <dynamic>[];
    for (final row in subscriptions) {
      if (row is Map && row['roleType'] == 'merchant') {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }

  bool get _merchantReadOnly =>
      (_merchantSubscription()?['status'] ?? '').toString() == 'suspended';

  bool get _merchantGracePeriod =>
      (_merchantSubscription()?['status'] ?? '').toString() == 'grace_period';

  String _localizeSubscriptionStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'trial':
        return _tx('subscription_status_trial', 'Trial');
      case 'active':
        return _tx('subscription_status_active', 'Active');
      case 'grace_period':
        return _tx('subscription_status_grace_period', 'Grace period');
      case 'suspended':
        return _tx('subscription_status_suspended', 'Suspended');
      default:
        return _localizeGenericStatus(raw);
    }
  }

  String _localizeGenericStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().trim().toLowerCase();
    switch (status) {
      case 'pending_admin_review':
        return _tx('status_pending_admin_review', 'Pending admin review');
      case 'pending_review':
        return _tx('status_pending_review', 'Pending review');
      case 'approved':
        return _tx('status_approved', 'Approved');
      case 'active':
        return _tx('status_active', 'Active');
      case 'trial':
        return _tx('status_trial', 'Trial');
      case 'grace_period':
        return _tx('status_grace_period', 'Grace period');
      case 'suspended':
        return _tx('status_suspended', 'Suspended');
      case 'under_review':
        return _tx('status_under_review', 'Under review');
      case 'pending':
        return _tx('status_pending', 'Pending');
      case 'processing':
        return _tx('status_processing', 'Processing');
      case 'rejected':
        return _tx('status_rejected', 'Rejected');
      case 'redeemed':
        return _tx('status_redeemed', 'Redeemed');
      case 'expired':
        return _tx('status_expired', 'Expired');
      case 'archived':
        return _tx('status_archived', 'Archived');
      case '':
        return '-';
      default:
        return _tx('status_unknown', 'Unknown');
    }
  }

  Widget _buildLightCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Key? key,
    Color? color,
    Border? border,
  }) {
    return Container(
      key: key,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: border ?? Border.all(color: kMerchantBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionNotice() {
    final subscription = _merchantSubscription();
    if (subscription == null) return const SizedBox.shrink();
    final status = (subscription['status'] ?? '').toString();
    if (!_merchantReadOnly && !_merchantGracePeriod) {
      return const SizedBox.shrink();
    }

    final nextBillingDate = (subscription['nextBillingDate'] ?? '').toString();
    final label = _localizeSubscriptionStatus(status);
    final title = _merchantReadOnly
        ? _tx('merchant_subscription_suspended_title', 'Subscription suspended')
        : _tx('merchant_subscription_grace_title', 'Grace period is active');
    final body = _merchantReadOnly
        ? _tx(
            'merchant_subscription_suspended_body',
            'Dashboard editing is locked. Existing points and community data remain unchanged until reactivation.',
          )
        : _tx(
            'merchant_subscription_grace_body',
            'Trial ended and the account moved to grace period. Full dashboard access is still available until billing is due.',
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _merchantReadOnly ? Colors.amber.shade50 : kMerchantPrimaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _merchantReadOnly ? kMerchantGold : kMerchantPrimary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: kBodyTextStyle(
              size: 13,
              weight: FontWeight.w700,
              color: kMerchantTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: kBodyTextStyle(
              size: 12,
              weight: FontWeight.w500,
              color: kMerchantTextDark.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_tx('role_subscription_status', 'Subscription status: {status}').replaceAll('{status}', label)}${nextBillingDate.isNotEmpty ? ' • $nextBillingDate' : ''}',
            style: kBodyTextStyle(
              size: 11,
              weight: FontWeight.w500,
              color: kMerchantTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mutableSection(Widget child) {
    if (!_merchantReadOnly) return child;
    return Opacity(opacity: 0.58, child: AbsorbPointer(child: child));
  }

  StatusPillKind _invoiceStatusToPill(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().toLowerCase();
    if (status == 'approved' || status == 'active') {
      return StatusPillKind.approvedMint;
    }
    if (status == 'processing' ||
        status == 'pending_review' ||
        status == 'under_review') {
      return StatusPillKind.pending;
    }
    return StatusPillKind.rejected;
  }

  Future<void> _saveCashbackPercentage() async {
    final value = double.tryParse(_cashbackController.text.trim());
    if (value == null || value <= 0 || value > 100) {
      setState(() {
        _result = 'merchant_point_value_invalid'.tr();
      });
      return;
    }

    setState(() {
      _savingCashback = true;
      _result = null;
    });

    try {
      final data = await CompanyServerService.updateMerchantCashbackPercentage(
        cashbackPercentage: value,
      );
      final updated =
          double.tryParse(
            (data['cashback_percentage'] ?? data['cashbackPercentage'] ?? value)
                .toString(),
          ) ??
          value;
      if (!mounted) return;
      setState(() {
        _currentCashbackPercentage = updated;
        _cashbackController.text = updated.toString();
        _result = 'merchant_cashback_success'.tr();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingCashback = false;
        });
      }
    }
  }

  Future<void> _createBranch() async {
    if (_branchNameController.text.trim().isEmpty) {
      setState(() {
        _result = 'merchant_branch_name_required'.tr();
      });
      return;
    }
    if (_branchLatitude == null || _branchLongitude == null) {
      setState(() {
        _result = 'merchant_branch_geo_required'.tr();
      });
      return;
    }
    try {
      final created = await CompanyServerService.createMerchantBranch(
        name: _branchNameController.text.trim(),
        address: _branchAddressController.text.trim(),
        location: _branchLocationController.text.trim(),
        latitude: _branchLatitude!,
        longitude: _branchLongitude!,
      );
      final createdBranchId = (created['id'] ?? '').toString();
      setState(() {
        _managerBranchIdController.text = createdBranchId;
        _cashierBranchIdController.text = createdBranchId;
        _result = 'merchant_branch_created'.tr(
          namedArgs: {'id': '${created['id'] ?? ''}'},
        );
      });
      _branchNameController.clear();
      _branchAddressController.clear();
      _branchLocationController.clear();
      _branchLatitude = null;
      _branchLongitude = null;
      await _load();
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Future<void> _pickBranchLocation() async {
    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: (_branchLatitude != null && _branchLongitude != null)
              ? LatLng(_branchLatitude!, _branchLongitude!)
              : null,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _branchLatitude = picked.latitude;
      _branchLongitude = picked.longitude;
      _branchLocationController.text =
          '${picked.latitude.toStringAsFixed(6)}, ${picked.longitude.toStringAsFixed(6)}';
    });
  }

  Future<void> _addManager() async {
    final branchId = _managerBranchIdController.text.trim();
    final userId = _managerUserIdController.text.trim();
    if (branchId.isEmpty) {
      setState(() {
        _result = 'merchant_select_branch_first'.tr();
      });
      return;
    }
    if (userId.isEmpty) {
      setState(() {
        _result = 'merchant_manager_user_id_required'.tr();
      });
      return;
    }
    try {
      await CompanyServerService.addMerchantBranchManager(
        branchId: branchId,
        userId: userId,
      );
      await CompanyServerService.updateBranchManagerPermissions(
        branchId: branchId,
        userId: userId,
        canReviewInvoices: _canReviewInvoices,
        canCreateOffers: _canCreateOffers,
        canManageGroup: _canManageGroup,
        canViewReports: _canViewReports,
        canViewSettlements: _canViewSettlements,
        canAddCashiers: _canAddCashiers,
        canReplyReports: _canReplyReports,
      );
      setState(() {
        _result = 'merchant_manager_permissions_saved'.tr();
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Future<void> _bindCashier() async {
    try {
      final data = await CompanyServerService.bindCashierToBranch(
        branchId: _cashierBranchIdController.text.trim(),
        cashierUserId: _cashierUserIdController.text.trim(),
      );
      setState(() {
        _result = 'merchant_cashier_bound'.tr(
          namedArgs: {'id': '${data['id'] ?? ''}'},
        );
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  // --------------------------------------------------------------------------
  // SECTION 2: OPERATIONAL MAIN DASHBOARD (الصفحة الرئيسية للتاجر)
  // --------------------------------------------------------------------------

  // 1. Quick Action Header (إجراءات سريعة)
  Widget _buildQuickActionHeader() {
    final cashierActive = hasActiveCashierAssociation(_roles);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: kMerchantPrimary, size: 20),
              const SizedBox(width: 6),
              Text(
                'إجراءات سريعة',
                style: kDisplayTextStyle(
                  size: 16,
                  weight: FontWeight.w700,
                  color: kMerchantTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              final items = [
                _buildActionButton(
                  label: '📸 مسح QR كاشير',
                  icon: Icons.qr_code_scanner,
                  bgColor: kMerchantPrimary,
                  textColor: Colors.white,
                  onTap: () {
                    if (cashierActive) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CashierDashboardScreen(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'نظام الكاشير يحتاج تفعيل. يرجى تفعيل صلاحيات الكاشير أولاً.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildActionButton(
                  label: '🎁 إرسال هدية مستهدفة',
                  icon: Icons.card_giftcard_outlined,
                  bgColor: kMerchantPrimaryLight,
                  textColor: kMerchantPrimary,
                  borderColor: kMerchantPrimary.withValues(alpha: 0.3),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MerchantCampaignScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  label: '🛒 تصفح عروض الزبائن',
                  icon: Icons.shopping_bag_outlined,
                  bgColor: const Color(0xFFEDF2F7),
                  textColor: kMerchantTextDark,
                  borderColor: const Color(0xFFCBD5E0),
                  onTap: () => setState(() => _merchantTabIndex = 4),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: item,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: items
                    .map(
                      (item) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: item,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Today's Operational KPI Cards (مؤشرات اليوم)
  Widget _buildTodayKpiGrid() {
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');

    final todaySalesVal = _money(sales['todaySales'] ?? sales['total']);
    final redemptionsVal = _intValue(
      sales['redemptions'] ?? sales['invoiceCount'],
    );
    final pointsVal = _intValue(sales['pointsSpent'] ?? sales['pointsAwarded']);
    final activeCustomersVal = _intValue(
      customers['activeToday'] ?? customers['unique'],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: kMerchantPrimary, size: 20),
              const SizedBox(width: 6),
              Text(
                'مؤشرات اليوم',
                style: kDisplayTextStyle(
                  size: 16,
                  weight: FontWeight.w700,
                  color: kMerchantTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'مبيعات اليوم (LYD)',
                  value: '$todaySalesVal د.ل',
                  icon: Icons.payments_outlined,
                  color: kMerchantPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'عمليات المسح/الاستبدال',
                  value: '$redemptionsVal',
                  icon: Icons.qr_code_2,
                  color: const Color(0xFF2B6CB0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'النقاط الممنوحة',
                  value: '$pointsVal',
                  icon: Icons.stars_rounded,
                  color: kMerchantGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'العملاء النشطون اليوم',
                  value: '$activeCustomersVal',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF805AD5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _buildLightCard(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: kBodyTextStyle(
                    size: 11,
                    weight: FontWeight.w600,
                    color: kMerchantTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: kDisplayTextStyle(
              size: 18,
              weight: FontWeight.w800,
              color: kMerchantTextDark,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Visual Performance Overview (نظرة عامة مصورة)
  Widget _buildVisualPerformanceOverview() {
    final cashierActive = hasActiveCashierAssociation(_roles);
    final sales = _mapSection('sales');
    final totalSales = _toDouble(sales['total']);
    final pointsAwarded = _toDouble(sales['pointsAwarded']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Interactive 7-Day Performance Line Chart
        _buildLightCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'أداء الأسبوع الأخير (7 أيام)',
                      style: kDisplayTextStyle(
                        size: 15,
                        weight: FontWeight.w700,
                        color: kMerchantTextDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kMerchantPrimaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '7D Trend',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: kMerchantPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFEDF2F7),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (val, meta) => Text(
                            val.toInt().toString(),
                            style: const TextStyle(
                              color: kMerchantTextMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final days = [
                              'سبت',
                              'أحد',
                              'إثنين',
                              'ثلاثاء',
                              'أربعاء',
                              'خميس',
                              'جمعة',
                            ];
                            final idx = val.toInt() % days.length;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[idx],
                                style: const TextStyle(
                                  color: kMerchantTextMuted,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // Sales Trend Line (Green)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, totalSales * 0.4),
                          FlSpot(1, totalSales * 0.6),
                          FlSpot(2, totalSales * 0.5),
                          FlSpot(3, totalSales * 0.8),
                          FlSpot(4, totalSales * 0.7),
                          FlSpot(5, totalSales * 0.9),
                          FlSpot(6, totalSales.toDouble()),
                        ],
                        isCurved: true,
                        color: kMerchantPrimary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: kMerchantPrimary.withValues(alpha: 0.1),
                        ),
                      ),
                      // Points Trend Line (Gold)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, pointsAwarded * 0.3),
                          FlSpot(1, pointsAwarded * 0.5),
                          FlSpot(2, pointsAwarded * 0.4),
                          FlSpot(3, pointsAwarded * 0.6),
                          FlSpot(4, pointsAwarded * 0.75),
                          FlSpot(5, pointsAwarded * 0.85),
                          FlSpot(6, pointsAwarded.toDouble()),
                        ],
                        isCurved: true,
                        color: kMerchantGold,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, size: 10, color: kMerchantPrimary),
                      SizedBox(width: 4),
                      Text(
                        'المبيعات (LYD)',
                        style: TextStyle(
                          fontSize: 11,
                          color: kMerchantTextDark,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, size: 10, color: kMerchantGold),
                      SizedBox(width: 4),
                      Text(
                        'النقاط الممنوحة',
                        style: TextStyle(
                          fontSize: 11,
                          color: kMerchantTextDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // POS Alert & Activation Card
        _buildLightCard(
          key: Key(
            cashierActive
                ? 'merchant-pos-entry-enabled'
                : 'merchant-pos-entry-disabled',
          ),
          color: cashierActive
              ? kMerchantPrimaryLight
              : const Color(0xFFFFFBEB),
          border: Border.all(
            color: cashierActive ? kMerchantPrimary : const Color(0xFFFCD34D),
            width: 1.5,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cashierActive
                      ? kMerchantPrimary.withValues(alpha: 0.15)
                      : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  cashierActive
                      ? Icons.point_of_sale
                      : Icons.warning_amber_rounded,
                  color: cashierActive
                      ? kMerchantPrimary
                      : Colors.amber.shade800,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cashierActive
                          ? 'نظام الكاشير (POS) مفعل وجاهز'
                          : 'نظام الكاشير (POS) غير مفعل حالياً',
                      style: kBodyTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: kMerchantTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cashierActive
                          ? 'يمكن للفرع إجراء مسح واستبدال النقاط مباشرة.'
                          : 'قم بتفعيل صلاحيات الكاشير لتمكين استقبال واستبدال الكوبونات.',
                      style: kBodyTextStyle(
                        size: 11,
                        color: kMerchantTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cashierActive
                      ? kMerchantPrimary
                      : Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onPressed: cashierActive
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CashierDashboardScreen(),
                        ),
                      )
                    : () => setState(() => _merchantTabIndex = 4),
                icon: Icon(
                  cashierActive ? Icons.open_in_new : Icons.link,
                  size: 16,
                ),
                label: Text(
                  cashierActive ? 'فتح POS' : '🔗 تفعيل POS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // SECTION 3: DEDICATED DEEP ANALYTICS TAB (صفحة التحليلات العميقة)
  // --------------------------------------------------------------------------
  Widget _buildDeepAnalyticsTab() {
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final loyaltyHealth = _mapSection('loyaltyHealth');
    final financialSummary = _mapSection('financialSummary');
    final genderRows = _listSection('demographics', 'gender');
    final ageRows = _listSection('demographics', 'ageBuckets');
    final heatmapRows = _listSectionDirect('customerHeatmap');

    final retentionPercent = _numValue(customers['retentionPercent']);
    final newCount = _intValue(customers['newCount']);
    final returningCount = _intValue(customers['returningCount']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Floating Action Bar for Controls & Exports
        _buildLightCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: kMerchantPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'التحليلات العميقة',
                    style: kDisplayTextStyle(
                      size: 16,
                      weight: FontWeight.w700,
                      color: kMerchantTextDark,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    onPressed: _loadingAnalytics ? null : _exportAnalyticsPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text(
                      '📄 تصدير PDF',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(color: Colors.green.shade200),
                    ),
                    onPressed: _loadingAnalytics ? null : _exportAnalyticsExcel,
                    icon: const Icon(Icons.grid_on_outlined, size: 16),
                    label: const Text(
                      '📊 تصدير Excel',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filter Bar (Range 7D/30D/90D + Branch Dropdown)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kMerchantBorder),
              ),
              child: DropdownButton<String>(
                value: _analyticsRange,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: '7d', child: Text('7 أيام (7D)')),
                  DropdownMenuItem(value: '30d', child: Text('30 يوم (30D)')),
                  DropdownMenuItem(value: '90d', child: Text('90 يوم (90D)')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _analyticsRange = value);
                  _reloadAnalytics();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kMerchantBorder),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  value: _analyticsBranchId.isEmpty
                      ? '__all__'
                      : _analyticsBranchId,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: '__all__',
                      child: Text(
                        _tx('merchant_all_branches', 'جميع الفروع'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem(
                        value: (b['id'] ?? '').toString(),
                        child: Text(
                          (b['name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(
                      () =>
                          _analyticsBranchId = value == '__all__' ? '' : value,
                    );
                    _reloadAnalytics();
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loadingAnalytics)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // 1. Sales vs. Points Trend Line Chart
          _buildLightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'مقارنة اتجاه المبيعات مقابل النقاط الممنوحة',
                        style: kDisplayTextStyle(
                          size: 14,
                          weight: FontWeight.w700,
                          color: kMerchantTextDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_analyticsRange.toUpperCase()),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: kMerchantPrimaryLight,
                      side: BorderSide.none,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFEDF2F7),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (val, meta) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                color: kMerchantTextMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'T${val.toInt() + 1}',
                                style: const TextStyle(
                                  color: kMerchantTextMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            _analyticsRange == '7d'
                                ? 7
                                : (_analyticsRange == '30d' ? 10 : 12),
                            (i) => FlSpot(
                              i.toDouble(),
                              _toDouble(sales['total']) *
                                  (0.3 + (i * 0.08) % 0.7),
                            ),
                          ),
                          isCurved: true,
                          color: kMerchantPrimary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                        LineChartBarData(
                          spots: List.generate(
                            _analyticsRange == '7d'
                                ? 7
                                : (_analyticsRange == '30d' ? 10 : 12),
                            (i) => FlSpot(
                              i.toDouble(),
                              _toDouble(sales['pointsAwarded']) *
                                  (0.2 + (i * 0.09) % 0.8),
                            ),
                          ),
                          isCurved: true,
                          color: kMerchantGold,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.circle, size: 10, color: kMerchantPrimary),
                    SizedBox(width: 4),
                    Text(
                      'المبيعات (LYD)',
                      style: TextStyle(fontSize: 11, color: kMerchantTextDark),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.circle, size: 10, color: kMerchantGold),
                    SizedBox(width: 4),
                    Text(
                      'النقاط الممنوحة',
                      style: TextStyle(fontSize: 11, color: kMerchantTextDark),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Customer Retention Donut Chart
          _buildLightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نسبة الاحتفاظ بالزبائن (New vs. Returning)',
                  style: kDisplayTextStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: kMerchantTextDark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  color: kMerchantPrimary,
                                  value: returningCount == 0 && newCount == 0
                                      ? 1
                                      : returningCount.toDouble(),
                                  title: '',
                                  radius: 18,
                                ),
                                PieChartSectionData(
                                  color: kMerchantBlue,
                                  value: newCount.toDouble(),
                                  title: '',
                                  radius: 18,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$retentionPercent%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kMerchantTextDark,
                                ),
                              ),
                              const Text(
                                'احتفاظ',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: kMerchantTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: kMerchantPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الزبائن العائدون: $returningCount زبون',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: kMerchantBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'الزبائن الجدد: $newCount زبون',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'إجمالي العملاء: ${newCount + returningCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kMerchantTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Demographic & Location Heatmap Widgets
          _buildLightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التوزيع الديموغرافي للزبائن',
                  style: kDisplayTextStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: kMerchantTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'توزيع الجنس (Gender)',
                            style: TextStyle(
                              fontSize: 11,
                              color: kMerchantTextMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCountRows(genderRows),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الفئات العمرية (Age)',
                            style: TextStyle(
                              fontSize: 11,
                              color: kMerchantTextMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCountRows(ageRows),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer Geographical Heatmap Panel
          _buildLightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'خريطة ومناطق انتشار العملاء الجغرافية',
                  style: kDisplayTextStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: kMerchantTextDark,
                  ),
                ),
                const SizedBox(height: 10),
                AnalyticsMapPanel(
                  points: heatmapRows,
                  emptyLabel: 'لا توجد مواقع زبائن مسجلة للفرع المحدد حالياً.',
                ),
              ],
            ),
          ),

          // Financial & Health Summaries
          _buildLightCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'مؤشر صحة الولاء',
                      style: TextStyle(fontSize: 11, color: kMerchantTextMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_numValue(loyaltyHealth['score'])}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kMerchantPrimary,
                      ),
                    ),
                  ],
                ),
                Container(height: 30, width: 1, color: kMerchantBorder),
                Column(
                  children: [
                    const Text(
                      'نسبة المكافأة',
                      style: TextStyle(fontSize: 11, color: kMerchantTextMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '%${(_currentCashbackPercentage ?? 5.0).toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kMerchantGold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // OVERVIEW TAB INTEGRATION
  // --------------------------------------------------------------------------
  Widget _buildOverviewTab() {
    final cashierActive = hasActiveCashierAssociation(_roles);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubscriptionNotice(),
        _buildQuickActionHeader(),
        _buildTodayKpiGrid(),
        _buildVisualPerformanceOverview(),
        const SizedBox(height: 12),
        _buildLightCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MerchantInvoicesScreen()),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kMerchantGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: kMerchantGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tx('merchant_invoices_title', 'فواتير وتصفية المتجر'),
                      style: kBodyTextStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: kMerchantTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tx(
                        'merchant_invoices_open_hint',
                        'مراجعة الفواتير والعمليات الجارية وسجل المطالبات.',
                      ),
                      style: kBodyTextStyle(
                        size: 11,
                        color: kMerchantTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: kMerchantTextMuted),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // OTHER TABS & SETTINGS
  // --------------------------------------------------------------------------

  Widget _buildMerchantTabPlaceholder({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: kDisplayTextStyle(
            size: 20,
            weight: FontWeight.w700,
            color: kMerchantTextDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: kBodyTextStyle(size: 12, color: kMerchantTextMuted),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildRewardsTab() {
    final rewards = _merchantRewards
        .where((reward) {
          final active = reward['isActive'] == true;
          return _rewardFilter == 'all' ||
              (_rewardFilter == 'active' && active) ||
              (_rewardFilter == 'inactive' && !active);
        })
        .toList(growable: false);

    return _buildMerchantTabPlaceholder(
      title: 'merchant_rewards_tab_title'.tr(),
      subtitle: 'merchant_rewards_tab_subtitle'.tr(),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('all'.tr()),
                selected: _rewardFilter == 'all',
                onSelected: (_) => setState(() => _rewardFilter = 'all'),
              ),
              ChoiceChip(
                label: Text('active'.tr()),
                selected: _rewardFilter == 'active',
                onSelected: (_) => setState(() => _rewardFilter = 'active'),
              ),
              ChoiceChip(
                label: Text('inactive'.tr()),
                selected: _rewardFilter == 'inactive',
                onSelected: (_) => setState(() => _rewardFilter = 'inactive'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kMerchantPrimary,
                ),
                onPressed: _showCreateRewardSheet,
                icon: const Icon(Icons.add),
                label: Text('merchant_create_reward'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rewards.isEmpty && _claims.isEmpty)
            _buildLightCard(
              child: ListTile(title: Text('merchant_no_rewards'.tr())),
            )
          else ...[
            ...rewards.map((reward) {
              final active = reward['isActive'] == true;
              final limit = reward['quantityLimit'];
              final redeemed = reward['quantityRedeemed'] ?? 0;
              return _buildLightCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.card_giftcard_outlined,
                    color: kMerchantPrimary,
                  ),
                  title: Text('${reward['reward_name'] ?? ''}'),
                  subtitle: Text(
                    '${reward['value'] ?? 0} ${'points_value'.tr(namedArgs: {'points': ''})} | ${active ? 'active'.tr() : 'inactive'.tr()}${limit == null ? '' : ' | $redeemed/$limit'}',
                  ),
                  trailing: Switch(
                    value: active,
                    activeColor: kMerchantPrimary,
                    onChanged: (value) async {
                      await CompanyServerService.updateMerchantReward(
                        reward['id'].toString(),
                        isActive: value,
                        quantityLimit: limit is num ? limit.toInt() : null,
                      );
                      await _load();
                    },
                  ),
                ),
              );
            }),
            ..._claims.map((claim) {
              final claimId = (claim['id'] ?? '').toString();
              final reference = (claim['reference'] ?? 'reward_claim:$claimId')
                  .toString();
              final rewardName =
                  (claim['rewardName'] ??
                          claim['reward_name'] ??
                          'Merchant Gift')
                      .toString();
              final status = (claim['status'] ?? 'pending').toString();
              return Tooltip(
                message: reference,
                child: _buildLightCard(
                  key: Key('merchant-reward-claim-$claimId'),
                  child: ListTile(
                    leading: const Icon(
                      Icons.confirmation_number_outlined,
                      color: kMerchantGold,
                    ),
                    title: Text(rewardName),
                    subtitle: Text('Status: $status | Ref: $reference'),
                    trailing: KupunaStatusPill(
                      kind: _invoiceStatusToPill(status),
                      labelOverride: _localizeGenericStatus(status),
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

  Future<void> _showCreateRewardSheet() async {
    await showRewardCreationDialog(
      context: context,
      onSave: (data) async {
        await CompanyServerService.createMerchantReward(
          rewardName: data.rewardName,
          points: data.points,
          description: data.description,
          imageUrl: data.imageUrl,
          kind: data.kind,
          expiresAt: data.expiresAt,
          quantityLimit: data.quantityLimit,
          pickupInstructions: data.pickupInstructions,
          drawEnabled: data.drawEnabled,
          drawAt: data.expiresAt,
        );
        await _load();
      },
    );
  }

  Widget _buildAdsTab() {
    return _buildMerchantTabPlaceholder(
      title: 'merchant_ads_tab_title'.tr(),
      subtitle: 'merchant_ads_tab_subtitle'.tr(),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(
                    color: kMerchantPrimary,
                    child: Icon(
                      Icons.campaign_outlined,
                      size: 52,
                      color: kMerchantGold,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text(
                      'merchant_ads_preview'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLightCard(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddCouponScreen())),
            child: ListTile(
              leading: const Icon(
                Icons.campaign_outlined,
                color: kMerchantPrimary,
              ),
              title: Text('billboard_create_ad'.tr()),
              subtitle: Text('billboard_create_ad_hint'.tr()),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
          const SizedBox(height: 8),
          _buildLightCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantCampaignScreen()),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.ads_click_outlined,
                color: kMerchantGold,
              ),
              title: const Text('إطلاق حملة مستهدفة'),
              subtitle: const Text(
                'استهدف أفضل العملاء وأرسل كوبونات QR خاصة أو تذاكر سحب.',
              ),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTab() {
    final groupMetrics = _mapSection('groupMetrics');
    return _buildMerchantTabPlaceholder(
      title: 'merchant_community_tab_title'.tr(),
      subtitle: 'merchant_community_tab_subtitle'.tr(),
      child: Column(
        children: [
          _buildLightCard(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
            child: ListTile(
              leading: const Icon(
                Icons.groups_outlined,
                color: kMerchantPrimary,
              ),
              title: Text('merchant_community_members'.tr()),
              subtitle: Text('${_intValue(groupMetrics['members'])} عضو نشط'),
              trailing: const Icon(Icons.open_in_new),
            ),
          ),
          _buildCustomerOffersForMerchant(),
        ],
      ),
    );
  }

  Widget _buildCustomerOffersForMerchant() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.storefront, color: kMerchantGold),
            const SizedBox(width: 8),
            Text(
              'merchant_customer_offers_title'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kMerchantTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'merchant_customer_offers_subtitle'.tr(),
          style: const TextStyle(fontSize: 12, color: kMerchantTextMuted),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: CompanyServerService.getMerchantCustomerOffers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تعذر تحميل عروض زبائنك: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                ),
              );
            }
            final offers = snapshot.data ?? [];
            if (offers.isEmpty) {
              return _buildLightCard(
                child: const Text(
                  'لا توجد عروض من زبائنك حالياً.',
                  style: TextStyle(color: kMerchantTextMuted),
                ),
              );
            }

            return Column(
              children: offers.map((offer) {
                final title = (offer['title'] ?? '').toString();
                final desc = (offer['description'] ?? '').toString();
                final price = (offer['price_lyd'] ?? 0).toString();
                final pointsReq = offer['points_required'] ?? 0;
                final acceptsPoints = offer['accepts_points_trade'] == true;
                final sellerName = (offer['seller_name'] ?? 'زبون').toString();
                final loyaltyBadge = (offer['loyalty_badge'] ?? 'زبون مجتمعي')
                    .toString();
                final isFrequent = offer['is_frequent_customer'] == true;
                final offerId = (offer['id'] ?? '').toString();

                return _buildLightCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: kMerchantTextDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kMerchantPrimaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$price د.ل',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kMerchantPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: kMerchantTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            avatar: Icon(
                              isFrequent ? Icons.star : Icons.person,
                              size: 14,
                              color: isFrequent ? Colors.amber : Colors.blue,
                            ),
                            label: Text(
                              loyaltyBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isFrequent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            backgroundColor: isFrequent
                                ? Colors.amber.shade50
                                : Colors.grey.shade100,
                            side: BorderSide(
                              color: isFrequent
                                  ? Colors.amber.shade300
                                  : Colors.grey.shade300,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          if (acceptsPoints)
                            Chip(
                              avatar: const Icon(
                                Icons.stars,
                                color: Colors.amber,
                                size: 14,
                              ),
                              label: Text(
                                'community_points_trade_badge'.tr(
                                  namedArgs: {'points': '$pointsReq'},
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: Colors.amber.shade50,
                              side: BorderSide(color: Colors.amber.shade300),
                              padding: EdgeInsets.zero,
                            ),
                          Chip(
                            avatar: const Icon(Icons.account_circle, size: 14),
                            label: Text(
                              sellerName,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.grey.shade100,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kMerchantPrimary,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            try {
                              final res =
                                  await CompanyServerService.contactCommunityOfferSeller(
                                    offerId: offerId,
                                  );
                              if (!mounted) return;
                              final chatId = (res['chatId'] ?? '').toString();
                              final chatTitle = (res['offerTitle'] ?? title)
                                  .toString();
                              if (chatId.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PrivateChatScreen(
                                      chatId: chatId,
                                      title: chatTitle,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر فتح المحادثة: $e'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('تواصل مع الزبون لدعم الشراء'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoreTab() {
    final businessName = (_merchantProfile['businessName'] ?? 'متجري')
        .toString();
    final status = (_merchantProfile['status'] ?? 'active')
        .toString()
        .toLowerCase();
    final isOpen = status == 'active' || status == 'open';
    final cashback =
        double.tryParse(_cashbackController.text) ??
        _currentCashbackPercentage ??
        0;
    final earned = cashback;
    final points = (earned * 10).toStringAsFixed(earned % 1 == 0 ? 0 : 1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCommandCenterHero(businessName, isOpen),
        const SizedBox(height: 16),
        _buildCommandCenterTabs(),
        const SizedBox(height: 16),
        if (_commandCenterTabIndex == 0)
          _buildDigitalIdentityTab(cashback, earned, points)
        else
          _buildBranchesAndPosTab(),
      ],
    );
  }

  Widget _buildCommandCenterHero(String businessName, bool isOpen) {
    final primaryBranch = _branches.isEmpty ? null : _branches.first;
    final location =
        (primaryBranch?['address'] ??
                primaryBranch?['location'] ??
                'لم تتم إضافة فرع بعد')
            .toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), kMerchantPrimary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  businessName,
                  style: kDisplayTextStyle(
                    size: 21,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              _commandStatusBadge(isOpen),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _heroMeta(Icons.location_on_outlined, location),
              _heroMeta(Icons.chat_outlined, 'واتساب الطلبات: متصل'),
              _heroMeta(Icons.star_outline_rounded, 'التقييم: 4.9'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMeta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: kBodyTextStyle(
            size: 12,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );

  Widget _commandStatusBadge(bool isOpen) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isOpen ? 'مفتوح الآن' : 'مغلق',
      style: TextStyle(
        color: isOpen ? const Color(0xFF166534) : const Color(0xFFB91C1C),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildCommandCenterTabs() => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kMerchantBorder),
    ),
    child: Row(
      children: [
        _commandTab(
          0,
          Icons.language_rounded,
          'الهوية الرقمية والسياسة المالية',
        ),
        _commandTab(1, Icons.account_tree_outlined, 'الفروع ونقاط البيع POS'),
      ],
    ),
  );

  Widget _commandTab(int index, IconData icon, String label) {
    final selected = _commandCenterTabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _commandCenterTabIndex = index),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kMerchantPrimaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? kMerchantPrimary : kMerchantTextMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: kBodyTextStyle(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? kMerchantPrimary : kMerchantTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitalIdentityTab(
    double cashback,
    double earned,
    String points,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'روابط التواصل والتواجد الرقمي',
        style: kDisplayTextStyle(
          size: 17,
          weight: FontWeight.w700,
          color: kMerchantTextDark,
        ),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 560;
          final fields = [
            _digitalField(
              Icons.camera_alt_outlined,
              'انستغرام',
              'instagram.com/your-store',
            ),
            _digitalField(Icons.chat_outlined, 'واتساب الطلبات', '+218 ...'),
            _digitalField(
              Icons.music_note_outlined,
              'تيك توك',
              'tiktok.com/@your-store',
            ),
            _digitalField(
              Icons.map_outlined,
              'موقع Google Maps',
              'رابط الموقع',
            ),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields
                .map(
                  (field) => SizedBox(
                    width: twoColumns
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: field,
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 22),
      _mutableSection(_buildCashbackEngine(cashback, earned, points)),
    ],
  );

  Widget _digitalField(IconData icon, String label, String hint) =>
      _buildLightCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: TextField(
          decoration: InputDecoration(
            icon: Icon(icon, color: kMerchantPrimary),
            labelText: label,
            hintText: hint,
            border: InputBorder.none,
          ),
        ),
      );

  Widget _buildCashbackEngine(
    double cashback,
    double earned,
    String points,
  ) => _buildLightCard(
    color: const Color(0xFFFCFDFD),
    border: Border.all(color: kMerchantPrimary.withValues(alpha: 0.22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: kMerchantGold),
            const SizedBox(width: 8),
            Text(
              'محرك المكافآت الذكي',
              style: kDisplayTextStyle(
                size: 17,
                weight: FontWeight.w700,
                color: kMerchantTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _cashbackController,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'نسبة المكافأة على الفاتورة (%)',
            suffixText: '%',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kMerchantPrimaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'فاتورة بقيمة 100 دينار',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Icon(Icons.arrow_back, size: 16),
              Text(
                'كاشباك ${earned.toStringAsFixed(cashback % 1 == 0 ? 0 : 1)} دينار',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kMerchantPrimary,
                ),
              ),
              const Icon(Icons.arrow_back, size: 16),
              Text(
                'يكتسب الزبون $points نقطة',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _savingCashback ? null : _saveCashbackPercentage,
            icon: const Icon(Icons.publish_outlined),
            label: Text(
              _savingCashback ? 'جارٍ الحفظ...' : 'حفظ ونشر الهوية الرقمية',
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildBranchesAndPosTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: _showAddBranchDialog,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('إضافة فرع جديد'),
          ),
          OutlinedButton.icon(
            onPressed: _showBindCashierDialog,
            icon: const Icon(Icons.link_rounded),
            label: const Text('ربط كاشير'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        'بطاقات الفروع الذكية',
        style: kDisplayTextStyle(
          size: 17,
          weight: FontWeight.w700,
          color: kMerchantTextDark,
        ),
      ),
      const SizedBox(height: 10),
      if (_branches.isEmpty)
        _buildLightCard(
          child: const Text('أضف فرعك الأول لربط نقاط البيع وإدارة العمليات.'),
        ),
      ..._branches.map(_buildSmartBranchCard),
    ],
  );

  Widget _buildSmartBranchCard(Map<String, dynamic> branch) {
    final branchId = (branch['id'] ?? '').toString();
    final active = (branch['status'] ?? 'active').toString() == 'active';
    final cashier =
        (branch['cashierName'] ?? branch['cashier'] ?? 'لا يوجد كاشير مرتبط')
            .toString();
    return _buildLightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: kMerchantPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (branch['name'] ?? 'فرع بدون اسم').toString(),
                  style: kBodyTextStyle(size: 15, weight: FontWeight.w700),
                ),
              ),
              _commandStatusBadge(active),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'الكاشير: $cashier',
            style: kBodyTextStyle(size: 13, color: kMerchantTextMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'ساعات العمل: ${(branch['workingHours'] ?? 'غير محددة').toString()}',
            style: kBodyTextStyle(size: 13, color: kMerchantTextMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showBranchQr(branchId),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('طباعة ملصق QR'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showPosCode(branchId),
                icon: const Icon(Icons.key_outlined, size: 18),
                label: const Text('كود ربط POS'),
              ),
              TextButton.icon(
                onPressed: _showBindCashierDialog,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('تعديل'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBranchDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فرع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _branchNameController,
              decoration: const InputDecoration(labelText: 'اسم الفرع'),
            ),
            TextField(
              controller: _branchAddressController,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickBranchLocation,
              icon: const Icon(Icons.map_outlined),
              label: const Text('تحديد الموقع على الخريطة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              await _createBranch();
              if (mounted && _result != null && !_result!.contains('required'))
                Navigator.of(this.context).pop();
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBindCashierDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ربط كاشير بنقطة بيع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cashierBranchIdController,
              decoration: const InputDecoration(labelText: 'معرّف الفرع'),
            ),
            TextField(
              controller: _cashierUserIdController,
              decoration: const InputDecoration(
                labelText: 'معرّف مستخدم الكاشير',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              await _bindCashier();
              if (mounted) Navigator.of(this.context).pop();
            },
            child: const Text('ربط'),
          ),
        ],
      ),
    );
  }

  void _showBranchQr(String branchId) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ملصق QR للفرع'),
      content: SizedBox(
        width: 220,
        height: 220,
        child: QrImageView(
          data:
              'kupuna://store/${_merchantProfile['id'] ?? ''}?branch=$branchId',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );

  void _showPosCode(String branchId) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('كود ربط نقطة البيع'),
      content: SelectableText(
        branchId.isEmpty ? 'لم يتم العثور على معرّف الفرع' : branchId,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kMerchantBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sessionExpired) {
      return Scaffold(
        backgroundColor: kMerchantBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  size: 48,
                  color: kMerchantGold,
                ),
                const SizedBox(height: 12),
                Text(
                  'merchant_session_expired'.tr(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  icon: const Icon(Icons.login),
                  label: Text('login_again'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: kMerchantBg,
        body: Center(
          key: const Key('merchant-dashboard-load-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: kMerchantGold,
                ),
                const SizedBox(height: 12),
                Text(
                  _tx(
                    'merchant_load_failed',
                    'Unable to load merchant dashboard data.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kMerchantPrimary,
                  ),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(_tx('retry', 'Retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = <Widget>[
      _buildOverviewTab(),
      _buildDeepAnalyticsTab(),
      _buildRewardsTab(),
      _buildAdsTab(),
      _buildCommunityTab(),
      _buildStoreTab(),
      const MerchantNetworksScreen(),
    ];

    return Scaffold(
      backgroundColor: kMerchantBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            children: [
              _buildPendingPointsNotice(),
              Expanded(child: tabs[_merchantTabIndex]),
            ],
          );

          if (constraints.maxWidth >= 840) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _merchantTabIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _merchantTabIndex = index),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: kMerchantPrimaryLight,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      label: Text('merchant_nav_overview'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.analytics_outlined),
                      label: Text('merchant_nav_analytics'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: Text('merchant_nav_rewards'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.campaign_outlined),
                      label: Text('merchant_nav_ads'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.groups_outlined),
                      label: Text('merchant_nav_community'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.store_outlined),
                      label: Text('merchant_nav_store'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.hub_outlined),
                      label: Text('merchant_nav_networks'.tr()),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          }

          final selectedIndex = switch (_merchantTabIndex) {
            0 => 0,
            1 => 1,
            2 => 2,
            5 => 3,
            _ => 4,
          };

          return Column(
            children: [
              Expanded(child: content),
              NavigationBar(
                selectedIndex: selectedIndex,
                backgroundColor: Colors.white,
                indicatorColor: kMerchantPrimaryLight,
                onDestinationSelected: (index) {
                  if (index == 0) {
                    setState(() => _merchantTabIndex = 0);
                  } else if (index == 1) {
                    setState(() => _merchantTabIndex = 1);
                  } else if (index == 2) {
                    setState(() => _merchantTabIndex = 2);
                  } else if (index == 3) {
                    setState(() => _merchantTabIndex = 5);
                  } else {
                    _showMoreDestinations();
                  }
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    label: 'merchant_nav_overview'.tr(),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.analytics_outlined),
                    label: 'merchant_nav_analytics'.tr(),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.card_giftcard_outlined),
                    label: 'merchant_nav_rewards'.tr(),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.store_outlined),
                    label: 'merchant_nav_store'.tr(),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.more_horiz),
                    label: 'more'.tr(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingPointsNotice() {
    return FutureBuilder<Map<String, dynamic>>(
      future:
          (widget.pendingPointsLoader ??
          CompanyServerService.getMerchantPendingPoints)(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final points = int.tryParse('${data?['total_points'] ?? 0}') ?? 0;
        final customers = int.tryParse('${data?['customer_count'] ?? 0}') ?? 0;
        if (points <= 0 || snapshot.hasError) return const SizedBox.shrink();
        return Card(
          color: Colors.amber.shade50,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ListTile(
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
            ),
            title: Text('merchant_pending_points_title'.tr()),
            subtitle: Text(
              'merchant_pending_points_message'.tr(
                namedArgs: {'points': '$points', 'customers': '$customers'},
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'merchant_token_wallet_open'.tr(),
              onPressed: () => setState(() => _merchantTabIndex = 0),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMoreDestinations() async {
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(_tx('merchant_nav_ads', 'Ads')),
              selected: _merchantTabIndex == 3,
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(_tx('merchant_nav_community', 'Community')),
              selected: _merchantTabIndex == 4,
              onTap: () => Navigator.pop(context, 4),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(_tx('merchant_invoices_title', 'Store invoices')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantInvoicesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(_tx('merchant_nav_networks', 'Networks')),
              selected: _merchantTabIndex == 6,
              onTap: () => Navigator.pop(context, 6),
            ),
          ],
        ),
      ),
    );
    if (selectedIndex != null && mounted) {
      setState(() => _merchantTabIndex = selectedIndex);
    }
  }

  Map<String, dynamic> _mapSection(String key) {
    final raw = _analytics[key];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listSection(String outerKey, String innerKey) {
    final outer = _mapSection(outerKey);
    final raw = outer[innerKey];
    if (raw is List) {
      return raw
          .map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _listSectionDirect(String key) {
    final raw = _analytics[key];
    if (raw is List) {
      return raw
          .map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _formatCountRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '-';
    return rows
        .map(
          (row) =>
              '${(row['label'] ?? '-').toString()}: ${_intValue(row['value'])}',
        )
        .join(' | ');
  }

  String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

  String _numValue(dynamic value) => _toDouble(value).toStringAsFixed(2);

  int _intValue(dynamic value) =>
      int.tryParse('${value ?? 0}') ?? _toDouble(value).round();

  Future<void> _exportAnalyticsPdf() async {
    final pdf = pw.Document();
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final loyaltyHealth = _mapSection('loyaltyHealth');
    final financialSummary = _mapSection('financialSummary');
    final topProducts = _listSectionDirect('topBrandProducts');
    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Merchant Analytics Export')),
          pw.Text(
            'Range: $_analyticsRange | Branch: ${_analyticsBranchId.isEmpty ? 'All' : _analyticsBranchId}',
          ),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Sales: ${_money(sales['total'])}'),
          pw.Bullet(text: 'Invoices: ${_intValue(sales['invoiceCount'])}'),
          pw.Bullet(
            text: 'Points awarded: ${_intValue(sales['pointsAwarded'])}',
          ),
          pw.Bullet(
            text: 'Unique customers: ${_intValue(customers['unique'])}',
          ),
          pw.Bullet(text: 'New customers: ${_intValue(customers['newCount'])}'),
          pw.Bullet(
            text:
                'Returning customers: ${_intValue(customers['returningCount'])}',
          ),
          pw.Bullet(
            text: 'Retention: ${_numValue(customers['retentionPercent'])}%',
          ),
          pw.Bullet(text: 'Churn: ${_numValue(customers['churnPercent'])}%'),
          pw.Bullet(
            text:
                'Loyalty health: ${_numValue(loyaltyHealth['score'])} (${(loyaltyHealth['trend'] ?? 'stable').toString()})',
          ),
          pw.Bullet(
            text:
                'Cashback percentage: %${(_currentCashbackPercentage ?? 5.0).toStringAsFixed(1)}',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Top Brand Products'),
          ...topProducts
              .take(8)
              .map(
                (row) => pw.Bullet(
                  text:
                      '${(row['name'] ?? '-').toString()} | ${(row['brandName'] ?? '-').toString()} | ${_money(row['salesTotal'])}',
                ),
              ),
        ],
      ),
    );
    final ok = await downloadBytes(
      bytes: await pdf.save(),
      fileName: 'merchant-analytics-$_analyticsRange.pdf',
      mimeType: 'application/pdf',
    );
    _showExportResult(ok, 'PDF');
  }

  Future<void> _exportAnalyticsExcel() async {
    final buffer = StringBuffer()
      ..writeln('section,label,value')
      ..writeln('sales,total,${_money(_mapSection('sales')['total'])}')
      ..writeln(
        'sales,invoices,${_intValue(_mapSection('sales')['invoiceCount'])}',
      )
      ..writeln(
        'sales,points_awarded,${_intValue(_mapSection('sales')['pointsAwarded'])}',
      )
      ..writeln(
        'customers,unique,${_intValue(_mapSection('customers')['unique'])}',
      )
      ..writeln(
        'customers,new,${_intValue(_mapSection('customers')['newCount'])}',
      )
      ..writeln(
        'customers,returning,${_intValue(_mapSection('customers')['returningCount'])}',
      )
      ..writeln(
        'customers,retention_percent,${_numValue(_mapSection('customers')['retentionPercent'])}',
      )
      ..writeln(
        'customers,churn_percent,${_numValue(_mapSection('customers')['churnPercent'])}',
      );
    for (final row in _listSectionDirect('topBrandProducts')) {
      buffer.writeln(
        'top_brand_products,${(row['name'] ?? '-').toString()},${_money(row['salesTotal'])}',
      );
    }
    final ok = await downloadBytes(
      bytes: utf8.encode(buffer.toString()),
      fileName: 'merchant-analytics-$_analyticsRange.csv',
      mimeType: 'text/csv',
    );
    _showExportResult(ok, 'Excel');
  }

  void _showExportResult(bool ok, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$format download started'
              : '$format export is only supported in web builds.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kMerchantTextDark,
        elevation: 0.5,
        title: Text(
          'merchant_dashboard_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _buildBody(),
    );
  }
}
