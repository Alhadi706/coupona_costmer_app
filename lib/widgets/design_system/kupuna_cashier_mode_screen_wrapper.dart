import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/design_tokens.dart';

class KupunaCashierModeScreenWrapper extends StatelessWidget {
  final String storeName;
  final VoidCallback onGrantPoints;
  final VoidCallback onRedeemReward;
  final Widget? body;

  const KupunaCashierModeScreenWrapper({
    super.key,
    required this.storeName,
    required this.onGrantPoints,
    required this.onRedeemReward,
    this.body,
  });

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kViolet,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(kPaddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kTopTabPaddingHorizontal,
                    vertical: kTopTabPaddingVertical,
                  ),
                  decoration: BoxDecoration(
                    color: kWhite.withValues(alpha: kCashierBadgeAlpha),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                  child: Text(
                    _tx('cashier_mode_badge', '⚡ وضع الكاشير'),
                    style: kBodyTextStyle(
                      size: 12,
                      weight: FontWeight.w600,
                      color: kWhite,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: kGapList),
              Text(
                storeName,
                textAlign: TextAlign.center,
                style: kDisplayTextStyle(
                  size: kCashierModeTitleSize,
                  weight: FontWeight.w700,
                  color: kWhite,
                ),
              ),
              const SizedBox(height: kGapList),
              if (body != null)
                Expanded(child: body!)
              else
                Expanded(
                  child: Center(
                    child: Container(
                      width: kCashierScanBoxSize,
                      height: kCashierScanBoxSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kCashierScanRadius),
                        border: Border.all(
                          color: kWhite.withValues(alpha: 0.75),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: kWhite.withValues(alpha: 0.9),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: _tx('cashier_grant_points_action', 'منح نقاط'),
                      onTap: onGrantPoints,
                    ),
                  ),
                  const SizedBox(width: kGapTight),
                  Expanded(
                    child: _ActionButton(
                      label: _tx('cashier_redeem_claim_action', 'تسليم مكافأة'),
                      onTap: onRedeemReward,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite.withValues(alpha: kCashierButtonAlpha),
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: kPaddingCardCompact,
            horizontal: kPaddingCardCompact,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: kBodyTextStyle(
              size: 13,
              weight: FontWeight.w600,
              color: kWhite,
            ),
          ),
        ),
      ),
    );
  }
}
