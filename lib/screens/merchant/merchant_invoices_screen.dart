import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/customer_profile.dart';
import '../../models/invoice.dart';
import '../../services/firestore/customer_repository.dart';
import '../../services/firestore/invoice_repository.dart';

class MerchantInvoicesScreen extends StatefulWidget {
  final String merchantId;
  const MerchantInvoicesScreen({super.key, required this.merchantId});

  @override
  State<MerchantInvoicesScreen> createState() => _MerchantInvoicesScreenState();
}

class _MerchantInvoicesScreenState extends State<MerchantInvoicesScreen> {
  late final InvoiceRepository _invoiceRepository;
  late final CustomerRepository _customerRepository;
  final Map<String, CustomerProfile> _customerCache = {};
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _customerRepository = CustomerRepository();
    _invoiceRepository = InvoiceRepository(customerRepository: _customerRepository);
  }

  void _showInvoiceDetails(Invoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _InvoiceDetailsSheet(invoice: invoice),
    );
  }

  Future<void> _updateStatus(Invoice invoice, String status) async {
    await _invoiceRepository.updateInvoiceStatus(invoiceId: invoice.id, status: status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('merchant_invoices_status_updated'.tr())),
    );
  }

  Future<Map<String, CustomerProfile>> _ensureCustomerProfiles(List<Invoice> invoices) async {
    final ids = invoices.map((invoice) => invoice.customerId).where((id) => id.isNotEmpty).toSet();
    final missing = ids.where((id) => !_customerCache.containsKey(id)).toList();
    if (missing.isEmpty) {
      return _customerCache;
    }

    final fetched = await Future.wait(missing.map((id) async {
      final profile = await _customerRepository.fetchCustomer(id);
      return MapEntry(id, profile);
    }));

    for (final entry in fetched) {
      final profile = entry.value;
      if (profile != null) {
        _customerCache[entry.key] = profile;
      }
    }

    return _customerCache;
  }

  String _customerDisplayName(String customerId, Map<String, CustomerProfile> cache) {
    final profile = cache[customerId];
    if (profile == null || profile.name.trim().isEmpty) {
      return customerId;
    }
    return profile.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_invoices_title'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'all', label: Text('merchant_invoices_filter_all'.tr())),
                ButtonSegment(value: 'pending', label: Text('merchant_invoices_filter_pending'.tr())),
                ButtonSegment(value: 'approved', label: Text('merchant_invoices_filter_approved'.tr())),
                ButtonSegment(value: 'rejected', label: Text('merchant_invoices_filter_rejected'.tr())),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (value) => setState(() => _statusFilter = value.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Invoice>>(
              stream: _invoiceRepository.watchInvoices(widget.merchantId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('merchant_invoices_error'.tr()));
                }
                var invoices = snapshot.data ?? const [];
                if (_statusFilter != 'all') {
                  invoices = invoices.where((invoice) => invoice.status == _statusFilter).toList();
                }
                if (invoices.isEmpty) {
                  return Center(child: Text('merchant_invoices_empty'.tr()));
                }
                return FutureBuilder<Map<String, CustomerProfile>>(
                  future: _ensureCustomerProfiles(invoices),
                  builder: (context, customerSnapshot) {
                    final loadingNames = customerSnapshot.connectionState == ConnectionState.waiting && _customerCache.isEmpty;
                    final customerMap = customerSnapshot.data ?? _customerCache;
                    if (loadingNames) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final invoice = invoices[index];
                        final customerName = _customerDisplayName(invoice.customerId, customerMap);
                        return Card(
                          child: ListTile(
                            onTap: () => _showInvoiceDetails(invoice),
                            title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('merchant_invoices_customer'.tr(args: [customerName])),
                                Text('merchant_invoices_total'.tr(args: [invoice.totalAmount.toStringAsFixed(2)])),
                                if (invoice.ocrText != null && invoice.ocrText!.isNotEmpty)
                                  Text('merchant_invoices_ocr'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatusChip(status: invoice.status),
                                const SizedBox(height: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_horiz),
                                  onSelected: (value) => _updateStatus(invoice, value),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'approved',
                                      child: Text('merchant_invoices_action_approve'.tr()),
                                    ),
                                    PopupMenuItem(
                                      value: 'rejected',
                                      child: Text('merchant_invoices_action_reject'.tr()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _colorForStatus(BuildContext context) {
    switch (status) {
      case 'approved':
        return Colors.green.shade100;
      case 'rejected':
        return Colors.red.shade100;
      default:
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }
  }

  Color _textColor(BuildContext context) {
    switch (status) {
      case 'approved':
        return Colors.green.shade900;
      case 'rejected':
        return Colors.red.shade900;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _colorForStatus(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('merchant_invoices_status_$status'.tr(), style: TextStyle(color: _textColor(context))),
    );
  }
}

class _InvoiceDetailsSheet extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceDetailsSheet({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('merchant_invoices_details_title'.tr(args: [invoice.invoiceNumber]),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('merchant_invoices_total'.tr(args: [invoice.totalAmount.toStringAsFixed(2)])),
          Text('merchant_invoices_customer'.tr(args: [invoice.customerId])),
          const SizedBox(height: 12),
          Text('merchant_invoices_items'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...invoice.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productId),
              subtitle: Text('merchant_invoices_item_points'.tr(args: [item.points.toStringAsFixed(1)])),
              trailing: Text('${item.quantity} × ${item.price.toStringAsFixed(2)}'),
            ),
          ),
          const SizedBox(height: 12),
          if (invoice.ocrText != null && invoice.ocrText!.isNotEmpty)
            ExpansionTile(
              title: Text('merchant_invoices_ocr'.tr()),
              children: [
                Text(invoice.ocrText!),
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
