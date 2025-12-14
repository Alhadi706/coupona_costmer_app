import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/merchant_code_service.dart';
import '../services/user_merchant_link_service.dart';

class AddCouponManualScreen extends StatefulWidget {
  const AddCouponManualScreen({super.key});

  @override
  State<AddCouponManualScreen> createState() => _AddCouponManualScreenState();
}

class _AddCouponManualScreenState extends State<AddCouponManualScreen> {
  final TextEditingController _merchantCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final MerchantCodeService _merchantCodeService = MerchantCodeService();

  DateTime? _invoiceDate;
  TimeOfDay? _invoiceTime;
  final List<_LineItemControllers> _lineItems = [];
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;
  static const int _maxLineItems = 30;

  @override
  void initState() {
    super.initState();
    _lineItems.add(_LineItemControllers());
  }

  @override
  void dispose() {
    _merchantCodeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _invoiceNumberController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addLineItem() {
    if (_lineItems.length >= _maxLineItems) return;
    setState(() {
      _lineItems.add(
        _LineItemControllers(),
      );
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      final removed = _lineItems.removeAt(index);
      removed.dispose();
    });
  }

  List<Map<String, dynamic>> _buildLineItemsPayload() {
    return _lineItems.map((item) {
      final description = item.description.text.trim();
      final quantity = double.tryParse(item.quantity.text.trim());
      final unitPrice = double.tryParse(item.unitPrice.text.trim());
      final lineTotal = double.tryParse(item.total.text.trim());
      final map = <String, dynamic>{
        'description': description.isEmpty ? null : description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_total': lineTotal,
      }..removeWhere((key, value) => value == null);
      return map;
    }).where((entry) => entry.isNotEmpty).toList();
  }

  void _showDebugHint(String message) {
    if (!kDebugMode) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('DEBUG: $message'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _formatTimeForPayload(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickInvoiceDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _invoiceDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (selected != null) {
      setState(() => _invoiceDate = selected);
    }
  }

  Future<void> _pickInvoiceTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _invoiceTime ?? TimeOfDay.now(),
    );
    if (selected != null) {
      setState(() => _invoiceTime = selected);
    }
  }

  Future<void> _submit() async {
    final rawCode = _merchantCodeController.text.trim();
    final normalizedCode = _merchantCodeService.normalizeCode(rawCode);
    if (normalizedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_coupon_manual_missing_code'.tr())),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final lineItemsPayload = _buildLineItemsPayload();
      final payload = <String, dynamic>{
        'merchant_code': normalizedCode,
        'total_amount': double.tryParse(_amountController.text.trim()),
        'invoice_number': _invoiceNumberController.text.trim().isEmpty ? null : _invoiceNumberController.text.trim(),
        'invoice_date': _invoiceDate == null ? null : DateFormat('yyyy-MM-dd').format(_invoiceDate!),
        'invoice_time': _invoiceTime == null ? null : _formatTimeForPayload(_invoiceTime!),
        'line_items': lineItemsPayload.isEmpty ? null : lineItemsPayload,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      }..removeWhere((key, value) => value == null);

      debugPrint('Submitting manual invoice payload: $payload');
      _showDebugHint('Payload ready (${lineItemsPayload.length} items)');

      final resultKey = await UserMerchantLinkService.sendDataToLinkAgent(
        merchantCode: normalizedCode,
        invoicePayload: payload,
      );

      _showDebugHint('Result key: $resultKey');
      debugPrint('Invoice submission result key: $resultKey');

      if (!mounted) return;
      setState(() {
        _statusMessage = resultKey.tr();
        _statusIsError = resultKey != 'invoice_link_success';
      });

      if (resultKey == 'invoice_link_success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('add_coupon_manual_success'.tr())),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusMessage ?? 'add_coupon_manual_error'.tr())),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Manual invoice submission threw: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showDebugHint('Exception: $error');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'add_coupon_manual_error'.tr();
        _statusIsError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_coupon_manual_error'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPickerField({
    required BuildContext context,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: TextStyle(color: onTap == null ? theme.disabledColor : null),
        ),
      ),
    );
  }

  Widget _buildLineItemCard(BuildContext context, int index) {
    final item = _lineItems[index];
    final canRemove = _lineItems.length > 1 && !_isSubmitting;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${'add_coupon_manual_line_items_title'.tr()} #${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: canRemove ? () => _removeLineItem(index) : null,
                  icon: const Icon(Icons.close),
                  tooltip: 'add_coupon_manual_line_item_remove'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: item.description,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'add_coupon_manual_line_item_description'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                Widget buildField(TextEditingController controller, String label) {
                  return TextField(
                    controller: controller,
                    enabled: !_isSubmitting,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                    ),
                  );
                }

                final quantityField = buildField(
                  item.quantity,
                  'add_coupon_manual_line_item_quantity'.tr(),
                );
                final unitPriceField = buildField(
                  item.unitPrice,
                  'add_coupon_manual_line_item_unit_price'.tr(),
                );
                final totalField = buildField(
                  item.total,
                  'add_coupon_manual_line_item_total'.tr(),
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    children: [
                      quantityField,
                      const SizedBox(height: 12),
                      unitPriceField,
                      const SizedBox(height: 12),
                      totalField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: quantityField),
                    const SizedBox(width: 12),
                    Expanded(child: unitPriceField),
                    const SizedBox(width: 12),
                    Expanded(child: totalField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('add_coupon_manual_title'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _merchantCodeController,
              decoration: InputDecoration(
                labelText: 'add_coupon_manual_code_label'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'add_coupon_manual_amount_label'.tr(),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceNumberController,
              decoration: InputDecoration(
                labelText: 'add_coupon_manual_invoice_number_label'.tr(),
                border: const OutlineInputBorder(),
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPickerField(
                    context: context,
                    label: 'add_coupon_manual_invoice_date_label'.tr(),
                    value: _invoiceDate == null
                        ? '-'
                        : DateFormat('yyyy-MM-dd').format(_invoiceDate!),
                    onTap: _isSubmitting ? null : _pickInvoiceDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerField(
                    context: context,
                    label: 'add_coupon_manual_invoice_time_label'.tr(),
                    value: _invoiceTime == null ? '-' : _invoiceTime!.format(context),
                    onTap: _isSubmitting ? null : _pickInvoiceTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'add_coupon_manual_line_items_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _isSubmitting || _lineItems.length >= _maxLineItems
                      ? null
                      : () => _addLineItem(),
                  icon: const Icon(Icons.add),
                  label: Text('add_coupon_manual_line_item_add'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: _lineItems
                  .asMap()
                  .entries
                  .map((entry) => _buildLineItemCard(context, entry.key))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              enabled: !_isSubmitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'add_coupon_manual_notes_label'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusIsError ? Colors.red : Colors.green,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('add_coupon_manual_submit'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineItemControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController total;

  _LineItemControllers({
    String? description,
    String? quantity,
    String? unitPrice,
    String? total,
  })  : description = TextEditingController(text: description ?? ''),
        quantity = TextEditingController(text: quantity ?? ''),
        unitPrice = TextEditingController(text: unitPrice ?? ''),
        total = TextEditingController(text: total ?? '');

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    total.dispose();
  }
}
