import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

typedef CustomerInvoicesLoader = Future<List<Map<String, dynamic>>> Function({int limit});
typedef CustomerInvoiceDisputeCreator = Future<Map<String, dynamic>> Function({
  required String invoiceId,
  required String reason,
  String? evidence,
});

class CustomerInvoicesScreen extends StatefulWidget {
  final CustomerInvoicesLoader? invoicesLoader;
  final CustomerInvoiceDisputeCreator? disputeCreator;

  const CustomerInvoicesScreen({
    super.key,
    this.invoicesLoader,
    this.disputeCreator,
  });

  @override
  State<CustomerInvoicesScreen> createState() => _CustomerInvoicesScreenState();
}

class _CustomerInvoicesScreenState extends State<CustomerInvoicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _invoices = const <Map<String, dynamic>>[];

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
      final invoices = await (widget.invoicesLoader ?? CompanyServerService.getMyInvoices)(limit: 100);
      if (!mounted) return;
      setState(() => _invoices = invoices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dispute(Map<String, dynamic> invoice) async {
    final invoiceId = (invoice['id'] ?? '').toString();
    if (invoiceId.isEmpty) return;
    var reason = '';
    var evidence = '';
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_tx('customer_invoice_dispute_title', 'Dispute rejected invoice')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                maxLines: 2,
                onChanged: (value) => reason = value,
                decoration: InputDecoration(
                  labelText: _tx('customer_invoice_dispute_reason', 'Reason'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                maxLines: 2,
                onChanged: (value) => evidence = value,
                decoration: InputDecoration(
                  labelText: _tx('customer_invoice_dispute_evidence', 'Additional evidence (optional)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tx('cancel', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (reason.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(_tx('customer_invoice_submit_dispute', 'Submit dispute')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await (widget.disputeCreator ?? CompanyServerService.createInvoiceDispute)(
        invoiceId: invoiceId,
        reason: reason.trim(),
        evidence: evidence.trim(),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_tx('customer_invoice_dispute_failed', 'Unable to submit dispute')}: $error')),
      );
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'uploaded':
        return _tx('status_uploaded', 'Uploaded');
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
      case 'closed_rejected':
        return _tx('status_closed_rejected', 'Dispute denied');
      default:
        return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('customer_invoices_title', 'My invoices'))),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        key: const Key('customer-invoices-load-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: kGold),
            const SizedBox(height: 10),
            Text(_tx('customer_invoices_load_failed', 'Unable to load your invoices.')),
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
        key: const Key('customer-invoices-empty'),
        child: Text(_tx('customer_invoices_empty', 'You have no scanned invoices yet.')),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          final invoiceId = (invoice['id'] ?? '').toString();
          final state = (invoice['state'] ?? '').toString();
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
                          (invoice['merchantName'] ?? _tx('customer_invoice_unknown_store', 'Unknown store')).toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Chip(label: Text(_stateLabel(state))),
                    ],
                  ),
                  Text('${_tx('customer_invoice_number', 'Invoice')}: ${invoice['invoiceNumber'] ?? '-'}'),
                  Text('${_tx('customer_invoice_total', 'Total')}: ${invoice['totalAmount'] ?? '-'} ${invoice['currency'] ?? ''}'),
                  if ((invoice['reviewNote'] ?? '').toString().isNotEmpty)
                    Text('${_tx('customer_invoice_review_note', 'Review note')}: ${invoice['reviewNote']}'),
                  if (state == 'rejected') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: Key('customer-invoice-$invoiceId-dispute'),
                      onPressed: () => _dispute(invoice),
                      icon: const Icon(Icons.gavel_outlined),
                      label: Text(_tx('customer_invoice_dispute_action', 'Dispute decision')),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
