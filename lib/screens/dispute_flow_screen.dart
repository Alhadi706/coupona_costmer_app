import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class DisputeFlowScreen extends StatefulWidget {
  const DisputeFlowScreen({super.key});

  @override
  State<DisputeFlowScreen> createState() => _DisputeFlowScreenState();
}

class _DisputeFlowScreenState extends State<DisputeFlowScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  bool _loadingInvoices = true;
  String? _invoicesError;
  List<Map<String, dynamic>> _invoices = const <Map<String, dynamic>>[];

  bool _uploading = false;
  Uint8List? _imageBytes;
  Map<String, dynamic>? _selectedInvoice;
  String? _selectedType;

  static const List<String> _reportTypes = <String>[
    'product_quality',
    'price_mismatch',
    'service_delay',
    'other_report',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentInvoices();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentInvoices() async {
    setState(() {
      _loadingInvoices = true;
      _invoicesError = null;
    });
    try {
      final invoices = await CompanyServerService.getMyInvoices(limit: 20);
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _loadingInvoices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInvoices = false;
        _invoicesError = e.toString();
      });
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _selectedInvoice = null;
    });
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInvoice == null && _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dispute_choose_invoice_or_photo'.tr())),
      );
      return;
    }
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_report_type'.tr())),
      );
      return;
    }

    setState(() => _uploading = true);
    String? imageUrl;
    try {
      if (_imageBytes != null) {
        imageUrl = await CompanyServerService.uploadImageBytes(_imageBytes!);
      }
      final storeId = _selectedInvoice?['storeId']?.toString();
      final brandId = _selectedInvoice?['brandId']?.toString();
      final productName = _selectedInvoice?['productName']?.toString();

      await CompanyServerService.createReport(
        reportType: _selectedType!,
        targetStoreId: storeId,
        targetBrandId: brandId,
        description: _descriptionController.text.trim(),
        productName: productName,
        imageUrl: imageUrl,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('report_send_failed'.tr())),
      );
      return;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('report_sent'.tr()),
        content: Text('dispute_dual_dispatch_message'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatInvoiceDate(dynamic value) {
    final raw = value?.toString() ?? '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildSourceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dispute_link_invoice_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text('dispute_capture_receipt'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRecentInvoicesSheet(),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text('dispute_select_invoice'.tr()),
                  ),
                ),
              ],
            ),
            if (_selectedInvoice != null) ...[
              const SizedBox(height: 12),
              _buildSelectedInvoiceChip(),
            ],
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              _buildAttachedPhotoPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInvoiceChip() {
    final invoice = _selectedInvoice!;
    final storeName = (invoice['storeName'] ?? invoice['merchantName'] ?? 'dispute_unknown_store'.tr()).toString();
    final total = (invoice['total'] ?? invoice['amount'] ?? 0).toString();
    return Chip(
      avatar: const Icon(Icons.receipt_outlined, size: 18),
      label: Text('$storeName • $total'),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () => setState(() => _selectedInvoice = null),
    );
  }

  Widget _buildAttachedPhotoPreview() {
    return Stack(
      alignment: AlignmentDirectional.topEnd,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _imageBytes!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.black54,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              color: Colors.white,
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {

                _imageBytes = null;
              }),
            ),
          ),
        ),
      ],
    );
  }

  void _showRecentInvoicesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dispute_recent_invoices_title'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildRecentInvoicesList(scrollController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentInvoicesList(ScrollController scrollController) {
    if (_loadingInvoices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_invoicesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('dispute_invoices_load_error'.tr()),
            TextButton.icon(
              onPressed: _loadRecentInvoices,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr()),
            ),
          ],
        ),
      );
    }
    if (_invoices.isEmpty) {
      return Center(child: Text('dispute_no_invoices'.tr()));
    }
    return ListView.separated(
      controller: scrollController,
      itemCount: _invoices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        final storeName = (invoice['storeName'] ?? invoice['merchantName'] ?? 'dispute_unknown_store'.tr()).toString();
        final total = (invoice['total'] ?? invoice['amount'] ?? 0).toString();
        final date = _formatInvoiceDate(invoice['createdAt'] ?? invoice['date']);
        final selected = _selectedInvoice == invoice;
        return ListTile(
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? kTeal : Colors.grey,
          ),
          title: Text(storeName),
          subtitle: Text('dispute_invoice_date_total'.tr(namedArgs: {'date': date, 'total': total})),
          onTap: () {
            setState(() {
              _selectedInvoice = invoice;
              _imageBytes = null;
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _buildTypeChips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dispute_report_type_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reportTypes.map((type) {
                final selected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type.tr()),
                  selected: selected,
                  selectedColor: kTeal.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'report_description'.tr(),
            hintText: 'write_details_here'.tr(),
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'please_write_report_description'.tr()
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('dispute_submit_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSourceSection(),
            const SizedBox(height: 16),
            _buildTypeChips(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _uploading ? null : _submitDispute,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _uploading ? 'uploading'.tr() : 'send_report'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
