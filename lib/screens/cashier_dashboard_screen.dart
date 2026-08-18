import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _purchaseAmountController = TextEditingController();
  final TextEditingController _pickupQrCodeController = TextEditingController();

  String? _result;
  bool _loadingGrant = false;
  bool _loadingRedeem = false;
  bool _cashierActive = true;

  @override
  void initState() {
    super.initState();
    _loadCashierState();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
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
    _customerIdController.dispose();
    _purchaseAmountController.dispose();
    _pickupQrCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCashierState() async {
    try {
      final roles = await CompanyServerService.getMyRoles();
      final cashierRows = (roles['cashier'] as List?) ?? const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _cashierActive = cashierRows.any((row) => row is Map && row['isActive'] == true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cashierActive = false;
      });
    }
  }

  Future<void> _grantPoints() async {
    final amount = double.tryParse(_purchaseAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _result = _tx('cashier_enter_valid_purchase_amount', 'Please enter a valid purchase amount.');
      });
      return;
    }

    setState(() {
      _loadingGrant = true;
    });
    try {
      final result = await CompanyServerService.grantCashierPoints(
        branchId: _branchIdController.text.trim(),
        customerId: _customerIdController.text.trim(),
        purchaseAmount: amount,
      );
      setState(() {
        final template = _tx('cashier_grant_result', 'Granted points: {points}, fraction: {fraction}');
        _result = template
            .replaceAll('{points}', '${result['points'] ?? 0}')
            .replaceAll('{fraction}', '${result['fraction'] ?? 0}');
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
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
      });
    } catch (e) {
      setState(() {
        _result = e.toString();
      });
    } finally {
      setState(() {
        _loadingRedeem = false;
      });
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
          controller: _customerIdController,
          decoration: InputDecoration(labelText: _tx('cashier_customer_user_id', 'Customer User ID')),
        ),
        TextField(
          controller: _purchaseAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: _tx('cashier_purchase_amount', 'Purchase Amount')),
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
        ElevatedButton(
          onPressed: (!_cashierActive || _loadingRedeem) ? null : _redeemClaim,
          child: Text(_loadingRedeem
              ? _tx('cashier_redeeming', 'Redeeming...')
              : _tx('cashier_redeem_claim_action', 'Redeem claim')),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Text(
            _result!,
            style: const TextStyle(color: Colors.green),
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
