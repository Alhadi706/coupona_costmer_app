import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';

typedef PublicCoalitionRequestLoader = Future<Map<String, dynamic>?> Function(String applicantType);
typedef PublicCoalitionRequestAction = Future<Map<String, dynamic>> Function(String applicantType);

class PublicCoalitionMembershipScreen extends StatefulWidget {
  final String applicantType;
  final PublicCoalitionRequestLoader? requestLoader;
  final PublicCoalitionRequestAction? requestAction;

  const PublicCoalitionMembershipScreen({
    super.key,
    required this.applicantType,
    this.requestLoader,
    this.requestAction,
  });

  @override
  State<PublicCoalitionMembershipScreen> createState() => _PublicCoalitionMembershipScreenState();
}

class _PublicCoalitionMembershipScreenState extends State<PublicCoalitionMembershipScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicCoalitionMembershipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicantType != widget.applicantType) {
      _request = null;
      _load();
    }
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await (widget.requestLoader ??
          (type) => CompanyServerService.getPublicCoalitionMembershipRequest(applicantType: type))(widget.applicantType);
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final request = await (widget.requestAction ??
          (type) => CompanyServerService.requestPublicCoalitionMembership(applicantType: type))(widget.applicantType);
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openPayment(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme) ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('public_coalition_payment_open_failed', 'Could not open the payment link.'))),
      );
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending_admin_review' => _tx('public_coalition_status_pending', 'Pending admin review'),
      'approved_pending_payment' => _tx('public_coalition_status_payment', 'Approved - payment required'),
      'active' => _tx('public_coalition_status_active', 'Active'),
      'rejected' => _tx('public_coalition_status_rejected', 'Rejected'),
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('public_coalition_membership_title', 'Public coalition membership'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.public, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      _tx('public_coalition_membership_description', 'Apply to join Coupona public network. Activation requires admin approval and payment confirmation.'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(_tx('public_coalition_load_failed', 'Unable to load your application.')),
                  trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ),
              )
            else
              _buildRequestState(),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestState() {
    final request = _request;
    if (request == null || request['status'] == 'rejected' || request['status'] == 'cancelled') {
      final rejectionReason = request?['rejectionReason']?.toString() ?? '';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rejectionReason.isNotEmpty) ...[
                Text(_statusLabel('rejected'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(rejectionReason),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                key: const Key('public-coalition-submit-request'),
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send_outlined),
                label: Text(_submitting
                    ? _tx('public_coalition_submitting', 'Submitting...')
                    : _tx('public_coalition_submit', 'Submit membership application')),
              ),
            ],
          ),
        ),
      );
    }

    final status = request['status']?.toString() ?? '';
    final adminMessage = request['adminMessage']?.toString() ?? '';
    final paymentUrl = request['paymentUrl']?.toString() ?? '';
    return Card(
      key: Key('public-coalition-status-$status'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_statusLabel(status), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (adminMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_tx('public_coalition_admin_message', 'Private message from administration')),
              const SizedBox(height: 4),
              SelectableText(adminMessage),
            ],
            if (status == 'approved_pending_payment' && paymentUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('public-coalition-open-payment'),
                onPressed: () => _openPayment(paymentUrl),
                icon: const Icon(Icons.open_in_new),
                label: Text(_tx('public_coalition_open_payment', 'Open secure payment page')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}