import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class CustomerGiftsScreen extends StatefulWidget {
  const CustomerGiftsScreen({super.key});

  @override
  State<CustomerGiftsScreen> createState() => _CustomerGiftsScreenState();
}

class _CustomerGiftsScreenState extends State<CustomerGiftsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _assignments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignments = await CompanyServerService.getMyGiftAssignments();
      if (!mounted) return;
      setState(() => _assignments = assignments);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _viewGift(String assignmentId) async {
    await CompanyServerService.markGiftAssignmentViewed(assignmentId).catchError((_) => <String, dynamic>{});
    await _load();
  }

  Future<void> _claimGift(Map<String, dynamic> assignment) async {
    final assignmentId = (assignment['assignmentId'] ?? '').toString();
    if (assignmentId.isEmpty) return;
    try {
      final claim = await CompanyServerService.claimGiftAssignment(assignmentId);
      if (!mounted) return;
      await _showGiftQr(assignment, claim);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('gift_claim_error'.tr())));
    }
  }

  Future<void> _showGiftQr(Map<String, dynamic> assignment, Map<String, dynamic> claim) async {
    final gift = (assignment['gift'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final token = (claim['redemptionToken'] ?? '').toString();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text((gift['title'] ?? 'free_gift'.tr()).toString(), textAlign: TextAlign.center, style: kDisplayTextStyle(size: 20)),
              const SizedBox(height: 8),
              Text('show_qr_cashier_hint'.tr(), textAlign: TextAlign.center, style: kBodyTextStyle(size: 13)),
              const SizedBox(height: 16),
              if (token.isNotEmpty) ...[
                QrImageView(data: token, size: 230),
                const SizedBox(height: 8),
                SelectableText(token, textAlign: TextAlign.center),
              ] else
                Text('coupon_qr_hint'.tr()),
              if ((claim['expiresAt'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('valid_until'.tr(namedArgs: {'date': (claim['expiresAt'] ?? '').toString().split('T').first})),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text('admin_close'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('customer_my_gifts'.tr())),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('free_gifts_title'.tr(), style: kDisplayTextStyle(size: 22, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('free_gifts_subtitle'.tr(), style: kBodyTextStyle(size: 13, color: kInk.withValues(alpha: 0.68))),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                  title: Text('gift_load_error'.tr()),
                  subtitle: Text('stream_load_retry_message'.tr()),
                  trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ),
              )
            else if (_assignments.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.card_giftcard_outlined, color: kTeal),
                  title: Text('no_current_gifts'.tr()),
                  subtitle: Text('no_current_gifts_hint'.tr()),
                ),
              )
            else
              ..._assignments.map(_buildGiftCard),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> assignment) {
    final gift = (assignment['gift'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final assignmentId = (assignment['assignmentId'] ?? '').toString();
    final status = (assignment['status'] ?? '').toString();
    final title = (gift['title'] ?? 'هدية').toString();
    final description = (gift['description'] ?? '').toString();
    final canClaim = status == 'NOTIFIED' || status == 'VIEWED' || status == 'CLAIMED';
    final redeemed = status == 'REDEEMED';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: redeemed ? kLine : kTeal.withValues(alpha: 0.14),
          child: Icon(redeemed ? Icons.check_circle_outline : Icons.card_giftcard_outlined, color: redeemed ? Colors.grey : kTeal),
        ),
        title: Text(title, style: kBodyTextStyle(size: 15, weight: FontWeight.w700)),
        subtitle: Text([
          if (description.isNotEmpty) description,
          'الحالة: $status',
          if ((assignment['expiresAt'] ?? '').toString().isNotEmpty) 'صالحة حتى: ${(assignment['expiresAt'] ?? '').toString().split('T').first}',
        ].join('\n')),
        isThreeLine: true,
        trailing: canClaim
            ? FilledButton(
                onPressed: () async {
                  await _viewGift(assignmentId);
                  await _claimGift(assignment);
                },
                child: const Text('استخدم'),
              )
            : null,
      ),
    );
  }
}