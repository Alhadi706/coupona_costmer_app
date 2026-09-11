import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';

/// Bottom-sheet modal that confirms and executes a reward redemption.
///
/// Shows the reward image, title, required points and the customer's
/// current balance. Validates that the balance covers the cost, then
/// calls `POST /api/customer/rewards/claim` and displays the generated
/// coupon code + QR for the merchant to scan.
class ClaimRewardModal extends StatefulWidget {
  final Map<String, dynamic> reward;
  final int userPoints;
  final Future<void> Function()? onClaimed;

  const ClaimRewardModal({
    super.key,
    required this.reward,
    required this.userPoints,
    this.onClaimed,
  });

  @override
  State<ClaimRewardModal> createState() => _ClaimRewardModalState();
}

class _ClaimRewardModalState extends State<ClaimRewardModal> {
  static const _kTeal = Color(0xFF0A5C43);

  bool _claiming = false;
  bool _claimed = false;
  String _couponCode = '';
  String? _error;

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _requiredPoints =>
      _asInt(widget.reward['value'] ?? widget.reward['pointsCost']);

  bool get _hasEnoughPoints =>
      _requiredPoints > 0 && widget.userPoints >= _requiredPoints;

  Future<void> _confirmClaim() async {
    if (_claiming || !_hasEnoughPoints) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      final claim = await CompanyServerService.claimReward(
        rewardId: (widget.reward['id'] ?? '').toString(),
      );
      if (!mounted) return;
      final code = (claim['couponCode'] ??
              claim['digitalCode'] ??
              claim['code'] ??
              claim['pickupQrCode'] ??
              '')
          .toString();
      setState(() {
        _claimed = true;
        _couponCode = code;
      });
      await widget.onClaimed?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر استبدال الجائزة: $e');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _claimed ? _buildSuccessView() : _buildConfirmView(),
      ),
    );
  }

  Widget _buildConfirmView() {
    final imageUrl = (widget.reward['imageUrl'] ?? '').toString();
    final rewardName =
        (widget.reward['reward_name'] ?? widget.reward['title'] ?? 'جائزة')
            .toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.card_giftcard,
                          color: _kTeal,
                          size: 48,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.card_giftcard,
                        color: _kTeal,
                        size: 48,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          rewardName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildPointsRow('النقاط المطلوبة', '🪙 $_requiredPoints نقطة'),
        const SizedBox(height: 8),
        _buildPointsRow('رصيدك الحالي', '🪙 ${widget.userPoints} نقطة'),
        if (!_hasEnoughPoints) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رصيدك الحالي لا يكفي لاستبدال هذه الجائزة',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed:
                (_claiming || !_hasEnoughPoints) ? null : _confirmClaim,
            style: FilledButton.styleFrom(
              backgroundColor: _kTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _claiming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _claiming ? 'جاري الاستبدال...' : 'تأكيد استبدال الجائزة',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointsRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 56),
        const SizedBox(height: 10),
        const Text(
          'تم استبدال الجائزة بنجاح!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_couponCode.isNotEmpty) ...[
          Center(child: QrImageView(data: _couponCode, size: 200)),
          const SizedBox(height: 10),
          const Text(
            'أظهر هذا الرمز للتاجر لمسحه واستلام جائزتك',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Center(
            child: SelectableText(
              _couponCode,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kTeal,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: _kTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.close),
            label: const Text('إغلاق'),
          ),
        ),
      ],
    );
  }
}
