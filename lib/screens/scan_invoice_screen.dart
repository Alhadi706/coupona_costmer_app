// filepath: lib/screens/scan_invoice_screen.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/invoice_parser.dart';
import '../services/invoice_scanner.dart';
import '../services/user_merchant_link_service.dart';

class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({Key? key}) : super(key: key);

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  XFile? _capturedImage;
  bool _isProcessing = false;
  String? _ocrResult;
  String? _error;
  bool _didAutoOpenCamera = false;
  Map<String, dynamic>? _parsedData;
  bool _isLinking = false;
  String? _linkMessage;
  bool _linkHasError = false;
  final TextEditingController _manualMerchantIdController = TextEditingController();
  bool _showManualMerchantIdInput = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoOpenCamera && _capturedImage == null) {
      _didAutoOpenCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startScan();
        }
      });
    }
  }

  Future<void> _startScan({bool allowPopOnCancel = true}) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _error = null;
      _ocrResult = null;
      _parsedData = null;
      _linkMessage = null;
      _linkHasError = false;
      _showManualMerchantIdInput = false;
      _manualMerchantIdController.clear();
    });

    try {
      final result = await InvoiceScanner.scanInvoiceText();
      if (!mounted) return;

      if (result.image == null && result.errorMessage == 'no_image_captured') {
        setState(() {
          _isProcessing = false;
          _capturedImage = null;
          _ocrResult = null;
          _parsedData = null;
          _linkMessage = null;
        });
        if (allowPopOnCancel && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return;
      }

      if (result.hasError) {
        setState(() {
          _isProcessing = false;
          _capturedImage = result.image;
          _error = result.errorMessage == 'no_image_captured'
              ? 'error_capturing_image'.tr()
              : 'error_processing_image'.tr();
          _parsedData = null;
          _linkMessage = null;
        });
        return;
      }

      final rawText = (result.text ?? '').trim();
      final parsed = rawText.isNotEmpty ? InvoiceParser.parseInvoiceData(rawText) : null;

      setState(() {
        _capturedImage = result.image;
        _isProcessing = false;
        _ocrResult = rawText.isEmpty ? 'no_text_found'.tr() : rawText;
        _parsedData = parsed;
        _linkMessage = null;
        _linkHasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'error_processing_image'.tr();
        _parsedData = null;
        _linkMessage = null;
        _linkHasError = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _isProcessing = false;
      _ocrResult = null;
      _error = null;
      _parsedData = null;
      _linkMessage = null;
      _linkHasError = false;
      _didAutoOpenCamera = false;
    });
    _startScan(allowPopOnCancel: false);
  }

  Future<void> _linkInvoice() async {
    final parsed = _parsedData;
    if (parsed == null) {
      return;
    }

    String merchantId = parsed['merchant_id']?.toString().trim() ?? '';
    if (merchantId.isEmpty || merchantId.startsWith('UUID_')) {
      // Show manual input UI
      setState(() {
        _showManualMerchantIdInput = true;
        _linkMessage = 'invoice_link_missing_merchant';
        _linkHasError = true;
      });
      return;
    }

    // If manual input is visible, use its value
    if (_showManualMerchantIdInput) {
      merchantId = _manualMerchantIdController.text.trim();
      if (merchantId.isEmpty) {
        setState(() {
          _linkMessage = 'invoice_link_missing_merchant';
          _linkHasError = true;
        });
        return;
      }
    }

    final payload = Map<String, dynamic>.from(parsed);
    payload['merchant_id'] = merchantId;
    payload.remove('merchant_id');

    setState(() {
      _isLinking = true;
      _linkMessage = null;
      _linkHasError = false;
    });

    try {
      final resultMessage = await UserMerchantLinkService.sendDataToLinkAgent(
        merchantUuid: merchantId,
        invoicePayload: payload,
      );

      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _linkMessage = resultMessage;
        _linkHasError = false;
      });
      if (resultMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_resolveLinkMessage(resultMessage))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLinking = false;
        _linkMessage = 'invoice_link_failed';
        _linkHasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('invoice_link_failed'.tr())),
      );
    }
  }

  String _resolveLinkMessage(String keyOrMessage) {
    final localized = keyOrMessage.tr();
    // easy_localization returns the key itself when no translation is found.
    if (localized == keyOrMessage && !keyOrMessage.contains(' ')) {
      return keyOrMessage;
    }
    return localized;
  }

  Widget _buildResultView() {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('processing_invoice'.tr()),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reset,
              child: Text('try_again'.tr()),
            ),
          ],
        ),
      );
    }

    if (_ocrResult != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_capturedImage != null)
              Image.file(
                File(_capturedImage!.path),
                fit: BoxFit.contain,
                height: 200,
              ),
            const SizedBox(height: 16),
            Text(
              'invoice_text'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SelectableText(
                  _ocrResult!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (_parsedData != null) ...[
              const SizedBox(height: 20),
              Text(
                'invoice_summary'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryRow('merchant_id_label'.tr(), _parsedData!['merchant_id']?.toString() ?? ''),
                      if (_showManualMerchantIdInput) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _manualMerchantIdController,
                          decoration: InputDecoration(
                            labelText: 'merchant_id_label'.tr(),
                            hintText: 'أدخل كود التاجر من الفاتورة',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'total_amount_label'.tr(),
                        (_parsedData!['total_amount'] ?? 0).toString(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isLinking ? null : _linkInvoice,
                icon: _isLinking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text('link_invoice'.tr()),
              ),
              if (_linkMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _resolveLinkMessage(_linkMessage!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _linkHasError ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reset,
              child: Text('scan_another_invoice'.tr()),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'scan_invoice_to_get_text'.tr(),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            style: const TextStyle(fontFamily: 'RobotoMono'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan_invoice'.tr()),
        actions: [
          if (_capturedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'reset'.tr(),
            ),
        ],
      ),
      body: _buildResultView(),
    );
  }
}
