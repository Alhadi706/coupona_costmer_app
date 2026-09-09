import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CashierDashboardBody extends StatelessWidget {
  final bool cashierActive;
  final bool loadingGrant;
  final bool loadingRedeem;
  final bool loadingPromoRedeem;
  final bool manualOverrideOpen;
  final bool scannedQrTokenExists;
  final String? result;
  final bool isResultError;
  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId;
  final ValueChanged<String>? onBranchSelected;
  final VoidCallback? onExit;
  final TextEditingController branchIdController;
  final TextEditingController purchaseAmountController;
  final TextEditingController pickupQrCodeController;
  final TextEditingController promoQrCodeController;
  final TextEditingController manualCustomerIdController;
  final TextEditingController manualOverrideReasonController;
  final Future<void> Function() onGrantPoints;
  final Future<void> Function() onRedeemClaim;
  final Future<void> Function() onConfirmRedeemClaim;
  final Future<void> Function() onScanCustomerQr;
  final Future<void> Function() onScanRewardQr;
  final Future<void> Function() onScanPromoQr;
  final Future<void> Function() onConfirmPromoRedemption;
  final ValueChanged<bool> onManualOverrideToggled;
  final ValueChanged<String> onPromoCodeChanged;
  final String Function(String key, String fallback) tx;

  const CashierDashboardBody({
    super.key,
    required this.cashierActive,
    required this.loadingGrant,
    required this.loadingRedeem,
    required this.loadingPromoRedeem,
    required this.manualOverrideOpen,
    required this.scannedQrTokenExists,
    required this.result,
    required this.isResultError,
    this.branches = const [],
    this.selectedBranchId,
    this.onBranchSelected,
    this.onExit,
    required this.branchIdController,
    required this.purchaseAmountController,
    required this.pickupQrCodeController,
    required this.promoQrCodeController,
    required this.manualCustomerIdController,
    required this.manualOverrideReasonController,
    required this.onGrantPoints,
    required this.onRedeemClaim,
    required this.onConfirmRedeemClaim,
    required this.onScanCustomerQr,
    required this.onScanRewardQr,
    required this.onScanPromoQr,
    required this.onConfirmPromoRedemption,
    required this.onManualOverrideToggled,
    required this.onPromoCodeChanged,
    required this.tx,
  });

  Widget _buildBranchSelector(BuildContext context) {
    if (branches.length == 1) {
      final b = branches.first;
      final name = (b['name'] ?? b['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      return Container(
        key: const Key('cashier_assigned_branch_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront, color: Colors.blue.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx('cashier_assigned_branch_label', 'الفرع المعيّن'),
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.isNotEmpty && name != bId ? '$name ($bId)' : bId,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (branches.length > 1) {
      final currentSelected = branches.any((b) => b['id'] == selectedBranchId)
          ? selectedBranchId
          : branches.first['id']?.toString();

      return DropdownButtonFormField<String>(
        key: const Key('cashier_branch_dropdown'),
        initialValue: currentSelected,
        decoration: InputDecoration(
          labelText: tx('cashier_select_branch', 'اختر الفرع'),
          prefixIcon: const Icon(Icons.storefront),
          border: const OutlineInputBorder(),
        ),
        items: branches.map((branch) {
          final idStr = (branch['id'] ?? '').toString();
          final nameStr = (branch['name'] ?? idStr).toString();
          return DropdownMenuItem<String>(
            value: idStr,
            child: Text(nameStr != idStr ? '$nameStr ($idStr)' : idStr),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null && onBranchSelected != null) {
            onBranchSelected!(val);
          }
        },
      );
    }

    return TextField(
      controller: branchIdController,
      decoration: InputDecoration(labelText: tx('cashier_branch_id', 'Branch ID')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (onExit != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('cashier_body_exit_button'),
              onPressed: onExit,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(tx('exit_cashier_mode', 'خروج من وضع الكاشير')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!cashierActive) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Text(
              tx('cashier_access_inactive', 'Cashier access is currently inactive because the parent merchant subscription is not writable.'),
              style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          tx('cashier_grant_points_title', 'Grant points'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildBranchSelector(context),
        const SizedBox(height: 8),
        TextField(
          controller: purchaseAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tx('cashier_purchase_amount', 'Purchase Amount')),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scannedQrTokenExists ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scannedQrTokenExists ? Colors.green.shade400 : Colors.grey.shade400),
          ),
          child: Row(
            children: [
              Icon(
                scannedQrTokenExists ? Icons.check_circle : Icons.qr_code_scanner,
                color: scannedQrTokenExists ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scannedQrTokenExists
                      ? tx('cashier_qr_scanned', 'Customer QR scanned successfully.')
                      : tx('cashier_scan_prompt', "Scan the customer's QR code to identify them."),
                ),
              ),
              TextButton(
                onPressed: onScanCustomerQr,
                child: Text(scannedQrTokenExists ? tx('cashier_rescan', 'Rescan') : tx('cashier_scan_action', 'Scan')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: onManualOverrideToggled,
          title: Text(tx('cashier_manual_override_title', 'Manual entry (camera unavailable)')),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tx('cashier_manual_override_warning', 'Manual entries are logged and flagged for merchant/admin review.'),
                style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
              ),
            ),
            TextField(
              controller: manualCustomerIdController,
              decoration: InputDecoration(labelText: tx('cashier_customer_user_id', 'Customer User ID')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: manualOverrideReasonController,
              decoration: InputDecoration(labelText: tx('cashier_manual_override_reason', 'Reason (required)')),
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (!cashierActive || loadingGrant) ? null : onGrantPoints,
          child: Text(loadingGrant ? tx('cashier_sending', 'Sending...') : tx('cashier_grant_points_action', 'Grant points')),
        ),
        const Divider(height: 32),
        Text(
          tx('cashier_redeem_claim_title', 'Redeem claim'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pickupQrCodeController,
          decoration: InputDecoration(labelText: tx('cashier_pickup_qr_code', 'Pickup QR Code')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (!cashierActive || loadingRedeem) ? null : onScanRewardQr,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(tx('cashier_scan_reward_qr', 'Scan reward QR')),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (!cashierActive || loadingRedeem) ? null : onConfirmRedeemClaim,
          child: Text(loadingRedeem ? tx('cashier_redeeming', 'Redeeming...') : tx('cashier_redeem_claim_action', 'Redeem claim')),
        ),
        const Divider(height: 32),
        const Text('مسح كوبون ترويجي', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('امسح كوبون الخصم أو الهدية من هاتف العميل للتحقق من صلاحيته واستخدامه.'),
        const SizedBox(height: 10),
        TextField(
          controller: promoQrCodeController,
          onChanged: onPromoCodeChanged,
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
            onPressed: (!cashierActive || loadingPromoRedeem) ? null : onScanPromoQr,
            icon: loadingPromoRedeem
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code_scanner),
            label: Text(loadingPromoRedeem ? 'جارٍ التحقق...' : 'مسح كوبون ترويجي'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: (!cashierActive || loadingPromoRedeem || promoQrCodeController.text.trim().isEmpty)
              ? null
              : onConfirmPromoRedemption,
          child: const Text('التحقق من الرمز المكتوب'),
        ),
        if (result != null) ...[
          const SizedBox(height: 12),
          Text(
            result!,
            style: TextStyle(color: isResultError ? Colors.red : Colors.green),
          ),
        ],
      ],
    );
  }
}

class CashierQrScannerScreen extends StatefulWidget {
  const CashierQrScannerScreen({super.key});

  @override
  State<CashierQrScannerScreen> createState() => _CashierQrScannerScreenState();
}

class _CashierQrScannerScreenState extends State<CashierQrScannerScreen> {
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
