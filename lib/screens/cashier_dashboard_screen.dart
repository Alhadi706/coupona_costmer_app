import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../widgets/design_system/kupuna_cashier_mode_screen_wrapper.dart';
import 'cashier_dashboard_screen_widgets.dart';

class CashierDashboardScreen extends StatefulWidget {
  final bool embedded;

  const CashierDashboardScreen({super.key, this.embedded = false});

  const CashierDashboardScreen.embedded({super.key}) : embedded = true;

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  final TextEditingController _branchIdController = TextEditingController();
  final TextEditingController _purchaseAmountController = TextEditingController();
  final TextEditingController _pickupQrCodeController = TextEditingController();
  final TextEditingController _promoQrCodeController = TextEditingController();
  final TextEditingController _manualCustomerIdController = TextEditingController();
  final TextEditingController _manualOverrideReasonController = TextEditingController();

  String? _result;
  bool _isResultError = false;
  bool _loadingGrant = false;
  bool _loadingRedeem = false;
  bool _loadingPromoRedeem = false;
  bool _cashierActive = true;
  String? _scannedQrToken;
  bool _manualOverrideOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCashierState();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  String _localizeGrantError(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains('qr_token_already_used')) {
      return _tx('cashier_qr_already_used', 'This code has already been used.');
    }
    if (normalized.contains('qr_token_expired')) {
      return _tx('cashier_qr_expired', 'This code has expired. Ask the customer to refresh their QR.');
    }
    if (normalized.contains('qr_token_invalid')) {
      return _tx('cashier_qr_invalid', 'This code is invalid.');
    }
    if (normalized.contains('qr_token_or_manual_override_required')) {
      return _tx('cashier_scan_or_manual_required', 'Scan a customer QR code, or use manual entry below.');
    }
    if (normalized.contains('manual_override_reason_required')) {
      return _tx('cashier_manual_reason_required', 'Please enter the customer ID and a reason for manual entry.');
    }
    if (normalized.contains('daily_invoice_limit_reached')) {
      return _tx('cashier_daily_limit_reached', 'Daily limit reached for this customer.');
    }
    if (normalized.contains('cashier_not_authorized')) {
      return _tx('cashier_not_authorized_error', 'You are not an authorized cashier for this branch.');
    }
    if (normalized.contains('coupon_already_used')) {
      return 'تم استخدام هذا الكوبون مسبقاً.';
    }
    if (normalized.contains('coupon_expired')) {
      return 'انتهت صلاحية هذا الكوبون.';
    }
    if (normalized.contains('coupon_not_valid_for_this_store')) {
      return 'هذا الكوبون غير صالح في هذا المتجر.';
    }
    if (normalized.contains('coupon_not_found')) {
      return 'رمز الكوبون غير معروف.';
    }
    return raw;
  }

  String _localizeStatus(dynamic rawStatus) {
    final String status = (rawStatus ?? '').toString().trim().toLowerCase();
    switch (status) {
      case 'approved':
        return _tx('status_approved', 'Approved');
      case 'pending_admin_review':
        return _tx('status_pending_admin_review', 'Pending admin review');
      case 'pending_review':
        return _tx('status_pending_review', 'Pending review');
      case 'trial':
        return _tx('status_trial', 'Trial');
      case 'grace_period':
        return _tx('status_grace_period', 'Grace period');
      case 'suspended':
        return _tx('status_suspended', 'Suspended');
      case 'redeemed':
        return _tx('status_redeemed', 'Redeemed');
      case 'active':
        return _tx('status_active', 'Active');
      case '':
        return _tx('status_unknown', 'Unknown');
      default:
        return _tx('status_unknown', 'Unknown');
    }
  }

  @override
  void dispose() {
    _branchIdController.dispose();
    _purchaseAmountController.dispose();
    _pickupQrCodeController.dispose();
    _promoQrCodeController.dispose();
    _manualCustomerIdController.dispose();
    _manualOverrideReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadCashierState() async {
    try {
      final roles = await CompanyServerService.getMyRoles();
      final cashierRows = (roles['cashier'] as List?) ?? const <dynamic>[];
      var merchantActive = false;
      try {
        await CompanyServerService.getMerchantProfile();
        merchantActive = true;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _cashierActive = merchantActive || cashierRows.any((row) => row is Map && row['isActive'] == true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cashierActive = false;
      });
    }
  }

  Future<void> _scanCustomerQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CashierQrScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty) return;
    setState(() {
      _scannedQrToken = scanned;
      _manualOverrideOpen = false;
    });
  }

  Future<void> _grantPoints() async {
    final branchId = _branchIdController.text.trim();
    final amount = double.tryParse(_purchaseAmountController.text.trim());
    if (branchId.isEmpty) {
      setState(() {
        _result = _tx('cashier_enter_branch_id', 'Please enter a branch ID.');
        _isResultError = true;
      });
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() {
        _result = _tx('cashier_enter_valid_purchase_amount', 'Please enter a valid purchase amount.');
        _isResultError = true;
      });
      return;
    }
    final useManualOverride = _scannedQrToken == null && _manualOverrideOpen;
    if (_scannedQrToken == null && !_manualOverrideOpen) {
      setState(() {
        _result = _tx('cashier_scan_or_manual_required', 'Scan a customer QR code, or use manual entry below.');
        _isResultError = true;
      });
      return;
    }
    if (useManualOverride && (_manualCustomerIdController.text.trim().isEmpty || _manualOverrideReasonController.text.trim().isEmpty)) {
      setState(() {
        _result = _tx('cashier_manual_reason_required', 'Please enter the customer ID and a reason for manual entry.');
        _isResultError = true;
      });
      return;
    }

    setState(() {
      _loadingGrant = true;
      _isResultError = false;
    });
    try {
      final result = await CompanyServerService.grantCashierPoints(
        branchId: branchId,
        purchaseAmount: amount,
        qrToken: _scannedQrToken,
        manualOverride: useManualOverride,
        manualCustomerId: useManualOverride ? _manualCustomerIdController.text.trim() : null,
        manualOverrideReason: useManualOverride ? _manualOverrideReasonController.text.trim() : null,
      );
      setState(() {
        final template = _tx('cashier_grant_result', 'Granted points: {points}, fraction: {fraction}');
        _result = template
            .replaceAll('{points}', '${result['points'] ?? 0}')
            .replaceAll('{fraction}', '${result['fraction'] ?? 0}');
        _isResultError = false;
        _scannedQrToken = null;
        _manualOverrideOpen = false;
        _manualCustomerIdController.clear();
        _manualOverrideReasonController.clear();
        _purchaseAmountController.clear();
      });
    } catch (e) {
      setState(() {
        _result = _localizeGrantError(e.toString());
        _isResultError = true;
      });
    } finally {
      setState(() {
        _loadingGrant = false;
      });
    }
  }

  Future<void> _redeemClaim() async {
    setState(() {
      _loadingRedeem = true;
    });
    try {
      final result = await CompanyServerService.redeemRewardClaim(
        pickupQrCode: _pickupQrCodeController.text.trim(),
      );
      setState(() {
        final template = _tx('cashier_redeem_result', 'Claim redeemed. Status: {status}');
        _result = template.replaceAll('{status}', _localizeStatus(result['status'] ?? 'redeemed'));
        _isResultError = false;
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
        _isResultError = true;
      });
    } finally {
      setState(() {
        _loadingRedeem = false;
      });
    }
  }

  Future<void> _scanRewardQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CashierQrScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    setState(() => _pickupQrCodeController.text = scanned);
    await _confirmRedeemClaim();
  }

  Future<void> _confirmRedeemClaim() async {
    if (_pickupQrCodeController.text.trim().isEmpty || _loadingRedeem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tx('cashier_confirm_redemption_title', 'Confirm reward handover')),
        content: Text(_tx('cashier_confirm_redemption_body', 'Confirm that the customer is present and the reward will be handed over.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(_tx('cancel', 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(_tx('cashier_confirm_redemption', 'Confirm and hand over'))),
        ],
      ),
    );
    if (confirmed == true) await _redeemClaim();
  }

  Future<void> _scanPromoQr() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CashierQrScannerScreen()),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    setState(() => _promoQrCodeController.text = scanned);
    await _confirmPromoRedemption();
  }

  Future<void> _confirmPromoRedemption() async {
    final qrCode = _promoQrCodeController.text.trim();
    if (qrCode.isEmpty || _loadingPromoRedeem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tx('confirm_coupon_usage_title', 'Confirm Coupon Usage')),
        content: Text(_tx('confirm_coupon_usage_message', 'Verify customer presence. This coupon will become used and cannot be scanned again.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(_tx('cancel', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(_tx('confirm_usage', 'Confirm Usage'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loadingPromoRedeem = true;
      _isResultError = false;
    });
    try {
      final response = await CompanyServerService.redeemCampaignCoupon(qrCode: qrCode);
      if (!mounted) return;
      final campaignType = (response['campaignType'] ?? '').toString();
      final discount = response['discountPercentage'];
      final gift = (response['giftDescription'] ?? '').toString();
      setState(() {
        _result = campaignType == 'early_access_discount'
            ? 'تم قبول الكوبون. طبّق خصماً بنسبة ${num.tryParse(discount.toString())?.toStringAsFixed(0) ?? discount}%. '
            : 'تم قبول كوبون الهدية${gift.isEmpty ? '.' : ': $gift'}';
        _isResultError = false;
        _promoQrCodeController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = _localizeGrantError(error.toString());
        _isResultError = true;
      });
    } finally {
      if (mounted) setState(() => _loadingPromoRedeem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return CashierDashboardBody(
        cashierActive: _cashierActive,
        loadingGrant: _loadingGrant,
        loadingRedeem: _loadingRedeem,
        loadingPromoRedeem: _loadingPromoRedeem,
        manualOverrideOpen: _manualOverrideOpen,
        scannedQrTokenExists: _scannedQrToken != null,
        result: _result,
        isResultError: _isResultError,
        branchIdController: _branchIdController,
        purchaseAmountController: _purchaseAmountController,
        pickupQrCodeController: _pickupQrCodeController,
        promoQrCodeController: _promoQrCodeController,
        manualCustomerIdController: _manualCustomerIdController,
        manualOverrideReasonController: _manualOverrideReasonController,
        onGrantPoints: _grantPoints,
        onRedeemClaim: _redeemClaim,
        onConfirmRedeemClaim: _confirmRedeemClaim,
        onScanCustomerQr: _scanCustomerQr,
        onScanRewardQr: _scanRewardQr,
        onScanPromoQr: _scanPromoQr,
        onConfirmPromoRedemption: _confirmPromoRedemption,
        onManualOverrideToggled: (open) => setState(() => _manualOverrideOpen = open),
        onPromoCodeChanged: (_) => setState(() {}),
        tx: _tx,
      );
    }

    return KupunaCashierModeScreenWrapper(
      storeName: _tx('cashier_dashboard_title', 'Cashier Dashboard'),
      onGrantPoints: _grantPoints,
      onRedeemReward: _redeemClaim,
      body: CashierDashboardBody(
        cashierActive: _cashierActive,
        loadingGrant: _loadingGrant,
        loadingRedeem: _loadingRedeem,
        loadingPromoRedeem: _loadingPromoRedeem,
        manualOverrideOpen: _manualOverrideOpen,
        scannedQrTokenExists: _scannedQrToken != null,
        result: _result,
        isResultError: _isResultError,
        branchIdController: _branchIdController,
        purchaseAmountController: _purchaseAmountController,
        pickupQrCodeController: _pickupQrCodeController,
        promoQrCodeController: _promoQrCodeController,
        manualCustomerIdController: _manualCustomerIdController,
        manualOverrideReasonController: _manualOverrideReasonController,
        onGrantPoints: _grantPoints,
        onRedeemClaim: _redeemClaim,
        onConfirmRedeemClaim: _confirmRedeemClaim,
        onScanCustomerQr: _scanCustomerQr,
        onScanRewardQr: _scanRewardQr,
        onScanPromoQr: _scanPromoQr,
        onConfirmPromoRedemption: _confirmPromoRedemption,
        onManualOverrideToggled: (open) => setState(() => _manualOverrideOpen = open),
        onPromoCodeChanged: (_) => setState(() {}),
        tx: _tx,
      ),
    );
  }
}
