import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

typedef AdminPublicCoalitionRequestsLoader =
    Future<List<Map<String, dynamic>>> Function(String status);
typedef AdminPublicCoalitionApproveAction =
    Future<Map<String, dynamic>> Function(
      String requestId, {
      required String adminMessage,
      String? paymentUrl,
    });
typedef AdminPublicCoalitionRejectAction =
    Future<Map<String, dynamic>> Function(
      String requestId, {
      required String reason,
    });
typedef AdminPublicCoalitionActivateAction =
    Future<Map<String, dynamic>> Function(
      String requestId, {
      required String paymentReference,
    });

class AdminPublicCoalitionRequestsScreen extends StatefulWidget {
  final bool embedded;
  final AdminPublicCoalitionRequestsLoader? requestsLoader;
  final AdminPublicCoalitionApproveAction? approveAction;
  final AdminPublicCoalitionRejectAction? rejectAction;
  final AdminPublicCoalitionActivateAction? activateAction;

  const AdminPublicCoalitionRequestsScreen({
    super.key,
    this.embedded = false,
    this.requestsLoader,
    this.approveAction,
    this.rejectAction,
    this.activateAction,
  });

  @override
  State<AdminPublicCoalitionRequestsScreen> createState() =>
      _AdminPublicCoalitionRequestsScreenState();
}

class _AdminPublicCoalitionRequestsScreenState
    extends State<AdminPublicCoalitionRequestsScreen> {
  bool _loading = true;
  String? _error;
  String _status = 'pending_admin_review';
  List<Map<String, dynamic>> _requests = const [];
  final Set<String> _pendingRequestIds = <String>{};

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
      final rows =
          await (widget.requestsLoader ??
              (status) =>
                  CompanyServerService.getAdminPublicCoalitionMembershipRequests(
                    status: status,
                  ))(_status);
      if (mounted) setState(() => _requests = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _runRequestAction(
    String requestId,
    Future<void> Function() action,
  ) async {
    if (_pendingRequestIds.contains(requestId)) return;
    setState(() => _pendingRequestIds.add(requestId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx('admin_action_completed', 'Action completed successfully.'),
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx(
              'admin_action_failed',
              'Could not complete this action. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pendingRequestIds.remove(requestId));
    }
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    String message = '';
    String paymentUrl = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('public_coalition_admin_approve'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => message = value,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'public_coalition_admin_message'.tr(),
              ),
            ),
            TextField(
              onChanged: (value) => paymentUrl = value,
              decoration: InputDecoration(
                labelText: 'public_coalition_payment_url'.tr(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('public_coalition_send_payment_message'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || message.trim().isEmpty) return;
    final requestId = request['id'].toString();
    await _runRequestAction(requestId, () async {
      await (widget.approveAction ??
          CompanyServerService.approvePublicCoalitionMembershipRequest)(
        requestId,
        adminMessage: message.trim(),
        paymentUrl: paymentUrl.trim(),
      );
    });
  }

  Future<void> _activate(Map<String, dynamic> request) async {
    String reference = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('public_coalition_admin_activate'.tr()),
        content: TextField(
          onChanged: (value) => reference = value,
          decoration: InputDecoration(
            labelText: 'public_coalition_payment_reference'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('public_coalition_confirm_activation'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || reference.trim().isEmpty) return;
    final requestId = request['id'].toString();
    await _runRequestAction(requestId, () async {
      await (widget.activateAction ??
          CompanyServerService.activatePublicCoalitionMembershipRequest)(
        requestId,
        paymentReference: reference.trim(),
      );
    });
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('public_coalition_admin_reject'.tr()),
        content: TextField(
          onChanged: (value) => reason = value,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'public_coalition_rejection_reason'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('reject'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || reason.trim().isEmpty) return;
    final requestId = request['id'].toString();
    await _runRequestAction(requestId, () async {
      await (widget.rejectAction ??
          CompanyServerService.rejectPublicCoalitionMembershipRequest)(
        requestId,
        reason: reason.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            items: [
              DropdownMenuItem(
                value: 'pending_admin_review',
                child: Text('public_coalition_status_pending'.tr()),
              ),
              DropdownMenuItem(
                value: 'approved_pending_payment',
                child: Text('public_coalition_status_payment'.tr()),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text('public_coalition_status_active'.tr()),
              ),
              DropdownMenuItem(
                value: 'rejected',
                child: Text('public_coalition_status_rejected'.tr()),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                _status = value;
                _load();
              }
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tx(
                          'admin_load_failed',
                          'Could not load this section.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(_tx('retry', 'Retry')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      final status = request['status']?.toString() ?? '';
                      final requestId = request['id']?.toString() ?? '';
                      final actionPending = _pendingRequestIds.contains(
                        requestId,
                      );
                      return Card(
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: ListTile(
                          title: Text(
                            request['applicantName']?.toString() ??
                                request['applicantEmail']?.toString() ??
                                '-',
                          ),
                          subtitle: Text(
                            '${request['applicantType']} • $status',
                          ),
                          trailing: actionPending
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : status == 'pending_admin_review'
                              ? PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'approve') _approve(request);
                                    if (action == 'reject') _reject(request);
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'approve',
                                      child: Text('approve'.tr()),
                                    ),
                                    PopupMenuItem(
                                      value: 'reject',
                                      child: Text('reject'.tr()),
                                    ),
                                  ],
                                )
                              : status == 'approved_pending_payment'
                              ? FilledButton(
                                  onPressed: () => _activate(request),
                                  child: Text(
                                    'public_coalition_admin_activate'.tr(),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text('public_coalition_admin_title'.tr())),
      body: body,
    );
  }
}
