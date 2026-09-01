import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/company_server_service.dart';
import '../widgets/design_system/kupuna_cashier_mode_screen_wrapper.dart';

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
      } catch (_) {
        // Non-merchant cashiers are expected to fail this profile lookup.
      }
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
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
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
    if (useManualOverride &&
        (_manualCustomerIdController.text.trim().isEmpty || _manualOverrideReasonController.text.trim().isEmpty)) {
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
        // Reset so a scanned/used token can never be resubmitted from this screen.
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
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
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
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
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
        title: const Text('تأكيد استخدام الكوبون'),
        content: const Text('تحقق من حضور العميل. سيصبح الكوبون مستخدماً ولا يمكن مسحه مرة أخرى.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('تأكيد الاستخدام')),
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
            ? 'تم قبول الكوبون. طبّق خصماً بنسبة ${num.tryParse(discount.toString())?.toStringAsFixed(0) ?? discount}%.'
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

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_cashierActive) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Text(
              _tx('cashier_access_inactive', 'Cashier access is currently inactive because the parent merchant subscription is not writable.'),
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'cashier_grant_points_title',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        const SizedBox(height: 8),
        TextField(
          controller: _branchIdController,
          decoration: InputDecoration(labelText: _tx('cashier_branch_id', 'Branch ID')),
        ),
        TextField(
          controller: _purchaseAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: _tx('cashier_purchase_amount', 'Purchase Amount')),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _scannedQrToken != null ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _scannedQrToken != null ? Colors.green.shade400 : Colors.grey.shade400),
          ),
          child: Row(
            children: [
              Icon(
                _scannedQrToken != null ? Icons.check_circle : Icons.qr_code_scanner,
                color: _scannedQrToken != null ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _scannedQrToken != null
                      ? _tx('cashier_qr_scanned', 'Customer QR scanned successfully.')
                      : _tx('cashier_scan_prompt', "Scan the customer's QR code to identify them."),
                ),
              ),
              TextButton(
                onPressed: _scanCustomerQr,
                child: Text(_scannedQrToken != null
                    ? _tx('cashier_rescan', 'Rescan')
                    : _tx('cashier_scan_action', 'Scan')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (open) => setState(() => _manualOverrideOpen = open),
          title: Text(_tx('cashier_manual_override_title', 'Manual entry (camera unavailable)')),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _tx('cashier_manual_override_warning', 'Manual entries are logged and flagged for merchant/admin review.'),
                style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
              ),
            ),
            TextField(
              controller: _manualCustomerIdController,
              decoration: InputDecoration(labelText: _tx('cashier_customer_user_id', 'Customer User ID')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _manualOverrideReasonController,
              decoration: InputDecoration(labelText: _tx('cashier_manual_override_reason', 'Reason (required)')),
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (!_cashierActive || _loadingGrant) ? null : _grantPoints,
          child: Text(_loadingGrant
              ? _tx('cashier_sending', 'Sending...')
              : _tx('cashier_grant_points_action', 'Grant points')),
        ),
        const Divider(height: 32),
        const Text(
          'cashier_redeem_claim_title',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        const SizedBox(height: 8),
        TextField(
          controller: _pickupQrCodeController,
          decoration: InputDecoration(labelText: _tx('cashier_pickup_qr_code', 'Pickup QR Code')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (!_cashierActive || _loadingRedeem) ? null : _scanRewardQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(_tx('cashier_scan_reward_qr', 'Scan reward QR')),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (!_cashierActive || _loadingRedeem) ? null : _confirmRedeemClaim,
          child: Text(_loadingRedeem
              ? _tx('cashier_redeeming', 'Redeeming...')
              : _tx('cashier_redeem_claim_action', 'Redeem claim')),
        ),
        const Divider(height: 32),
        const Text('مسح كوبون ترويجي', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('امسح كوبون الخصم أو الهدية من هاتف العميل للتحقق من صلاحيته واستخدامه.'),
        const SizedBox(height: 10),
        TextField(
          controller: _promoQrCodeController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'رمز الكوبون الترويجي',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_activity_outlined),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: (!_cashierActive || _loadingPromoRedeem) ? null : _scanPromoQr,
            icon: _loadingPromoRedeem
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner),
            label: Text(_loadingPromoRedeem ? 'جارٍ التحقق...' : 'مسح كوبون ترويجي'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: (!_cashierActive || _loadingPromoRedeem || _promoQrCodeController.text.trim().isEmpty)
              ? null
              : _confirmPromoRedemption,
          child: const Text('التحقق من الرمز المكتوب'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Text(
            _result!,
            style: TextStyle(color: _isResultError ? Colors.red : Colors.green),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }
    return KupunaCashierModeScreenWrapper(
      storeName: _tx('cashier_dashboard_title', 'Cashier Dashboard'),
      onGrantPoints: _grantPoints,
      onRedeemReward: _redeemClaim,
      body: _buildBody(),
    );
  }
}

/// Full-screen live camera QR scanner. Pops with the raw decoded text of the
/// first barcode detected, or null if the cashier cancels.
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('cashier_scan_customer_qr_title', 'Scan customer QR'))),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
