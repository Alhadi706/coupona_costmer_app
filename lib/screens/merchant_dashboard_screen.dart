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
import 'map_picker_screen.dart';
import 'add_coupon_screen.dart';
import 'community_screen.dart';
import 'cashier_dashboard_screen.dart';
import 'points_conversion_screen.dart';
import 'reward_qr_code_screen.dart';
import 'login_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  final bool embedded;

  const MerchantDashboardScreen({super.key, this.embedded = false});

  const MerchantDashboardScreen.embedded({super.key}) : embedded = true;

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
  final TextEditingController _pointValueController = TextEditingController();

  bool _canReviewInvoices = false;
  bool _canCreateOffers = false;
  bool _canManageGroup = false;
  bool _canViewReports = false;
  bool _canViewSettlements = false;
  bool _canAddCashiers = false;
  bool _canReplyReports = false;
  bool _canEditPointValue = false;

  bool _loading = true;
  bool _savingPointValue = false;
  String? _error;
  bool _sessionExpired = false;
  String? _result;
  double? _branchLatitude;
  double? _branchLongitude;
  String _analyticsRange = '30d';
  int _merchantTabIndex = 0;
  String _analyticsBranchId = '';
  double? _currentPointValue;
  bool _loadingAnalytics = false;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invoices = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewards = <Map<String, dynamic>>[];
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
    _pointValueController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessionExpired = false;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        CompanyServerService.getMerchantBranches(),
        CompanyServerService.getMerchantLoyaltyHealth(),
        CompanyServerService.getMyInvoices(limit: 20),
        CompanyServerService.getMerchantProfile(),
        CompanyServerService.getOffers(),
        CompanyServerService.getMerchantRewards(),
        CompanyServerService.getMyRoles(),
        CompanyServerService.getMerchantAnalytics(
          range: _analyticsRange,
          branchId: _analyticsBranchId.isEmpty ? null : _analyticsBranchId,
        ).catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(results[3] as Map<dynamic, dynamic>);
      final pointValueRaw = profile['pointValue'];
      final pointValue = pointValueRaw == null ? null : double.tryParse(pointValueRaw.toString());
      final rawAnalytics = results[7];
      setState(() {
        _branches = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _loyalty = Map<String, dynamic>.from(results[1] as Map<dynamic, dynamic>);
        _invoices = List<Map<String, dynamic>>.from(results[2] as List<dynamic>);
        _offers = List<Map<String, dynamic>>.from(results[4] as List<dynamic>);
        _merchantRewards = List<Map<String, dynamic>>.from(results[5] as List<dynamic>);
        _roles = Map<String, dynamic>.from(results[6] as Map<dynamic, dynamic>);
        _merchantProfile = profile;
        _analytics = rawAnalytics is Map ? Map<String, dynamic>.from(rawAnalytics as Map<dynamic, dynamic>) : const <String, dynamic>{};
        _currentPointValue = pointValue;
        _pointValueController.text = pointValue == null ? '' : pointValue.toString();
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
      final data = await CompanyServerService.getMerchantAnalytics(
        range: _analyticsRange,
        branchId: _analyticsBranchId.isEmpty ? null : _analyticsBranchId,
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
    final subscriptions = (_roles['subscriptions'] as List?) ?? const <dynamic>[];
    for (final row in subscriptions) {
      if (row is Map && row['roleType'] == 'merchant') {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }

  bool get _merchantReadOnly => (_merchantSubscription()?['status'] ?? '').toString() == 'suspended';

  bool get _merchantGracePeriod => (_merchantSubscription()?['status'] ?? '').toString() == 'grace_period';

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
        color: _merchantReadOnly ? kGold.withValues(alpha: 0.18) : kTeal.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: _merchantReadOnly ? kGold : kTeal, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kWhite)),
          const SizedBox(height: 4),
          Text(body, style: kBodyTextStyle(size: 12, weight: FontWeight.w500, color: kWhite.withValues(alpha: 0.92))),
          const SizedBox(height: 4),
          Text(
            '${_tx('role_subscription_status', 'Subscription status: {status}').replaceAll('{status}', label)}${nextBillingDate.isNotEmpty ? ' • $nextBillingDate' : ''}',
            style: kBodyTextStyle(size: 11, weight: FontWeight.w500, color: kWhite.withValues(alpha: 0.85)),
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
        color: kIndigoLight,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kLineDark, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: kDisplayTextStyle(
              size: 15,
              weight: FontWeight.w700,
              color: kWhite,
            ),
          ),
          const SizedBox(height: kGapTight),
          child,
        ],
      ),
    );
  }

  Future<void> _savePointValue() async {
    final pointValue = double.tryParse(_pointValueController.text.trim());
    if (pointValue == null || pointValue <= 0) {
      setState(() {
        _result = 'merchant_point_value_invalid'.tr();
      });
      return;
    }

    setState(() {
      _savingPointValue = true;
      _result = null;
    });

    try {
      final data = await CompanyServerService.setMerchantPointValue(pointValue: pointValue);
      final updated = double.tryParse((data['pointValue'] ?? pointValue).toString()) ?? pointValue;
      if (!mounted) return;
      setState(() {
        _currentPointValue = updated;
        _pointValueController.text = updated.toString();
        _result = 'merchant_point_value_saved'.tr(namedArgs: {'value': updated.toString()});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingPointValue = false;
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
        canEditPointValue: _canEditPointValue,
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
          _mutableSection(
            ExpansionTile(
              title: Text('merchant_set_point_value'.tr()),
              subtitle: Text('merchant_current_value'.tr(namedArgs: {'value': _currentPointValue?.toString() ?? '-'})),
              childrenPadding: const EdgeInsets.all(12),
              children: [
                TextField(
                  controller: _pointValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'merchant_point_value_label'.tr(),
                    helperText: 'merchant_point_value_helper'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _savingPointValue ? null : _savePointValue,
                  child: Text(_savingPointValue ? 'merchant_saving'.tr() : 'merchant_save_point_value'.tr()),
                ),
              ],
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
                value: () {
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
              SwitchListTile(
                value: _canEditPointValue,
                title: Text('merchant_can_edit_point_value'.tr()),
                onChanged: (value) => setState(() => _canEditPointValue = value),
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
        ],
      ),
    );
  }

  Future<void> _showCreateRewardSheet() async {
    final name = TextEditingController();
    final points = TextEditingController();
    final description = TextEditingController();
    final imageUrl = TextEditingController();
    final quantity = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('merchant_create_reward'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextField(controller: name, decoration: InputDecoration(labelText: 'reward_name'.tr())),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'reward_points_required'.tr())),
                TextField(controller: description, decoration: InputDecoration(labelText: 'reward_description_optional'.tr())),
                TextField(controller: imageUrl, decoration: InputDecoration(labelText: 'reward_image_url_optional'.tr())),
                TextField(controller: quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'reward_quantity_optional'.tr())),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    final value = int.tryParse(points.text.trim());
                    final max = int.tryParse(quantity.text.trim());
                    if (name.text.trim().isEmpty || value == null || value <= 0) return;
                    await CompanyServerService.createMerchantReward(
                      rewardName: name.text.trim(), points: value, description: description.text.trim(), imageUrl: imageUrl.text.trim(), quantityLimit: max,
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    await _load();
                  },
                  child: Text('save'.tr()),
                )),
              ],
            ),
          ),
        ),
      );
    } finally {
      name.dispose(); points.dispose(); description.dispose(); imageUrl.dispose(); quantity.dispose();
    }
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: kIndigo, child: Icon(Icons.campaign_outlined, size: 52, color: kGold)),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text('merchant_ads_preview'.tr(), style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined, color: kTeal),
              title: Text('billboard_create_ad'.tr()),
              subtitle: Text('billboard_create_ad_hint'.tr()),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddCouponScreen())),
            ),
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'merchant_campaigns'.tr(),
            child: Column(
              children: _offers.where((offer) => (offer['imageUrl'] ?? offer['image'] ?? '').toString().isNotEmpty).take(8).map((offer) {
                final status = (offer['lifecycleStatus'] ?? 'pending_review').toString();
                final statusColor = status == 'active' ? Colors.green : (status == 'expired' ? Colors.grey : kGold);
                return ListTile(
                  leading: const Icon(Icons.image_outlined, color: kTeal),
                  title: Text((offer['description'] ?? 'offer'.tr()).toString()),
                  subtitle: Text('${'merchant_campaign_status'.tr()}: $status | ${'merchant_campaign_metrics'.tr(namedArgs: {'impressions': '${offer['impressions'] ?? 0}', 'clicks': '${offer['clicks'] ?? 0}'})}'),
                  trailing: Icon(Icons.circle, size: 12, color: statusColor),
                );
              }).toList(growable: false),
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
              children: _branches.map((branch) => ListTile(
                leading: Icon(
                  Icons.store_outlined,
                  color: (branch['id'] ?? '').toString() == (selectedBranch['id'] ?? '').toString() ? kTeal : null,
                ),
                title: Text((branch['name'] ?? 'merchant_unnamed_branch'.tr()).toString()),
                subtitle: Text('${branch['address'] ?? ''}${(branch['workingHours'] ?? '').toString().isEmpty ? '' : ' | ${branch['workingHours']}'}'),
                trailing: IconButton(
                  tooltip: 'merchant_edit_branch'.tr(),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editBranch(branch),
                ),
                onTap: () => setState(() => _analyticsBranchId = (branch['id'] ?? '').toString()),
              )).toList(growable: false),
            ),
          ),
          const SizedBox(height: 12),
          _buildIndigoSection(
            title: 'merchant_bind_cashier'.tr(),
            child: Column(
              children: [
                TextField(controller: _cashierBranchIdController, decoration: InputDecoration(labelText: 'merchant_branch_id'.tr())),
                TextField(controller: _cashierUserIdController, decoration: InputDecoration(labelText: 'merchant_cashier_user_id'.tr())),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _bindCashier, child: Text('merchant_bind_cashier_action'.tr())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
    final tabs = <Widget>[
      _buildScannerTab(),
      _buildRewardsTab(),
      _buildAdsTab(),
      _buildCommunityTab(),
      _buildStoreTab(),
    ];
    return Column(
      children: [
        Expanded(child: tabs[_merchantTabIndex]),
        NavigationBar(
          selectedIndex: _merchantTabIndex,
          onDestinationSelected: (index) => setState(() => _merchantTabIndex = index),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.qr_code_scanner), label: 'merchant_nav_scanner'.tr()),
            NavigationDestination(icon: const Icon(Icons.card_giftcard_outlined), label: 'merchant_nav_rewards'.tr()),
            NavigationDestination(icon: const Icon(Icons.campaign_outlined), label: 'merchant_nav_ads'.tr()),
            NavigationDestination(icon: const Icon(Icons.groups_outlined), label: 'merchant_nav_community'.tr()),
            NavigationDestination(icon: const Icon(Icons.store_outlined), label: 'merchant_nav_store'.tr()),
          ],
        ),
      ],
    );
  }

  Widget _buildScannerTab() {
    final sales = _mapSection('sales');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(child: _statCard('merchant_today_redemptions'.tr(), _intValue(sales['redemptions']))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('merchant_points_spent'.tr(), _intValue(sales['pointsSpent']))),
            ],
          ),
        ),
        Expanded(child: CashierDashboardScreen.embedded()),
      ],
    );
  }

  Widget _statCard(String label, int value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: kBodyTextStyle(size: 11, color: kInk.withValues(alpha: 0.65))),
            const SizedBox(height: 4),
            Text('$value', style: kPointsNumberStyle(size: 22, color: kTeal)),
          ],
        ),
      ),
    );
  }

  Future<void> _editBranch(Map<String, dynamic> branch) async {
    final name = TextEditingController(text: '${branch['name'] ?? ''}');
    final address = TextEditingController(text: '${branch['address'] ?? ''}');
    final hours = TextEditingController(text: '${branch['workingHours'] ?? ''}');
    final phone = TextEditingController(text: '${branch['phone'] ?? ''}');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('merchant_edit_branch'.tr(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              TextField(controller: name, decoration: InputDecoration(labelText: 'merchant_name'.tr())),
              TextField(controller: address, decoration: InputDecoration(labelText: 'merchant_address'.tr())),
              TextField(controller: hours, decoration: InputDecoration(labelText: 'merchant_working_hours'.tr())),
              TextField(controller: phone, decoration: InputDecoration(labelText: 'merchant_phone'.tr())),
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
      );
    } finally {
      name.dispose();
      address.dispose();
      hours.dispose();
      phone.dispose();
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
              DropdownButton<String>(
                value: _analyticsBranchId.isEmpty ? '__all__' : _analyticsBranchId,
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '__all__', child: Text('merchant_all_branches'.tr())),
                  ..._branches.map(
                    (b) => DropdownMenuItem(
                      value: (b['id'] ?? '').toString(),
                      child: Text((b['name'] ?? '').toString()),
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

  Widget _buildAnalyticsBlock(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kIndigo.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(kRadiusCardCompact),
        border: Border.all(color: kLineDark, width: kBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kWhite)),
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: kBodyTextStyle(size: 12, weight: FontWeight.w500, color: kWhite.withValues(alpha: 0.92))),
            ),
          ),
        ],
      ),
    );
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
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _listSectionDirect(String key) {
    final raw = _analytics[key];
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>)).toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String _formatCountRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '-';
    return rows.map((row) => '${(row['label'] ?? '-').toString()}: ${_intValue(row['value'])}').join(' | ');
  }

  String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

  String _numValue(dynamic value) => _toDouble(value).toStringAsFixed(2);

  int _intValue(dynamic value) => int.tryParse('${value ?? 0}') ?? _toDouble(value).round();

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
          pw.Text('Range: $_analyticsRange | Branch: ${_analyticsBranchId.isEmpty ? 'All' : _analyticsBranchId}'),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Sales: ${_money(sales['total'])}'),
          pw.Bullet(text: 'Invoices: ${_intValue(sales['invoiceCount'])}'),
          pw.Bullet(text: 'Points awarded: ${_intValue(sales['pointsAwarded'])}'),
          pw.Bullet(text: 'Unique customers: ${_intValue(customers['unique'])}'),
          pw.Bullet(text: 'New customers: ${_intValue(customers['newCount'])}'),
          pw.Bullet(text: 'Returning customers: ${_intValue(customers['returningCount'])}'),
          pw.Bullet(text: 'Retention: ${_numValue(customers['retentionPercent'])}%'),
          pw.Bullet(text: 'Churn: ${_numValue(customers['churnPercent'])}%'),
          pw.Bullet(text: 'Loyalty health: ${_numValue(loyaltyHealth['score'])} (${(loyaltyHealth['trend'] ?? 'stable').toString()})'),
          pw.Bullet(text: 'Point value: ${_money(financialSummary['pointValue'])}'),
          pw.SizedBox(height: 12),
          pw.Text('Top Brand Products'),
          ...topProducts.take(8).map((row) => pw.Bullet(text: '${(row['name'] ?? '-').toString()} | ${(row['brandName'] ?? '-').toString()} | ${_money(row['salesTotal'])}')),
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
      ..writeln('sales,invoices,${_intValue(_mapSection('sales')['invoiceCount'])}')
      ..writeln('sales,points_awarded,${_intValue(_mapSection('sales')['pointsAwarded'])}')
      ..writeln('customers,unique,${_intValue(_mapSection('customers')['unique'])}')
      ..writeln('customers,new,${_intValue(_mapSection('customers')['newCount'])}')
      ..writeln('customers,returning,${_intValue(_mapSection('customers')['returningCount'])}')
      ..writeln('customers,retention_percent,${_numValue(_mapSection('customers')['retentionPercent'])}')
      ..writeln('customers,churn_percent,${_numValue(_mapSection('customers')['churnPercent'])}');
    for (final row in _listSectionDirect('topBrandProducts')) {
      buffer.writeln('top_brand_products,${(row['name'] ?? '-').toString()},${_money(row['salesTotal'])}');
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
      SnackBar(content: Text(ok ? '$format download started' : '$format export is only supported in web builds.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return Scaffold(
      backgroundColor: kIndigo,
      appBar: AppBar(title: Text('merchant_dashboard_title'.tr())),
      body: _buildBody(),
    );
  }
}
