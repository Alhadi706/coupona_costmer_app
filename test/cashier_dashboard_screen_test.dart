import 'package:coupona_app/screens/cashier_dashboard_screen.dart';
import 'package:coupona_app/screens/cashier_dashboard_screen_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cashier dashboard uses cashier mode wrapper surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CashierDashboardScreen(),
      ),
    );

    expect(find.text('⚡ وضع الكاشير'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(const Key('cashier_mode_exit_button')), findsOneWidget);
  });

  testWidgets('cashier dashboard body displays assigned branch badge for single branch', (tester) async {
    final branchController = TextEditingController(text: 'branch-1');
    final amountController = TextEditingController();
    final pickupController = TextEditingController();
    final promoController = TextEditingController();
    final manualCustomerController = TextEditingController();
    final manualReasonController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CashierDashboardBody(
            cashierActive: true,
            loadingGrant: false,
            loadingRedeem: false,
            loadingPromoRedeem: false,
            manualOverrideOpen: false,
            scannedQrTokenExists: false,
            result: null,
            isResultError: false,
            branches: const [
              {'id': 'branch-1', 'name': 'Main Branch'}
            ],
            selectedBranchId: 'branch-1',
            branchIdController: branchController,
            purchaseAmountController: amountController,
            pickupQrCodeController: pickupController,
            promoQrCodeController: promoController,
            manualCustomerIdController: manualCustomerController,
            manualOverrideReasonController: manualReasonController,
            onGrantPoints: () async {},
            onRedeemClaim: () async {},
            onConfirmRedeemClaim: () async {},
            onScanCustomerQr: () async {},
            onScanRewardQr: () async {},
            onScanPromoQr: () async {},
            onConfirmPromoRedemption: () async {},
            onManualOverrideToggled: (_) {},
            onPromoCodeChanged: (_) {},
            tx: (key, fallback) => fallback,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('cashier_assigned_branch_badge')), findsOneWidget);
    expect(find.text('Main Branch (branch-1)'), findsOneWidget);
  });

  testWidgets('cashier dashboard body displays dropdown for multiple branches', (tester) async {
    final branchController = TextEditingController(text: 'branch-1');
    final amountController = TextEditingController();
    final pickupController = TextEditingController();
    final promoController = TextEditingController();
    final manualCustomerController = TextEditingController();
    final manualReasonController = TextEditingController();

    String? selectedBranch;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CashierDashboardBody(
            cashierActive: true,
            loadingGrant: false,
            loadingRedeem: false,
            loadingPromoRedeem: false,
            manualOverrideOpen: false,
            scannedQrTokenExists: false,
            result: null,
            isResultError: false,
            branches: const [
              {'id': 'branch-1', 'name': 'Branch One'},
              {'id': 'branch-2', 'name': 'Branch Two'},
            ],
            selectedBranchId: 'branch-1',
            onBranchSelected: (val) {
              selectedBranch = val;
            },
            branchIdController: branchController,
            purchaseAmountController: amountController,
            pickupQrCodeController: pickupController,
            promoQrCodeController: promoController,
            manualCustomerIdController: manualCustomerController,
            manualOverrideReasonController: manualReasonController,
            onGrantPoints: () async {},
            onRedeemClaim: () async {},
            onConfirmRedeemClaim: () async {},
            onScanCustomerQr: () async {},
            onScanRewardQr: () async {},
            onScanPromoQr: () async {},
            onConfirmPromoRedemption: () async {},
            onManualOverrideToggled: (_) {},
            onPromoCodeChanged: (_) {},
            tx: (key, fallback) => fallback,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('cashier_branch_dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cashier_branch_dropdown')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Branch Two (branch-2)').last);
    await tester.pumpAndSettle();

    expect(selectedBranch, 'branch-2');
  });
}
