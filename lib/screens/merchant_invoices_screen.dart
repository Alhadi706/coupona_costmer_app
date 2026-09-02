import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

typedef MerchantInvoicesLoader = Future<Map<String, dynamic>> Function({
  required String state,
  int limit,
});
typedef MerchantInvoiceTransition = Future<Map<String, dynamic>> Function({
  required String invoiceId,
  required String to,
  String? note,
});

class MerchantInvoicesScreen extends StatefulWidget {
  final MerchantInvoicesLoader? invoicesLoader;
  final MerchantInvoiceTransition? invoiceTransition;

  const MerchantInvoicesScreen({
    super.key,
    this.invoicesLoader,
    this.invoiceTransition,
  });

  @override
  State<MerchantInvoicesScreen> createState() => _MerchantInvoicesScreenState();
}

class _MerchantInvoicesScreenState extends State<MerchantInvoicesScreen> {
  String _stateFilter = 'all';
  bool _loading = true;
  String? _error;
  String _reviewerRole = '';
  List<Map<String, dynamic>> _invoices = const <Map<String, dynamic>>[];
  final Set<String> _updatingInvoiceIds = <String>{};

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

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
      final result = await (widget.invoicesLoader ?? CompanyServerService.getMerchantInvoices)(
        state: _stateFilter,
        limit: 100,
      );
      if (!mounted) return;
      final rawInvoices = result['invoices'] as List? ?? const <dynamic>[];
      setState(() {
        _reviewerRole = (result['reviewerRole'] ?? '').toString();
        _invoices = rawInvoices
            .whereType<Map>()
            .map((invoice) => Map<String, dynamic>.from(invoice))
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(Map<String, dynamic> invoice, String to) async {
    final invoiceId = (invoice['id'] ?? '').toString();
    if (invoiceId.isEmpty || _updatingInvoiceIds.contains(invoiceId)) return;

    final noteController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_actionLabel(to)),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _tx('merchant_invoice_review_note', 'Review note'),
              helperText: to == 'rejected'
                  ? _tx('merchant_invoice_rejection_note_required', 'A rejection reason is required.')
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tx('cancel', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (to == 'rejected' && noteController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(_tx('confirm', 'Confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _updatingInvoiceIds.add(invoiceId));
      await (widget.invoiceTransition ?? CompanyServerService.transitionInvoiceState)(
        invoiceId: invoiceId,
        to: to,
        note: noteController.text,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tx('merchant_invoice_update_failed', 'Unable to update invoice')}: $error')),
      );
    } finally {
      noteController.dispose();
      if (mounted) setState(() => _updatingInvoiceIds.remove(invoiceId));
    }
  }

  String _actionLabel(String state) {
    switch (state) {
      case 'approved':
        return _tx('merchant_invoice_approve', 'Approve');
      case 'rejected':
        return _tx('merchant_invoice_reject', 'Reject');
      case 'manual_review':
        return _tx('merchant_invoice_manual_review', 'Manual review');
      default:
        return state;
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'processing':
        return _tx('status_processing', 'Processing');
      case 'manual_review':
        return _tx('status_manual_review', 'Manual review');
      case 'approved':
        return _tx('status_approved', 'Approved');
      case 'rejected':
        return _tx('status_rejected', 'Rejected');
      case 'disputed':
        return _tx('status_disputed', 'Disputed');
      default:
        return state;
    }
  }

  List<String> _availableActions(String state) {
    if (state == 'processing') return const <String>['approved', 'rejected', 'manual_review'];
    if (state == 'manual_review') return const <String>['approved', 'rejected'];
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('merchant_invoices_title', 'Store invoices'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stateFilter,
                    decoration: InputDecoration(labelText: _tx('merchant_invoice_state_filter', 'Invoice state')),
                    items: <String>['all', 'processing', 'manual_review', 'approved', 'rejected', 'disputed']
                        .map((state) => DropdownMenuItem(
                              value: state,
                              child: Text(state == 'all' ? _tx('all', 'All') : _stateLabel(state)),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null || value == _stateFilter) return;
                      setState(() => _stateFilter = value);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: _tx('retry', 'Retry'),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_reviewerRole.isNotEmpty && !_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _reviewerRole == 'manager'
                      ? _tx('merchant_invoice_manager_scope', 'Showing assigned branches only')
                      : _tx('merchant_invoice_owner_scope', 'Showing all store branches'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        key: const Key('merchant-invoices-load-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: kGold),
            const SizedBox(height: 10),
            Text(_tx('merchant_invoices_load_failed', 'Unable to load store invoices.')),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(_tx('retry', 'Retry')),
            ),
          ],
        ),
      );
    }
    if (_invoices.isEmpty) {
      return Center(
        key: const Key('merchant-invoices-empty'),
        child: Text(_tx('merchant_invoices_empty', 'No invoices match this filter.')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildInvoiceCard(_invoices[index]),
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final state = (invoice['state'] ?? '').toString();
    final invoiceId = (invoice['id'] ?? '').toString();
    final updating = _updatingInvoiceIds.contains(invoiceId);
    final actions = _availableActions(state);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (invoice['invoiceNumber'] ?? _tx('merchant_invoice_without_number', 'Invoice without number')).toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(label: Text(_stateLabel(state))),
              ],
            ),
            Text('${_tx('merchant_invoice_customer', 'Customer')}: ${invoice['ownerLabel'] ?? '-'}'),
            Text('${_tx('merchant_invoice_branch', 'Branch')}: ${invoice['branchName'] ?? '-'}'),
            Text('${_tx('merchant_invoice_total', 'Total')}: ${invoice['totalAmount'] ?? '-'} ${invoice['currency'] ?? ''}'),
            if ((invoice['reviewNote'] ?? '').toString().isNotEmpty)
              Text('${_tx('merchant_invoice_review_note', 'Review note')}: ${invoice['reviewNote']}'),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions
                    .map((action) => OutlinedButton(
                          key: Key('invoice-$invoiceId-$action'),
                          onPressed: updating ? null : () => _transition(invoice, action),
                          child: Text(_actionLabel(action)),
                        ))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}