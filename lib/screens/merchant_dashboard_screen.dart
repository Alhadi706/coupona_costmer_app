import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
import '../widgets/reward_funding_card.dart';
import 'map_picker_screen.dart';
import 'add_coupon_screen.dart';
import 'community_screen.dart';
import 'cashier_dashboard_screen.dart';
import 'merchant_ads_screen.dart';
import 'merchant_team_screen.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';
import 'login_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'merchant_invoices_screen.dart';
import 'merchant_networks_screen.dart';
import 'merchant_reports_screen.dart';
import 'gift_management_screen.dart';

part 'merchant_dashboard/merchant_dashboard_helpers.dart';
part 'merchant_dashboard/merchant_dashboard_analytics.dart';
part 'merchant_dashboard/merchant_dashboard_overview.dart';

typedef MerchantDashboardLoader = Future<List<dynamic>> Function({
  required String range,
  String? branchId,
});
typedef MerchantAnalyticsLoader = Future<Map<String, dynamic>> Function({
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
  final MerchantDashboardLoader? dashboardLoader;
  final MerchantAnalyticsLoader? analyticsLoader;
  final MerchantPendingPointsLoader? pendingPointsLoader;
  final RewardFundingLoader? rewardFundingLoader;
  final RewardFunder? rewardFunder;

  const MerchantDashboardScreen({
    super.key,
    this.embedded = false,
    this.dashboardLoader,
    this.analyticsLoader,
    this.pendingPointsLoader,
    this.rewardFundingLoader,
    this.rewardFunder,
  });

  const MerchantDashboardScreen.embedded({
    super.key,
    this.dashboardLoader,
    this.analyticsLoader,
    this.pendingPointsLoader,
    this.rewardFundingLoader,
    this.rewardFunder,
  }) : embedded = true;

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final TextEditingController _branchNameController = TextEditingController();
  final TextEditingController _branchAddressController = TextEditingController();
  final TextEditingController _branchLocationController = TextEditingController();
  final TextEditingController _managerBranchIdController = TextEditingController();
  final TextEditingController _managerUserIdController = TextEditingController();
  final TextEditingController _cashierBranchIdController = TextEditingController();
  final TextEditingController _cashierUserIdController = TextEditingController();

  bool _canReviewInvoices = false;
  bool _canCreateOffers = false;
  bool _canManageGroup = false;
  bool _canViewReports = false;
  bool _canViewSettlements = false;
  bool _canAddCashiers = false;
  bool _canReplyReports = false;

  bool _loading = true;
  String? _error;
  bool _sessionExpired = false;
  String? _result;
  double? _branchLatitude;
  double? _branchLongitude;
  String _analyticsRange = '30d';
  int _merchantTabIndex = 0;
  String _analyticsBranchId = '';
  bool _loadingAnalytics = false;
  bool _showLegacyDashboard = false;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewardClaims = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantProducts = <Map<String, dynamic>>[];
  String _rewardFilter = 'all';
  Map<String, dynamic> _loyalty = const <String, dynamic>{};
  Map<String, dynamic> _analytics = const <String, dynamic>{};
  Map<String, dynamic> _roles = const <String, dynamic>{};
  Map<String, dynamic> _merchantProfile = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
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
          ? await widget.dashboardLoader!(range: _analyticsRange, branchId: branchId)
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
              CompanyServerService.getMerchantRewardClaims(),
              CompanyServerService.getMerchantProducts().catchError((_) => <Map<String, dynamic>>[]),
            ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(results[3] as Map<dynamic, dynamic>);
      final rawAnalytics = results[7];
      setState(() {
        _branches = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _loyalty = Map<String, dynamic>.from(results[1] as Map<dynamic, dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[2] as List<dynamic>);
        _offers = List<Map<String, dynamic>>.from(results[4] as List<dynamic>);
        _merchantRewards = List<Map<String, dynamic>>.from(results[5] as List<dynamic>);
        _merchantRewardClaims = results.length > 8
          ? List<Map<String, dynamic>>.from(results[8] as List<dynamic>)
          : <Map<String, dynamic>>[];
        _merchantProducts = results.length > 9
          ? List<Map<String, dynamic>>.from(results[9] as List<dynamic>)
          : <Map<String, dynamic>>[];
        _roles = Map<String, dynamic>.from(results[6] as Map<dynamic, dynamic>);
        _merchantProfile = profile;
        _analytics = rawAnalytics is Map ? Map<String, dynamic>.from(rawAnalytics) : const <String, dynamic>{};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _sessionExpired = e.toString().contains('401') || e.toString().toLowerCase().contains('invalid token');
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
      final data = await (widget.analyticsLoader ?? CompanyServerService.getMerchantAnalytics)(
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

  String _localizeSubscriptionStatus(String raw) => _MerchantDashboardHelpers.localizeSubscriptionStatus(raw);

  String _localizeGenericStatus(dynamic rawStatus) => _MerchantDashboardHelpers.localizeGenericStatus(rawStatus);

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
        ? _tx('merchant_subscription_suspended_body', 'Dashboard editing is locked. Existing points and community data remain unchanged until reactivation.')
        : _tx('merchant_subscription_grace_body', 'Trial ended and the account moved to grace period. Full dashboard access is still available until billing is due.');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _merchantReadOnly ? const Color(0xFFFEF3C7) : const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _merchantReadOnly ? const Color(0xFFF59E0B) : kMerchantBrandGreen, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal)),
          const SizedBox(height: 4),
          Text(body, style: kBodyTextStyle(size: 12, weight: FontWeight.w500, color: kMerchantDarkCharcoal.withValues(alpha: 0.92))),
          const SizedBox(height: 4),
          Text(
            '${_tx('role_subscription_status', 'Subscription status: {status}').replaceAll('{status}', label)}${nextBillingDate.isNotEmpty ? ' • $nextBillingDate' : ''}',
            style: kBodyTextStyle(size: 11, weight: FontWeight.w500, color: kMerchantMuted),
          ),
        ],
      ),
    );
  }

  Widget _mutableSection(Widget child) {
    if (!_merchantReadOnly) return child;
    return Opacity(
      opacity: 0.58,
      child: AbsorbPointer(child: child),
    );
  }

  StatusPillKind _invoiceStatusToPill(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().toLowerCase();
    if (status == 'approved' || status == 'active') {
      return StatusPillKind.approvedMint;
    }
    if (status == 'processing' || status == 'pending_review' || status == 'under_review') {
      return StatusPillKind.pending;
    }
    return StatusPillKind.rejected;
  }

  Widget _buildIndigoSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kPaddingCardCompact),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder, width: kBorderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: kDisplayTextStyle(
              size: 15,
              weight: FontWeight.w700,
              color: kMerchantDarkCharcoal,
            ),
          ),
          const SizedBox(height: kGapTight),
          child,
        ],
      ),
    );
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
        _result = 'merchant_branch_created'.tr(namedArgs: {'id': '${created['id'] ?? ''}'});
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
        canEditPointValue: false,
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
        _result = 'merchant_cashier_bound'.tr(namedArgs: {'id': '${data['id'] ?? ''}'});
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    }
  }

  Widget _buildLegacyBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الواجهة القديمة للتاجر (MerchantCommandCenter)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showLegacyDashboard = false),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('اللوحة الحديثة'),
                ),
              ],
            ),
          ),
          _buildSubscriptionNotice(),
          Container(
            decoration: BoxDecoration(
              color: kIndigo,
              borderRadius: BorderRadius.circular(kRadiusCardLarge),
              border: Border.all(color: kLineDark, width: kBorderWidth),
            ),
            padding: const EdgeInsets.all(kPaddingCard),
            child: Column(
              children: [
                const Center(
                  child: KupunaLoyaltyHealthRing(scorePercent: 78),
                ),
                const SizedBox(height: kGapList),
                Text(
                  'merchant_loyalty_health'.tr(),
                  style: kDisplayTextStyle(
                    size: 18,
                    weight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'merchant_score_trend'.tr(namedArgs: {
                    'score': _toDouble(_loyalty['score']).toStringAsFixed(0),
                    'trend': '${_loyalty['trend'] ?? '-'}',
                  }),
                  style: kBodyTextStyle(
                    size: 12,
                    weight: FontWeight.w400,
                    color: kWhite.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: kGapTight),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: kGold),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: kBodyTextStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGold,
                ),
              ),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _result!,
                style: kBodyTextStyle(
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text('system_point_value_title'.tr()),
              subtitle: Text('system_point_value_description'.tr(namedArgs: const {'value': '0.1'})),
            ),
          ),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'merchant_branches'.tr(),
            child: Column(
              children: _branches
                  .map((branch) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kIndigo,
                          borderRadius: BorderRadius.circular(kRadiusCardCompact),
                          border: Border.all(color: kLineDark, width: kBorderWidth),
                        ),
                        child: ListTile(
                          title: Text(
                            (branch['name'] ?? 'merchant_unnamed_branch'.tr()).toString(),
                            style: kBodyTextStyle(
                              size: 14,
                              weight: FontWeight.w600,
                              color: kWhite,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'merchant_branch_identity'.tr(namedArgs: {
                                  'id': '${branch['id'] ?? ''}',
                                  'address': '${branch['address'] ?? ''}',
                                }),
                                style: kBodyTextStyle(
                                  size: 12,
                                  weight: FontWeight.w400,
                                  color: kWhite.withValues(alpha: 0.86),
                                ),
                              ),
                              const SizedBox(height: 6),
                              KupunaStatusPill(
                                kind: _branchStatusToPill(branch['status']),
                                labelOverride: _localizeGenericStatus(branch['status'] ?? 'pending'),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          _mutableSection(
            ExpansionTile(
              title: Text('merchant_create_branch'.tr()),
              childrenPadding: const EdgeInsets.all(12),
              children: [
              TextField(
                controller: _branchNameController,
                decoration: InputDecoration(labelText: 'merchant_name'.tr()),
              ),
              TextField(
                controller: _branchAddressController,
                decoration: InputDecoration(labelText: 'merchant_address'.tr()),
              ),
              TextField(
                controller: _branchLocationController,
                decoration: InputDecoration(labelText: 'merchant_location'.tr()),
                readOnly: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickBranchLocation,
                icon: const Icon(Icons.map_outlined),
                label: Text('merchant_pick_branch_location'.tr()),
              ),
              if (_branchLatitude != null && _branchLongitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'merchant_branch_geo_selected'.tr(namedArgs: {
                      'lat': _branchLatitude!.toStringAsFixed(6),
                      'lng': _branchLongitude!.toStringAsFixed(6),
                    }),
                  ),
                ),
              const SizedBox(height: 8),
                ElevatedButton(onPressed: _createBranch, child: Text('create'.tr())),
              ],
            ),
          ),
          _mutableSection(
            ExpansionTile(
              title: Text('merchant_assign_manager_permissions'.tr()),
              childrenPadding: const EdgeInsets.all(12),
              children: [
              DropdownButtonFormField<String>(
                initialValue: () {
                  final current = _managerBranchIdController.text.trim();
                  if (current.isEmpty) return null;
                  final exists = _branches.any((b) => (b['id'] ?? '').toString() == current);
                  return exists ? current : null;
                }(),
                items: _branches
                    .map(
                      (branch) => DropdownMenuItem<String>(
                        value: (branch['id'] ?? '').toString(),
                        child: Text(
                          '${branch['name'] ?? 'Branch'} (${branch['id'] ?? ''})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  _managerBranchIdController.text = (value ?? '').trim();
                  setState(() {});
                },
                decoration: InputDecoration(labelText: 'merchant_branch'.tr()),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _managerBranchIdController,
                decoration: InputDecoration(labelText: 'merchant_branch_id'.tr()),
              ),
              TextField(
                controller: _managerUserIdController,
                decoration: InputDecoration(labelText: 'merchant_manager_user_id'.tr()),
              ),
              SwitchListTile(
                value: _canReviewInvoices,
                title: Text('merchant_can_review_invoices'.tr()),
                onChanged: (value) => setState(() => _canReviewInvoices = value),
              ),
              SwitchListTile(
                value: _canCreateOffers,
                title: Text('merchant_can_create_offers'.tr()),
                onChanged: (value) => setState(() => _canCreateOffers = value),
              ),
              SwitchListTile(
                value: _canManageGroup,
                title: Text('merchant_can_manage_group'.tr()),
                onChanged: (value) => setState(() => _canManageGroup = value),
              ),
              SwitchListTile(
                value: _canViewReports,
                title: Text('merchant_can_view_reports'.tr()),
                onChanged: (value) => setState(() => _canViewReports = value),
              ),
              SwitchListTile(
                value: _canViewSettlements,
                title: Text('merchant_can_view_settlements'.tr()),
                onChanged: (value) => setState(() => _canViewSettlements = value),
              ),
              SwitchListTile(
                value: _canAddCashiers,
                title: Text('merchant_can_add_cashiers'.tr()),
                onChanged: (value) => setState(() => _canAddCashiers = value),
              ),
              SwitchListTile(
                value: _canReplyReports,
                title: Text('merchant_can_reply_reports'.tr()),
                onChanged: (value) => setState(() => _canReplyReports = value),
              ),
                ElevatedButton(onPressed: _addManager, child: Text('merchant_save_manager_permissions'.tr())),
              ],
            ),
          ),
          _mutableSection(
            ExpansionTile(
              title: Text('merchant_bind_cashier'.tr()),
              childrenPadding: const EdgeInsets.all(12),
              children: [
              TextField(
                controller: _cashierBranchIdController,
                decoration: InputDecoration(labelText: 'merchant_branch_id'.tr()),
              ),
              TextField(
                controller: _cashierUserIdController,
                decoration: InputDecoration(labelText: 'merchant_cashier_user_id'.tr()),
              ),
                ElevatedButton(onPressed: _bindCashier, child: Text('merchant_bind_cashier_action'.tr())),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _mutableSection(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PointsConversionScreen()),
                    );
                  },
                  child: Text('merchant_points_conversion'.tr()),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RewardQrCodeScreen()),
                    );
                  },
                  child: Text('merchant_create_reward_qr'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddCouponScreen()),
                    );
                  },
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text('billboard_create_ad'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MerchantNetworksScreen()),
                    );
                  },
                  icon: const Icon(Icons.hub_outlined),
                  label: Text('merchant_nav_networks'.tr()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'merchant_latest_offers'.tr(),
            child: Column(
              children: _offers.take(6).map((offer) {
                final String title = (offer['description'] ?? offer['title'] ?? 'offer'.tr()).toString();
                final String category = (offer['category'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KupunaOfferCard(
                    offer: <String, dynamic>{
                      ...offer,
                      'title': title,
                      'subtitle': category,
                      'sourceType': 'merchant',
                    },
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'merchant_recent_invoices'.tr(),
            child: Column(
              children: _invoices
                  .map((invoice) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kIndigo,
                          borderRadius: BorderRadius.circular(kRadiusCardCompact),
                          border: Border.all(color: kLineDark, width: kBorderWidth),
                        ),
                        child: ListTile(
                          title: Text(
                            (invoice['merchantName'] ?? 'merchant_unknown_merchant'.tr()).toString(),
                            style: kBodyTextStyle(
                              size: 14,
                              weight: FontWeight.w600,
                              color: kWhite,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'merchant_invoice_line'.tr(namedArgs: {
                                  'invoice': '${invoice['invoiceNumber'] ?? '-'}',
                                  'total': '${invoice['totalAmount'] ?? '-'}',
                                }),
                                style: kBodyTextStyle(
                                  size: 12,
                                  weight: FontWeight.w400,
                                  color: kWhite.withValues(alpha: 0.86),
                                ),
                              ),
                              const SizedBox(height: 6),
                              KupunaStatusPill(
                                kind: _invoiceStatusToPill(invoice['state'] ?? invoice['lifecycleStatus']),
                                labelOverride: _localizeGenericStatus(invoice['state'] ?? invoice['lifecycleStatus'] ?? 'processing'),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 8),
          _buildAnalyticsSuite(),
          const SizedBox(height: 8),
          _buildIndigoSection(
            title: 'merchant_reports_settlements_snapshot'.tr(),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'merchant_count_invoices'.tr(namedArgs: {'count': '${_invoices.length}'}),
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
                Chip(
                  label: Text(
                    'merchant_count_branches'.tr(namedArgs: {'count': '${_branches.length}'}),
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
                Chip(
                  label: Text(
                    'merchant_count_offers'.tr(namedArgs: {'count': '${_offers.length}'}),
                    style: kBodyTextStyle(size: 12, weight: FontWeight.w600, color: kWhite),
                  ),
                  backgroundColor: kIndigo,
                  side: const BorderSide(color: kLineDark, width: kBorderWidth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantTabPlaceholder({required String title, required String subtitle, required Widget child}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: kDisplayTextStyle(size: 22, weight: FontWeight.w700, color: kInk)),
        const SizedBox(height: 4),
        Text(subtitle, style: kBodyTextStyle(size: 13, color: kInk.withValues(alpha: 0.65))),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildRewardsTab() {
    final rewards = _merchantRewards.where((reward) {
      final active = reward['isActive'] == true;
      return _rewardFilter == 'all' || (_rewardFilter == 'active' && active) || (_rewardFilter == 'inactive' && !active);
    }).toList(growable: false);
    return _buildMerchantTabPlaceholder(
      title: 'merchant_rewards_tab_title'.tr(),
      subtitle: 'merchant_rewards_tab_subtitle'.tr(),
      child: Column(
        children: [
          RewardFundingCard(
            sourceType: 'merchant',
            loader: widget.rewardFundingLoader,
            funder: widget.rewardFunder,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text('all'.tr()), selected: _rewardFilter == 'all', onSelected: (_) => setState(() => _rewardFilter = 'all')),
              ChoiceChip(label: Text('active'.tr()), selected: _rewardFilter == 'active', onSelected: (_) => setState(() => _rewardFilter = 'active')),
              ChoiceChip(label: Text('inactive'.tr()), selected: _rewardFilter == 'inactive', onSelected: (_) => setState(() => _rewardFilter = 'inactive')),
              FilledButton.icon(onPressed: _showCreateRewardSheet, icon: const Icon(Icons.add), label: Text('merchant_create_reward'.tr())),
            ],
          ),
          const SizedBox(height: 12),
          if (rewards.isEmpty)
            Card(child: ListTile(title: Text('merchant_no_rewards'.tr())))
          else
            ...rewards.map((reward) {
              final active = reward['isActive'] == true;
              final limit = reward['quantityLimit'];
              final redeemed = reward['quantityRedeemed'] ?? 0;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard_outlined, color: kTeal),
                  title: Text('${reward['reward_name'] ?? ''}'),
                  subtitle: Text('${reward['value'] ?? 0} ${'points_value'.tr(namedArgs: {'points': ''})} | ${active ? 'active'.tr() : 'inactive'.tr()}${limit == null ? '' : ' | $redeemed/$limit'}'),
                  trailing: Switch(value: active, onChanged: (value) async {
                    await CompanyServerService.updateMerchantReward(reward['id'].toString(), isActive: value, quantityLimit: limit is num ? limit.toInt() : null);
                    await _load();
                  }),
                ),
              );
            }),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'merchant_reward_claims_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          const SizedBox(height: 8),
          if (_merchantRewardClaims.isEmpty)
            Card(child: ListTile(title: Text('merchant_reward_claims_empty'.tr())))
          else
            ..._merchantRewardClaims.take(10).map((claim) {
              final claimId = (claim['id'] ?? '').toString();
              final shortId = claimId.substring(0, claimId.length.clamp(0, 8));
              return Card(
                child: ListTile(
                  key: Key('merchant-reward-claim-$claimId'),
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text((claim['rewardName'] ?? 'reward_generic'.tr()).toString()),
                  subtitle: Text('${claim['status'] ?? '-'} • ${claim['pointsCost'] ?? 0}'),
                  trailing: Tooltip(
                    message: (claim['reference'] ?? '').toString(),
                    child: Text('#$shortId'),
                  ),
                ),
              );
            }),
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
    return const MerchantAdsTab();
  }

  Widget _buildCommunityTab() {
    final groupMetrics = _mapSection('groupMetrics');
    return _buildMerchantTabPlaceholder(
      title: 'merchant_community_tab_title'.tr(),
      subtitle: 'merchant_community_tab_subtitle'.tr(),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_outlined, color: kTeal),
              title: Text('merchant_community_members'.tr()),
              subtitle: Text('${_intValue(groupMetrics['members'])}'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityScreen())),
            ),
          ),
          const SizedBox(height: 12),
          _buildAnalyticsBlock('merchant_analytics_group_metrics_title'.tr(), [
            'merchant_analytics_group_metrics_line_1'.tr()
                .replaceAll('{groups}', '${_intValue(groupMetrics['groups'])}')
                .replaceAll('{members}', '${_intValue(groupMetrics['members'])}')
                .replaceAll('{messages}', '${_intValue(groupMetrics['messages'])}'),
          ]),
        ],
      ),
    );
  }

  Future<void> _editMerchantProduct([Map<String, dynamic>? product]) async {
    final name = TextEditingController(text: product != null ? '${product['name'] ?? ''}' : '');
    final imageUrl = TextEditingController(text: product != null ? '${product['imageUrl'] ?? product['image_url'] ?? ''}' : '');
    final price = TextEditingController(text: product != null && product['price'] != null ? '${product['price']}' : '');
    final description = TextEditingController(text: product != null ? '${product['description'] ?? ''}' : '');
    var active = product != null ? product['isActive'] != false : true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product == null ? 'إضافة منتج للمتجر' : 'تعديل المنتج',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المنتج *'),
                  ),
                  TextField(
                    controller: price,
                    decoration: const InputDecoration(labelText: 'السعر (اختياري)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'وصف المنتج (اختياري)'),
                  ),
                  TextField(
                    controller: imageUrl,
                    decoration: InputDecoration(
                      labelText: 'brand_image_url_optional'.tr(),
                      hintText: 'https://...',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  if (imageUrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl.text.trim(),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  if (product != null)
                    SwitchListTile(
                      value: active,
                      title: const Text('المنتج نشط'),
                      subtitle: const Text('سيظهر للعملاء في التطبيق عند تفعيله'),
                      onChanged: (value) => setSheetState(() => active = value),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final parsedPrice = double.tryParse(price.text.trim());
                        if (name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اسم المنتج مطلوب')),
                          );
                          return;
                        }
                        if (product == null) {
                          await CompanyServerService.createMerchantProduct(
                            name: name.text.trim(),
                            imageUrl: imageUrl.text.trim(),
                            price: parsedPrice,
                            description: description.text.trim(),
                          );
                        } else {
                          await CompanyServerService.updateMerchantProduct(
                            productId: (product['id'] ?? '').toString(),
                            name: name.text.trim(),
                            imageUrl: imageUrl.text.trim(),
                            price: parsedPrice,
                            description: description.text.trim(),
                            isActive: active,
                          );
                        }
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        await _load();
                      },
                      child: Text('save'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      name.dispose();
      imageUrl.dispose();
      price.dispose();
      description.dispose();
    }
  }

  Widget _buildStoreTab() {
    final selectedBranch = _branches.isEmpty
        ? const <String, dynamic>{}
        : (_branches.firstWhere(
            (branch) => (branch['id'] ?? '').toString() == _analyticsBranchId,
            orElse: () => _branches.first,
          ));
    final merchantId = (_merchantProfile['id'] ?? '').toString();
    final branchId = (selectedBranch['id'] ?? '').toString();
    final storeQrData = 'kupuna://store/$merchantId${branchId.isEmpty ? '' : '?branch=$branchId'}';
    return _buildMerchantTabPlaceholder(
      title: 'merchant_store_tab_title'.tr(),
      subtitle: 'merchant_store_tab_subtitle'.tr(),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined, color: kTeal),
              title: Text((_merchantProfile['businessName'] ?? 'merchant_name'.tr()).toString()),
              subtitle: Text('${_merchantProfile['commercialRegistration'] ?? ''}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('merchant_store_qr_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('merchant_store_qr_hint'.tr(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (merchantId.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.white,
                      child: QrImageView(data: storeQrData, size: 190),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    branchId.isEmpty ? 'merchant_all_branches'.tr() : '${selectedBranch['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kTeal),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'merchant_branches'.tr(),
            child: Column(
              children: _branches.map((branch) {
                final bImg = (branch['imageUrl'] ?? branch['image_url'] ?? '').toString();
                final bLat = branch['latitude'] ?? branch['lat'];
                final bLng = branch['longitude'] ?? branch['lng'];
                return ListTile(
                  leading: bImg.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            bImg,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.store_outlined, color: kTeal),
                          ),
                        )
                      : Icon(
                          Icons.store_outlined,
                          color: (branch['id'] ?? '').toString() == (selectedBranch['id'] ?? '').toString() ? kTeal : null,
                        ),
                  title: Text((branch['name'] ?? 'merchant_unnamed_branch'.tr()).toString()),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${branch['address'] ?? ''}${(branch['workingHours'] ?? '').toString().isEmpty ? '' : ' | ${branch['workingHours']}'}'),
                      if ((branch['phone'] ?? '').toString().isNotEmpty)
                        Text('${'merchant_phone'.tr()}: ${branch['phone']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (bLat != null && bLng != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: kTealDark),
                            const SizedBox(width: 4),
                            Text(
                              '${double.parse(bLat.toString()).toStringAsFixed(4)}, ${double.parse(bLng.toString()).toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: kTealDark),
                            ),
                          ],
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'merchant_edit_branch'.tr(),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editBranch(branch),
                  ),
                  onTap: () => setState(() => _analyticsBranchId = (branch['id'] ?? '').toString()),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'منتجات المتجر',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editMerchantProduct(),
                    icon: const Icon(Icons.add_circle_outline, color: kTeal),
                    label: const Text('إضافة منتج جديد', style: TextStyle(color: kTeal)),
                  ),
                ),
                if (_merchantProducts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'لا توجد منتجات مضافة لهذا المتجر حاليًا.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _merchantProducts.length,
                      itemBuilder: (context, index) {
                        final product = _merchantProducts[index];
                        final pName = (product['name'] ?? '').toString();
                        final pImage = (product['imageUrl'] ?? product['image_url'] ?? '').toString();
                        final pPrice = product['price'];

                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 10),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: InkWell(
                              onTap: () => _editMerchantProduct(product),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: pImage.isNotEmpty
                                        ? Image.network(
                                            pImage,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Center(
                                              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade100,
                                            child: const Center(
                                              child: Icon(Icons.inventory_2_outlined, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        if (pPrice != null)
                                          Text(
                                            '$pPrice د.ل',
                                            style: const TextStyle(
                                              color: kTealDark,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: kTeal),
              title: Text('merchant_team_title'.tr()),
              subtitle: Text('merchant_team_open_hint'.tr()),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MerchantTeamScreen(branches: _branches),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_showLegacyDashboard) return _buildLegacyBody();
    if (_loading) return _buildLegacyBody();
    if (_sessionExpired) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 48, color: kGold),
              const SizedBox(height: 12),
              Text('merchant_session_expired'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())),
                icon: const Icon(Icons.login),
                label: Text('login_again'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('merchant-dashboard-load-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: kGold),
              const SizedBox(height: 12),
              Text(
                _tx('merchant_load_failed', 'Unable to load merchant dashboard data.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_tx('retry', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    final tabs = <Widget>[
      _buildOverviewTab(),
      _buildRewardsTab(),
      _buildAdsTab(),
      _buildCommunityTab(),
      _buildStoreTab(),
      const MerchantNetworksScreen(),
    ];
    return LayoutBuilder(
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
                onDestinationSelected: (index) => setState(() => _merchantTabIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), label: Text(_tx('merchant_nav_overview', 'Overview'))),
                  NavigationRailDestination(icon: const Icon(Icons.card_giftcard_outlined), label: Text(_tx('merchant_nav_rewards', 'Rewards'))),
                  NavigationRailDestination(icon: const Icon(Icons.campaign_outlined), label: Text(_tx('merchant_nav_ads', 'Ads'))),
                  NavigationRailDestination(icon: const Icon(Icons.groups_outlined), label: Text(_tx('merchant_nav_community', 'Community'))),
                  NavigationRailDestination(icon: const Icon(Icons.store_outlined), label: Text(_tx('merchant_nav_store', 'Store'))),
                  NavigationRailDestination(icon: const Icon(Icons.hub_outlined), label: Text(_tx('merchant_nav_networks', 'Networks'))),
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
          4 => 3,
          _ => 4,
        };
        return Column(
          children: [
            Expanded(child: content),
            NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                if (index < 3) {
                  setState(() => _merchantTabIndex = index);
                } else if (index == 3) {
                  setState(() => _merchantTabIndex = 4);
                } else {
                  _showMoreDestinations();
                }
              },
              destinations: [
                NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: _tx('merchant_nav_overview', 'Overview')),
                NavigationDestination(icon: const Icon(Icons.card_giftcard_outlined), label: _tx('merchant_nav_rewards', 'Rewards')),
                NavigationDestination(icon: const Icon(Icons.campaign_outlined), label: _tx('merchant_nav_ads', 'Ads')),
                NavigationDestination(icon: const Icon(Icons.store_outlined), label: _tx('merchant_nav_store', 'Store')),
                NavigationDestination(icon: const Icon(Icons.more_horiz), label: _tx('more', 'More')),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingPointsNotice() {
    return FutureBuilder<Map<String, dynamic>>(
      future: (widget.pendingPointsLoader ?? CompanyServerService.getMerchantPendingPoints)(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final points = int.tryParse('${data?['total_points'] ?? 0}') ?? 0;
        final customers = int.tryParse('${data?['customer_count'] ?? 0}') ?? 0;
        if (points <= 0 || snapshot.hasError) return const SizedBox.shrink();
        return Card(
          color: Colors.orange.shade50,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text('merchant_pending_points_title'.tr()),
            subtitle: Text('merchant_pending_points_message'.tr(namedArgs: {
              'points': '$points',
              'customers': '$customers',
            })),
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
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(_tx('merchant_invoices_title', 'Store invoices')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute(builder: (_) => const MerchantInvoicesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(_tx('merchant_reports_title', 'Store reports')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(this.context).push(
                  MaterialPageRoute(builder: (_) => const MerchantReportsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(_tx('merchant_nav_community', 'Community')),
              selected: _merchantTabIndex == 3,
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(_tx('merchant_nav_networks', 'Networks')),
              selected: _merchantTabIndex == 5,
              onTap: () => Navigator.pop(context, 5),
            ),
          ],
        ),
      ),
    );
    if (selectedIndex != null && mounted) {
      setState(() => _merchantTabIndex = selectedIndex);
    }
  }

  Widget _buildQuickActionHeader(bool cashierActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات سريعة للمحل',
            style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantMuted),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CashierDashboardScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cashierActive ? kMerchantBrandGreen : const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: Text(
                    cashierActive ? '📸 مسح QR كاشير' : '📸 تجربة كاشير (معاينة)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showLegacyDashboard = !_showLegacyDashboard),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: kTealDark,
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.alt_route_outlined, size: 16),
                  label: const Text(
                    '🏛️ اللوحة القديمة (CommandCenter)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GiftManagementScreen(ownerLabel: 'merchant_owner_label'.tr()),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    foregroundColor: kMerchantBrandGreen,
                    side: const BorderSide(color: kMerchantBrandGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.card_giftcard, size: 16),
                  label: Text(
                    'merchant_manage_gifts_campaigns'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCreateRewardSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: kMerchantBrandGreen,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.card_giftcard, size: 16),
                  label: const Text(
                    '🎁 إرسال هدية مستهدفة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _merchantTabIndex = 4),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: kMerchantDarkCharcoal,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text(
                    '🛒 تصفح عروض الزبائن',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOperationalKpis(Map<String, dynamic> sales, Map<String, dynamic> customers) {
    final salesTotal = _money(sales['total'] ?? sales['todaySales']);
    final redemptions = _intValue(sales['redemptions']);
    final pointsSpent = _intValue(sales['pointsSpent'] ?? sales['pointsAwarded']);
    final activeCustomers = _intValue(customers['activeToday'] ?? customers['unique']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiMetricCard(
              width: itemWidth,
              title: 'مبيعات اليوم (LYD)',
              value: salesTotal,
              icon: Icons.payments_outlined,
              iconColor: kMerchantBrandGreen,
              bgColor: const Color(0xFFECFDF5),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'عمليات المسح/الاستبدال',
              value: '$redemptions',
              icon: Icons.qr_code_2_outlined,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'النقاط الممنوحة',
              value: '$pointsSpent',
              icon: Icons.stars_outlined,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
            ),
            _kpiMetricCard(
              width: itemWidth,
              title: 'العملاء النشطون اليوم',
              value: '$activeCustomers',
              icon: Icons.people_alt_outlined,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiMetricCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: kBodyTextStyle(size: 11, weight: FontWeight.w600, color: kMerchantMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: kDisplayTextStyle(size: 17, weight: FontWeight.w800, color: kMerchantDarkCharcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosStatusAlertCard(bool cashierActive) {
    return Card(
      key: Key(cashierActive ? 'merchant-pos-entry-enabled' : 'merchant-pos-entry-disabled'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cashierActive ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
        ),
      ),
      color: cashierActive ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cashierActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            cashierActive ? Icons.point_of_sale : Icons.warning_amber_rounded,
            color: cashierActive ? kMerchantBrandGreen : const Color(0xFFD97706),
          ),
        ),
        title: Text(
          cashierActive ? 'حالة POS مفعلة وجاهزة للاستخدام' : 'حالة نظام الكاشير (POS) غير مفعلة',
          style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
        ),
        subtitle: Text(
          cashierActive
              ? 'يمكنك إجراء عمليات المسح واستبدال النقاط مباشرة'
              : 'قم بتفعيل ربط كاشير المحل للبدء في استقبال واستبدال نقاط العملاء',
          style: kBodyTextStyle(size: 12, color: kMerchantMuted),
        ),
        trailing: ElevatedButton.icon(
          onPressed: cashierActive
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CashierDashboardScreen()),
                  )
              : () => _showPosActivationDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: cashierActive ? kMerchantBrandGreen : const Color(0xFFD97706),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            elevation: 0,
          ),
          icon: Icon(cashierActive ? Icons.login : Icons.link, size: 16),
          label: Text(
            cashierActive ? 'فتح POS' : '🔗 تفعيل POS',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  void _showPosActivationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل ربط كاشير POS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لتفعيل حاسب الكاشير الخاص بالفرع:'),
            const SizedBox(height: 8),
            const Text('1. اختر الفرع المراد ربطه.'),
            const Text('2. أدخل معرف المستخدم الخاص بالكاشير.'),
            const SizedBox(height: 12),
            TextField(
              controller: _cashierUserIdController,
              decoration: const InputDecoration(
                labelText: 'معرف مستخدم الكاشير',
                hintText: 'مثال: user-cashier-101',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bindCashier();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kMerchantBrandGreen, foregroundColor: Colors.white),
            child: const Text('تأكيد التفعيل'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeepAnalyticsBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMerchantCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMerchantBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التحليلات التفصيلية للعملاء والأداء',
                style: kBodyTextStyle(size: 14, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
              ),
              const SizedBox(height: 2),
              Text(
                'معدلات الاستدامة، التوزيع الجغرافي والديموغرافي مع خيارات التصدير',
                style: kBodyTextStyle(size: 11, color: kMerchantMuted),
              ),
            ],
          );

          final actionBtn = ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/merchant/analytics');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kMerchantBrandGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: const Text('فتح التحليلات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: actionBtn),
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kMerchantBrandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_outlined, color: kMerchantBrandGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: content),
              const SizedBox(width: 8),
              actionBtn,
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab() {
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final cashierActive = hasActiveCashierAssociation(_roles);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubscriptionNotice(),
        _buildQuickActionHeader(cashierActive),
        const SizedBox(height: 12),
        _buildTodayOperationalKpis(sales, customers),
        const SizedBox(height: 12),
        _build7DayPerformanceChart(),
        const SizedBox(height: 12),
        _buildPosStatusAlertCard(cashierActive),
        const SizedBox(height: 12),
        _buildDeepAnalyticsBanner(),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: CompanyServerService.getMerchantEscrowSummary(),
          builder: (_, snapshot) => snapshot.hasData
              ? Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: kMerchantBrandGreen),
                    title: Text('merchant_escrow_summary'.tr()),
                    subtitle: Text('${'merchant_escrow_balance'.tr()}: ${snapshot.data?['escrowAccount']?['balance'] ?? 0} • ${'merchant_settlements_count'.tr()}: ${(snapshot.data?['settlements'] as List?)?.length ?? 0}'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: kGold),
            title: Text(_tx('merchant_invoices_title', 'Store invoices')),
            subtitle: Text(_tx('merchant_invoices_open_hint', 'Review processing invoices and customer disputes.')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantInvoicesScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined, color: kGold),
            title: Text(_tx('merchant_reports_title', 'Store reports')),
            subtitle: Text(_tx('merchant_reports_open_hint', 'Review customer reports and issue compensation when appropriate.')),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantReportsScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAnalyticsSuite(),
      ],
    );
  }

  Future<void> _editBranch(Map<String, dynamic> branch) async {
    final name = TextEditingController(text: '${branch['name'] ?? ''}');
    final address = TextEditingController(text: '${branch['address'] ?? ''}');
    final hours = TextEditingController(text: '${branch['workingHours'] ?? ''}');
    final phone = TextEditingController(text: '${branch['phone'] ?? ''}');
    final imageUrl = TextEditingController(text: '${branch['imageUrl'] ?? branch['image_url'] ?? ''}');
    double? selectedLat = branch['lat'] != null ? double.tryParse(branch['lat'].toString()) : (branch['latitude'] != null ? double.tryParse(branch['latitude'].toString()) : null);
    double? selectedLng = branch['lng'] != null ? double.tryParse(branch['lng'].toString()) : (branch['longitude'] != null ? double.tryParse(branch['longitude'].toString()) : null);
    var active = (branch['status'] ?? 'active').toString() == 'active';
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('merchant_edit_branch'.tr(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  TextField(controller: name, decoration: InputDecoration(labelText: 'merchant_name'.tr())),
                  TextField(controller: address, decoration: InputDecoration(labelText: 'merchant_address'.tr())),
                  TextField(controller: hours, decoration: InputDecoration(labelText: 'merchant_working_hours'.tr())),
                  TextField(controller: phone, decoration: InputDecoration(labelText: 'merchant_phone'.tr())),
                  TextField(
                    controller: imageUrl,
                    decoration: InputDecoration(
                      labelText: 'brand_image_url_optional'.tr(),
                      hintText: 'https://...',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  if (imageUrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl.text.trim(),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: Colors.grey.shade100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedLat != null && selectedLng != null
                              ? '${'location_on_map'.tr()}: ${selectedLat!.toStringAsFixed(6)}, ${selectedLng!.toStringAsFixed(6)}'
                              : 'merchant_branch_geo_required'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selectedLat != null ? kTealDark : Colors.red,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final LatLng? picked = await Navigator.of(context).push<LatLng>(
                            MaterialPageRoute(
                              builder: (_) => MapPickerScreen(
                                initialLocation: (selectedLat != null && selectedLng != null)
                                    ? LatLng(selectedLat!, selectedLng!)
                                    : null,
                              ),
                            ),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedLat = picked.latitude;
                              selectedLng = picked.longitude;
                            });
                          }
                        },
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text('pick_location_on_map'.tr()),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    value: active,
                    title: Text('merchant_branch_active'.tr()),
                    subtitle: Text(active ? 'merchant_branch_active_hint'.tr() : 'merchant_branch_inactive_hint'.tr()),
                    onChanged: (value) => setSheetState(() => active = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await CompanyServerService.updateMerchantBranch(
                          branchId: (branch['id'] ?? '').toString(),
                          name: name.text.trim(),
                          address: address.text.trim(),
                          workingHours: hours.text.trim(),
                          phone: phone.text.trim(),
                          status: active ? 'active' : 'inactive',
                          latitude: selectedLat,
                          longitude: selectedLng,
                          imageUrl: imageUrl.text.trim(),
                        );
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        await _load();
                      },
                      child: Text('save'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      name.dispose();
      address.dispose();
      hours.dispose();
      phone.dispose();
      imageUrl.dispose();
    }
  }

  Widget _buildAnalyticsSuite() {
    final sales = _mapSection('sales');
    final customers = _mapSection('customers');
    final offerPerformance = _mapSection('offerPerformance');
    final peakTimes = _mapSection('peakTimes');
    final groupMetrics = _mapSection('groupMetrics');
    final financialSummary = _mapSection('financialSummary');
    final loyaltyHealth = _mapSection('loyaltyHealth');
    final genderRows = _listSection('demographics', 'gender');
    final ageRows = _listSection('demographics', 'ageBuckets');
    final hourRows = _listSection('peakTimes', 'byHour');
    final weekdayRows = _listSection('peakTimes', 'byWeekday');
    final statusRows = _listSection('offerPerformance', 'statusBreakdown');
    final heatmapRows = _listSectionDirect('customerHeatmap');
    final topProductRows = _listSectionDirect('topBrandProducts');

    return _buildIndigoSection(
      title: 'merchant_analytics_dashboard'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: _analyticsRange,
                items: const [
                  DropdownMenuItem(value: '7d', child: Text('7D')),
                  DropdownMenuItem(value: '30d', child: Text('30D')),
                  DropdownMenuItem(value: '90d', child: Text('90D')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _analyticsRange = value;
                  });
                  _reloadAnalytics();
                },
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _analyticsBranchId.isEmpty ? '__all__' : _analyticsBranchId,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: '__all__',
                      child: Text(
                        _tx('merchant_all_branches', 'All branches'),
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
                    setState(() {
                      _analyticsBranchId = value == '__all__' ? '' : value;
                    });
                    _reloadAnalytics();
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadingAnalytics ? null : _exportAnalyticsPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('merchant_export_pdf'.tr()),
              ),
              OutlinedButton.icon(
                onPressed: _loadingAnalytics ? null : _exportAnalyticsExcel,
                icon: const Icon(Icons.grid_on_outlined),
                label: Text('merchant_export_excel'.tr()),
              ),
            ],
          ),
          if (_loadingAnalytics)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: 8),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_sales_points_title', 'Sales and points'),
              [
                _tx('merchant_analytics_sales_points_line_1', 'Sales {sales} | Invoices {invoices} | Avg bill {avgBill}')
                    .replaceAll('{sales}', _money(sales['total']))
                    .replaceAll('{invoices}', '${_intValue(sales['invoiceCount'])}')
                    .replaceAll('{avgBill}', _money(sales['averageBill'])),
                _tx('merchant_analytics_sales_points_line_2', 'Points awarded {points} | Growth {growth}%')
                    .replaceAll('{points}', '${_intValue(sales['pointsAwarded'])}')
                    .replaceAll('{growth}', _numValue(sales['salesGrowthPercent'])),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_customers_title', 'Customers'),
              [
                _tx('merchant_analytics_customers_line_1', 'Unique {unique} | New {newCount} | Returning {returning}')
                    .replaceAll('{unique}', '${_intValue(customers['unique'])}')
                    .replaceAll('{newCount}', '${_intValue(customers['newCount'])}')
                    .replaceAll('{returning}', '${_intValue(customers['returningCount'])}'),
                _tx('merchant_analytics_customers_line_2', 'Retention {retention}% | Churn {churn}% | Top customers {topCustomers}')
                    .replaceAll('{retention}', _numValue(customers['retentionPercent']))
                    .replaceAll('{churn}', _numValue(customers['churnPercent']))
                    .replaceAll('{topCustomers}', '${_intValue(_analytics['topCustomersCount'])}'),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_demographics_title', 'Age and gender distribution'),
              [
                _tx('merchant_analytics_age_line', 'Age: {value}').replaceAll('{value}', _formatCountRows(ageRows)),
                _tx('merchant_analytics_gender_line', 'Gender: {value}').replaceAll('{value}', _formatCountRows(genderRows)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_tx('merchant_analytics_heatmap_title', 'Customer location heatmap'), style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kWhite)),
            const SizedBox(height: 6),
            AnalyticsMapPanel(
              points: heatmapRows,
              emptyLabel: _tx('merchant_analytics_heatmap_empty', 'No customer locations in the current range.'),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_offer_performance_title', 'Offer performance'),
              [
                _tx('merchant_analytics_offer_performance_line_1', 'Current offers {offers} | Top category {topCategory}')
                    .replaceAll('{offers}', '${_intValue(offerPerformance['totalOffers'])}')
                    .replaceAll('{topCategory}', (offerPerformance['topCategory'] ?? '-').toString()),
                _tx('merchant_analytics_offer_performance_line_2', 'Statuses: {statuses}')
                    .replaceAll('{statuses}', _formatCountRows(statusRows)),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_peak_times_title', 'Peak times'),
              [
                _tx('merchant_analytics_peak_times_line_1', 'Peak hour {hour} | Peak day {day}')
                    .replaceAll('{hour}', (peakTimes['peakHour'] ?? '-').toString())
                    .replaceAll('{day}', (peakTimes['peakDay'] ?? '-').toString()),
                _tx('merchant_analytics_peak_times_line_2', 'Hours: {hours}').replaceAll('{hours}', _formatCountRows(hourRows)),
                _tx('merchant_analytics_peak_times_line_3', 'Days: {days}').replaceAll('{days}', _formatCountRows(weekdayRows)),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_group_metrics_title', 'Group metrics'),
              [
                _tx('merchant_analytics_group_metrics_line_1', 'Groups {groups} | Members {members} | Messages {messages}')
                    .replaceAll('{groups}', '${_intValue(groupMetrics['groups'])}')
                    .replaceAll('{members}', '${_intValue(groupMetrics['members'])}')
                    .replaceAll('{messages}', '${_intValue(groupMetrics['messages'])}'),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_top_brand_products_title', 'Top brand products'),
              topProductRows.isEmpty
                  ? <String>[_tx('merchant_analytics_top_brand_products_empty', 'No linked brand product data in this range.')]
                  : topProductRows
                      .map((row) => '${(row['name'] ?? '-').toString()} • ${(row['brandName'] ?? '-').toString()} • ${_money(row['salesTotal'])} • ${_intValue(row['quantity'])}')
                      .toList(growable: false),
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_financial_summary_title', 'Financial summary'),
              [
                _tx('merchant_analytics_financial_summary_line_1', 'Point value {pointValue} | Branches {branches}')
                    .replaceAll('{pointValue}', _money(financialSummary['pointValue']))
                    .replaceAll('{branches}', '${_intValue(financialSummary['branches'])}'),
                _tx('merchant_analytics_financial_summary_line_2', 'Total sales {totalSales} | Avg bill {avgBill}')
                    .replaceAll('{totalSales}', _money(financialSummary['totalSales']))
                    .replaceAll('{avgBill}', _money(financialSummary['averageBill'])),
              ],
            ),
            _buildAnalyticsBlock(
              _tx('merchant_analytics_loyalty_health_title', 'Loyalty health index'),
              [
                _tx('merchant_analytics_loyalty_health_line_1', 'Score {score} | Trend {trend}')
                    .replaceAll('{score}', _numValue(loyaltyHealth['score']))
                    .replaceAll('{trend}', (loyaltyHealth['trend'] ?? 'stable').toString()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(
        color: kMerchantBg,
        child: _buildBody(),
      );
    }
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kMerchantDarkCharcoal),
        title: Text(
          'merchant_dashboard_title'.tr(),
          style: kDisplayTextStyle(size: 18, weight: FontWeight.w800, color: kMerchantDarkCharcoal),
        ),
      ),
      body: _buildBody(),
    );
  }
}
