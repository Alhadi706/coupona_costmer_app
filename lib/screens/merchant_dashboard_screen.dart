import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart' as pdf_color;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/company_server_service.dart';
import '../services/export_download.dart';
import '../theme/design_tokens.dart';
import '../widgets/analytics_map_panel.dart';
import '../widgets/reward_funding_card.dart';
import '../widgets/store_digital_identity_card.dart';
import '../features/merchant/rewards/create_reward_wizard_dialog.dart';
import '../features/merchant/rewards/merchant_rewards_screen.dart';
import 'map_picker_screen.dart';
import 'community_screen.dart';
import 'community/community_tab_request.dart';
import 'cashier_dashboard_screen.dart';
import 'merchant_ads_screen.dart';
import 'merchant_team_screen.dart';
import 'login_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'merchant_invoices_screen.dart';
import 'merchant_networks_screen.dart';
import 'merchant_reports_screen.dart';
import 'merchant_gift_trigger.dart';

part 'merchant_dashboard/merchant_dashboard_helpers.dart';
part 'merchant_dashboard/merchant_dashboard_analytics.dart';
part 'merchant_dashboard/merchant_dashboard_overview.dart';
part 'merchant_dashboard/merchant_store_management_forms.dart';
part 'merchant_dashboard/merchant_kpi_cards.dart';

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
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewards = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantRewardClaims = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _merchantProducts = <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};

  void _updateFormState(VoidCallback fn) {
    if (mounted) setState(fn);
  }
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
              CompanyServerService.getMyRoles(),
              CompanyServerService.getMerchantAnalytics(
                range: _analyticsRange,
                branchId: branchId,
              ).catchError((_) => <String, dynamic>{}),
              CompanyServerService.getMerchantProducts().catchError((_) => <Map<String, dynamic>>[]),
            ]);
      if (!mounted) return;
      final rolesIndex = widget.dashboardLoader != null ? 6 : 5;
      final analyticsIndex = widget.dashboardLoader != null ? 7 : 6;
      final productsIndex = widget.dashboardLoader != null ? 9 : 7;
      final profile = Map<String, dynamic>.from(results[3] as Map<dynamic, dynamic>);
      final rawAnalytics = results[analyticsIndex];
      setState(() {
        _branches = List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
        _merchantRewards = widget.dashboardLoader != null && results.length > 5
          ? List<Map<String, dynamic>>.from(results[5] as List<dynamic>)
          : <Map<String, dynamic>>[];
        _merchantRewardClaims = widget.dashboardLoader != null && results.length > 8
          ? List<Map<String, dynamic>>.from(results[8] as List<dynamic>)
          : <Map<String, dynamic>>[];
        _merchantProducts = results.length > productsIndex
          ? List<Map<String, dynamic>>.from(results[productsIndex] as List<dynamic>)
          : <Map<String, dynamic>>[];
        _roles = Map<String, dynamic>.from(results[rolesIndex] as Map<dynamic, dynamic>);
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
    final branchId = _cashierBranchIdController.text.trim();
    final input = _cashierUserIdController.text.trim();

    if (branchId.isEmpty) {
      final msg = _tx('merchant_branch_required', 'الرجاء اختيار أو إدخال الفرع أولاً');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      setState(() {
        _result = msg;
      });
      return;
    }

    if (input.isEmpty) {
      final msg = _tx('cashier_phone_or_id_required', 'الرجاء إدخال رقم هاتف الكاشير أو معرف المستخدم');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      setState(() {
        _result = msg;
      });
      return;
    }

    String? cashierUserId;
    String? cashierPhone;

    final isPhone = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(input) ||
        input.startsWith('09') ||
        input.startsWith('05') ||
        input.startsWith('+');

    if (isPhone) {
      cashierPhone = input;
    } else {
      cashierUserId = input;
    }

    try {
      final data = await CompanyServerService.bindCashierToBranch(
        branchId: branchId,
        cashierUserId: cashierUserId,
        cashierPhone: cashierPhone,
      );
      final successMsg = 'merchant_cashier_bound'.tr(namedArgs: {'id': '${data['id'] ?? ''}'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
      }
      setState(() {
        _result = successMsg;
        _cashierUserIdController.clear();
      });
    } catch (e) {
      String errMsg = e.toString();
      if (e is StateError && e.message == 'cashierUserId_or_cashierPhone_required') {
        errMsg = _tx('cashier_phone_or_id_required', 'الرجاء إدخال رقم هاتف الكاشير أو معرف المستخدم بشكل صحيح');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
      }
      setState(() {
        _result = errMsg;
      });
    }
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
    return MerchantRewardsScreen(
      sourceType: 'merchant',
      rewardFundingLoader: widget.rewardFundingLoader,
      rewardFunder: widget.rewardFunder,
      rewardsLoader: widget.dashboardLoader == null ? null : () async => _merchantRewards,
      claimsLoader: widget.dashboardLoader == null ? null : () async => _merchantRewardClaims,
    );
  }

  Future<void> _showCreateRewardSheet() async {
    await showDialog(
      context: context,
      builder: (context) => CreateRewardWizardDialog(
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
          );
          await _load();
        },
      ),
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
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_bag_outlined, color: kMerchantBrandGreen),
              title: Text('merchant_browse_customer_offers'.tr()),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CommunityScreen(initialTabIndex: CommunityHubTabs.marketplace),
                ),
              ),
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
                    product == null ? 'merchant_product_add_title'.tr() : 'merchant_product_edit_title'.tr(),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: 'merchant_product_name_label'.tr()),
                  ),
                  TextField(
                    controller: price,
                    decoration: InputDecoration(labelText: 'merchant_product_price_label'.tr()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: description,
                    decoration: InputDecoration(labelText: 'merchant_product_desc_label'.tr()),
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
                      title: Text('merchant_product_active'.tr()),
                      subtitle: Text('merchant_product_active_hint'.tr()),
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
                            SnackBar(content: Text('merchant_product_name_required'.tr())),
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

  Future<void> _shareStoreLink(String businessName, String qrData) async {
    await SharePlus.instance.share(
      ShareParams(text: '$businessName\n$qrData'),
    );
  }

  Future<void> _downloadStoreQrPdf(String businessName, String branchName, String qrData) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: pdf_color.PdfPageFormat.a4,
          build: (pw.Context context) => pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(32),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdf_color.PdfColors.teal, width: 3),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    businessName,
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: pdf_color.PdfColors.teal800),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${'merchant_branch'.tr()}: $branchName',
                    style: const pw.TextStyle(fontSize: 18, color: pdf_color.PdfColors.grey800),
                  ),
                  pw.SizedBox(height: 24),
                  pw.BarcodeWidget(data: qrData, barcode: pw.Barcode.qrCode(), width: 220, height: 220),
                  pw.SizedBox(height: 24),
                  pw.Text(
                    'merchant_store_qr_hint'.tr(),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 14, color: pdf_color.PdfColors.grey700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final fileName = 'kupuna-store-qr-${businessName.replaceAll(' ', '_')}.pdf';
      await downloadBytes(bytes: await pdf.save(), fileName: fileName, mimeType: 'application/pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('store_qr_pdf_done'.tr()), backgroundColor: kTeal),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'store_qr_pdf_failed'.tr()}: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleProductActive(Map<String, dynamic> product, bool value) async {
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) return;
    setState(() => product['isActive'] = value);
    try {
      await CompanyServerService.updateMerchantProduct(productId: productId, isActive: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => product['isActive'] = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
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
          StoreDigitalIdentityCard(
            merchantProfile: _merchantProfile,
            readOnly: _merchantReadOnly,
            onSaved: _load,
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: merchantId.isEmpty
                            ? null
                            : () => _downloadStoreQrPdf(
                                  (_merchantProfile['businessName'] ?? 'merchant_name'.tr()).toString(),
                                  branchId.isEmpty ? 'merchant_all_branches'.tr() : '${selectedBranch['name'] ?? ''}',
                                  storeQrData,
                                ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: kTeal),
                        label: Text('store_qr_download_pdf'.tr(), style: const TextStyle(color: kTeal)),
                      ),
                      OutlinedButton.icon(
                        onPressed: merchantId.isEmpty
                            ? null
                            : () => _shareStoreLink(
                                  (_merchantProfile['businessName'] ?? '').toString(),
                                  storeQrData,
                                ),
                        icon: const Icon(Icons.share_outlined, color: kTeal),
                        label: Text('store_share_link'.tr(), style: const TextStyle(color: kTeal)),
                      ),
                    ],
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
            title: 'merchant_store_products'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editMerchantProduct(),
                    icon: const Icon(Icons.add_circle_outline, color: kTeal),
                    label: Text('merchant_product_add_new'.tr(), style: const TextStyle(color: kTeal)),
                  ),
                ),
                if (_merchantProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'merchant_products_empty'.tr(),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 195,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _merchantProducts.length,
                      itemBuilder: (context, index) {
                        final product = _merchantProducts[index];
                        final pName = (product['name'] ?? '').toString();
                        final pImage = (product['imageUrl'] ?? product['image_url'] ?? '').toString();
                        final pPrice = product['price'];
                        final pActive = product['isActive'] != false;

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
                                            '$pPrice ${'currency_lyd'.tr()}',
                                            style: const TextStyle(
                                              color: kTealDark,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                pActive ? 'store_product_on'.tr() : 'store_product_off'.tr(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: pActive ? kTealDark : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              height: 26,
                                              width: 34,
                                              child: Transform.scale(
                                                scale: 0.6,
                                                child: Switch(
                                                  value: pActive,
                                                  onChanged: _merchantReadOnly
                                                      ? null
                                                      : (v) => _toggleProductActive(product, v),
                                                ),
                                              ),
                                            ),
                                          ],
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
          _buildStoreManagementForms(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
            'merchant_quick_actions'.tr(),
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
                    cashierActive ? 'merchant_pos_scan_qr'.tr() : 'merchant_pos_preview'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantGiftTrigger(),
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
                  label: Text(
                    'merchant_reward_add'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CommunityScreen(initialTabIndex: CommunityHubTabs.marketplace),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: kMerchantDarkCharcoal,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: Text(
                    'merchant_browse_customer_offers'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
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
          cashierActive ? 'merchant_pos_status_active'.tr() : 'merchant_pos_status_inactive'.tr(),
          style: kBodyTextStyle(size: 13, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
        ),
        subtitle: Text(
          cashierActive
              ? 'merchant_pos_subtitle_active'.tr()
              : 'merchant_pos_subtitle_inactive'.tr(),
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
            cashierActive ? 'merchant_pos_open'.tr() : 'merchant_pos_activate'.tr(),
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
        title: Text('merchant_pos_dialog_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('merchant_pos_dialog_intro'.tr()),
            const SizedBox(height: 8),
            Text('merchant_pos_dialog_step_1'.tr()),
            Text('merchant_pos_dialog_step_2'.tr()),
            const SizedBox(height: 12),
            TextField(
              controller: _cashierUserIdController,
              decoration: InputDecoration(
                labelText: 'merchant_pos_cashier_id_label'.tr(),
                hintText: 'merchant_pos_cashier_id_hint'.tr(),
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
            child: Text('merchant_pos_confirm_activation'.tr()),
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
                'merchant_analytics_banner_title'.tr(),
                style: kBodyTextStyle(size: 14, weight: FontWeight.w700, color: kMerchantDarkCharcoal),
              ),
              const SizedBox(height: 2),
              Text(
                'merchant_analytics_banner_subtitle'.tr(),
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
            label: Text('merchant_analytics_open'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    title: Text(_tx('merchant_escrow_summary', 'Escrow & settlements summary')),
                    subtitle: Text('${_tx('merchant_escrow_balance', 'Escrow balance')}: ${snapshot.data?['escrowAccount']?['balance'] ?? 0} • ${_tx('merchant_settlements_count', 'Settlements count')}: ${(snapshot.data?['settlements'] as List?)?.length ?? 0}'),
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
