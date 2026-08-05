import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../modules/coupon_lifecycle/coupon_lifecycle_rules.dart';
import '../modules/coupon_lifecycle/models/coupon_lifecycle_record.dart';
import '../modules/coupon_lifecycle/services/coupon_lifecycle_service.dart';

class CouponLifecycleScreen extends StatefulWidget {
  const CouponLifecycleScreen({super.key});

  @override
  State<CouponLifecycleScreen> createState() => _CouponLifecycleScreenState();
}

class _CouponLifecycleScreenState extends State<CouponLifecycleScreen> {
  final CouponLifecycleService _service = CouponLifecycleService();
  final TextEditingController _offerIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;
  String? _selectedOfferId;

  String _statusLabel(CouponLifecycleStatus status) {
    switch (status) {
      case CouponLifecycleStatus.draft:
        return 'lifecycle_draft'.tr();
      case CouponLifecycleStatus.pendingReview:
        return 'lifecycle_pending_review'.tr();
      case CouponLifecycleStatus.approved:
        return 'lifecycle_approved'.tr();
      case CouponLifecycleStatus.rejected:
        return 'lifecycle_rejected'.tr();
      case CouponLifecycleStatus.active:
        return 'lifecycle_active'.tr();
      case CouponLifecycleStatus.redeemed:
        return 'lifecycle_redeemed'.tr();
      case CouponLifecycleStatus.expired:
        return 'lifecycle_expired'.tr();
      case CouponLifecycleStatus.archived:
        return 'lifecycle_archived'.tr();
    }
  }

  @override
  void dispose() {
    _offerIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _bindOffer() async {
    final String offerId = _offerIdController.text.trim();
    if (offerId.isEmpty) {
      _showError('offer_id_required'.tr());
      return;
    }

    setState(() {
      _selectedOfferId = offerId;
    });

    try {
      await _service.ensureLifecycleDefaults(offerId);
      await _service.syncTemporalStatus(offerId);
      if (!mounted) return;
      _showInfo('lifecycle_load_success'.tr());
    } catch (error) {
      _showError('lifecycle_bind_error'.tr(namedArgs: {'error': error.toString()}));
    }
  }

  Future<void> _moveTo(CouponLifecycleStatus status) async {
    final String? offerId = _selectedOfferId;
    if (offerId == null || offerId.isEmpty) {
      _showError('bind_offer_first'.tr());
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _service.transitionOffer(
        offerId: offerId,
        targetStatus: status,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (!mounted) return;
      _showInfo('lifecycle_changed_to'.tr(namedArgs: {'status': _statusLabel(status)}));
    } catch (error) {
      _showError('lifecycle_change_error'.tr(namedArgs: {'error': error.toString()}));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _statusChip(CouponLifecycleRecord record) {
    final String label = _statusLabel(record.status);
    return Chip(
      label: Text(label),
      backgroundColor: Colors.deepPurple.shade50,
      side: BorderSide(color: Colors.deepPurple.shade200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('coupon_lifecycle_title'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: <Widget>[
            TextField(
              controller: _offerIdController,
              decoration: InputDecoration(
                labelText: 'offer_id_label'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _bindOffer,
                    icon: const Icon(Icons.link),
                    label: Text('bind_offer'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'lifecycle_reason_optional'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedOfferId != null)
              StreamBuilder<CouponLifecycleRecord?>(
                stream: _service.watchOfferLifecycle(_selectedOfferId!),
                builder: (context, snapshot) {
                  final CouponLifecycleRecord? record = snapshot.data;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('offer_value'.tr(namedArgs: {'value': _selectedOfferId!})),
                          const SizedBox(height: 8),
                          if (record != null) _statusChip(record),
                          if (record != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text('last_updated_value'.tr(namedArgs: {'value': record.updatedAt.toIso8601String()})),
                            if (record.lastReason != null)
                              Text('reason_value'.tr(namedArgs: {'value': record.lastReason!})),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _statusButton('send_for_review'.tr(), CouponLifecycleStatus.pendingReview),
                _statusButton('approve'.tr(), CouponLifecycleStatus.approved),
                _statusButton('reject'.tr(), CouponLifecycleStatus.rejected),
                _statusButton('activate'.tr(), CouponLifecycleStatus.active),
                _statusButton('confirm_redemption'.tr(), CouponLifecycleStatus.redeemed),
                _statusButton('expire'.tr(), CouponLifecycleStatus.expired),
                _statusButton('archive'.tr(), CouponLifecycleStatus.archived),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'lifecycle_note'.tr(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(String text, CouponLifecycleStatus status) {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : () => _moveTo(status),
      child: Text(text),
    );
  }
}
