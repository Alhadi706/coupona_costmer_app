part of 'package:coupona_app/screens/my_rewards_screen.dart';

extension _MyRewardsCouponUi on _MyRewardsScreenState {
  void _showCouponDialog({
    required String rewardName,
    required String rewardKind,
    required String pickupQrCode,
    required String digitalCode,
    required String status,
    required String expiresAt,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  rewardName.isEmpty ? 'reward_generic'.tr() : rewardName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_formatClaimStatus(status), style: const TextStyle(color: kTeal)),
                const SizedBox(height: 16),
                if (rewardKind == 'physical' && pickupQrCode.isNotEmpty) ...[
                  QrImageView(data: pickupQrCode, size: 220),
                  const SizedBox(height: 10),
                  Text('coupon_qr_hint'.tr(), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SelectableText(pickupQrCode),
                ] else if (digitalCode.isNotEmpty) ...[
                  Text('coupon_digital_code_label'.tr()),
                  const SizedBox(height: 8),
                  SelectableText(digitalCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTeal)),
                ],
                if (expiresAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('coupon_expires_at'.tr(namedArgs: {'value': expiresAt.split('T').first})),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                    label: Text('close'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
