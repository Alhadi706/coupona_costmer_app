import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'dart:convert';

import '../modules/invoice/services/invoice_ocr_service.dart';
import '../modules/invoice/services/invoice_text_parser.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class ScanInvoiceScreen extends StatefulWidget {
  const ScanInvoiceScreen({super.key});

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  final InvoiceOcrService _ocrService = createInvoiceOcrService();
  XFile? _capturedImage;
  Uint8List? _webImageBytes;
  bool _isProcessing = false;
  String? _ocrResult;
  String? _error;
  bool _didAutoOpenCamera = false;
  double _detectedTotal = 0;
  String? _detectedInvoiceNumber;
  String? _detectedOrderNumber;
  String? _detectedStoreName;
  List<String> _detectedStoreCandidates = const <String>[];
  double _detectedStoreConfidence = 0;
  String? _detectedDate;
  String? _detectedCategory;
  List<InvoiceLineItem> _detectedItems = const <InvoiceLineItem>[];
  bool _rewardApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoOpenCamera && _capturedImage == null) {
      _didAutoOpenCamera = true;
      Future.delayed(Duration.zero, () => _captureImage(isPanorama: false));
    }
  }

  Future<void> _captureImage({bool isPanorama = false}) async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _ocrResult = null;
    });
    final picker = ImagePicker();
    try {
      final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        Uint8List? webImageBytes;
        if (kIsWeb) {
          webImageBytes = await image.readAsBytes();
        }
        setState(() {
          _capturedImage = image;
          _webImageBytes = webImageBytes;
        });
        // Placeholder for future long-invoice stitching.
        await _processInvoice(image);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'scan_invoice_capture_error'.tr();
      });
    }
  }

  Future<void> _processInvoice(XFile image) async {
    String extractedText;
    var localError = '';
    try {
      extractedText = await _ocrService.extractText(image);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'scan_invoice_ocr_error'.tr(namedArgs: {'error': e.toString()});
        _ocrResult = null;
      });
      return;
    }

    if (extractedText.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'scan_invoice_no_text'.tr();
        _ocrResult = '';
      });
      return;
    }

    final parsed = InvoiceTextParser.parse(extractedText);
    final merchantOnlyMode = InvoiceTextParser.isMerchantNameOnlyMode;
    final localTotal = parsed.total;
    final localInvoiceNumber = parsed.invoiceNumber;
    final localOrderNumber = parsed.orderNumber;
    final localStoreName = parsed.storeName;
    final localItems = parsed.items;
    final storeCandidates = parsed.storeCandidates;
    final storeConfidence = parsed.storeConfidence;
    final localInvoiceDate = parsed.invoiceDate;

    String? imageBase64;
    try {
      final bytes = await image.readAsBytes();
      imageBase64 = base64Encode(bytes);
    } catch (_) {
      imageBase64 = null;
    }

    final ai = await CompanyServerService.analyzeInvoiceWithAi(
      rawText: extractedText,
      imageBase64: imageBase64,
      mimeType: 'image/jpeg',
    );

    final aiOk = ai != null && ai['ok'] == true;
    final aiData = aiOk ? ai : null;
    final double aiConfidence = aiOk ? (aiData?['confidence'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final aiStore = aiOk ? (aiData?['merchantName'] as String?)?.trim() : null;
    final aiOrder = aiOk ? (aiData?['orderNumber'] as String?)?.trim() : null;
    final aiInvoiceNo = aiOk ? (aiData?['invoiceNumber'] as String?)?.trim() : null;
    final aiDate = aiOk ? (aiData?['invoiceDate'] as String?)?.trim() : null;
    final aiCategory = aiOk ? (aiData?['category'] as String?)?.trim() : null;
    final aiTotal = aiOk ? (aiData?['totalAmount'] as num?)?.toDouble() : null;
    final aiItemsRaw = aiOk && aiData?['items'] is List ? (aiData?['items'] as List) : const [];
    final aiItems = aiItemsRaw
        .whereType<Map>()
        .map((item) {
          final name = (item['name'] ?? '').toString().trim();
          final q = item['quantity'] as num?;
          final u = item['unitPrice'] as num?;
          final t = item['lineTotal'] as num?;
          return InvoiceLineItem(
            name: name,
            quantity: q?.toInt(),
            unitPrice: u?.toDouble(),
            lineTotal: t?.toDouble(),
          );
        })
        .where((e) => e.name.isNotEmpty)
        .toList();

    final total = aiConfidence >= 0.55 && aiTotal != null ? aiTotal : localTotal;
    final invoiceNumber = aiConfidence >= 0.55 && (aiInvoiceNo ?? '').isNotEmpty ? aiInvoiceNo : localInvoiceNumber;
    final orderNumber = aiConfidence >= 0.55 && (aiOrder ?? '').isNotEmpty ? aiOrder : localOrderNumber;
    final storeName = aiConfidence >= 0.5 && (aiStore ?? '').isNotEmpty ? aiStore : localStoreName;
    final invoiceDate = aiConfidence >= 0.55 && (aiDate ?? '').isNotEmpty ? aiDate : localInvoiceDate;
    final finalItems = aiConfidence >= 0.5 && aiItems.isNotEmpty ? aiItems : localItems;
    final String finalCategory = aiConfidence >= 0.55 && (aiCategory ?? '').isNotEmpty
      ? aiCategory!
      : parsed.category;
    var rewardApplied = false;

    if (!merchantOnlyMode) {
      final saveResult = await CompanyServerService.saveInvoiceScan(
        rawText: extractedText,
        category: finalCategory,
        totalAmount: total,
        invoiceNumber: invoiceNumber,
        orderNumber: orderNumber,
        invoiceDate: invoiceDate,
        merchantName: storeName,
        items: finalItems
            .map((item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'lineTotal': item.lineTotal,
                })
            .toList(),
        rewardApplied: false,
      );

      final isDuplicate = saveResult?['duplicate'] == true;
      final isTooOld = saveResult?['tooOld'] == true;

      if (isDuplicate) {
        localError = 'scan_invoice_duplicate'.tr();
      } else if (isTooOld) {
        localError = 'scan_invoice_too_old'.tr();
      } else if (total != null && total > 0) {
        try {
          await CompanyServerService.ensureAccountingDocuments();
          await CompanyServerService.applyCashbackFromPurchase(
            purchaseAmount: total,
            reference: invoiceNumber != null && invoiceNumber.isNotEmpty
                ? 'invoice:$invoiceNumber'
                : (orderNumber != null && orderNumber.isNotEmpty
                    ? 'order:$orderNumber'
                    : 'invoice:${DateTime.now().millisecondsSinceEpoch}'),
          );
          rewardApplied = true;
          await CompanyServerService.saveInvoiceScan(
            rawText: extractedText,
            category: finalCategory,
            totalAmount: total,
            invoiceNumber: invoiceNumber,
            orderNumber: orderNumber,
            invoiceDate: invoiceDate,
            merchantName: storeName,
            items: finalItems
                .map((item) => {
                      'name': item.name,
                      'quantity': item.quantity,
                      'unitPrice': item.unitPrice,
                      'lineTotal': item.lineTotal,
                    })
                .toList(),
            rewardApplied: true,
          );
        } catch (e) {
          localError = 'scan_invoice_rewards_save_error'.tr(namedArgs: {'error': e.toString()});
        }
      } else {
        localError = 'scan_invoice_total_unclear'.tr();
      }
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _detectedTotal = total ?? 0;
      _detectedInvoiceNumber = invoiceNumber;
      _detectedOrderNumber = orderNumber;
      _detectedStoreName = storeName;
      _detectedStoreCandidates = (() {
        final all = <String>[];
        for (final c in storeCandidates) {
          if (c.trim().isNotEmpty && !all.contains(c)) all.add(c);
        }
        if ((aiStore ?? '').isNotEmpty && !all.contains(aiStore)) {
          all.insert(0, aiStore!);
        }
        return all;
      })();
      _detectedStoreConfidence = aiConfidence > 0 ? aiConfidence : storeConfidence;
      _detectedDate = invoiceDate;
      _detectedCategory = finalCategory;
      _detectedItems = finalItems;
      _rewardApplied = rewardApplied;
      _error = localError.isEmpty ? null : localError;
      _ocrResult = extractedText;
    });
  }

  Future<void> _reanalyzeCurrentImage() async {
    if (_capturedImage == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    await _processInvoice(_capturedImage!);
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _webImageBytes = null;
      _ocrResult = null;
      _error = null;
      _detectedTotal = 0;
      _detectedInvoiceNumber = null;
      _detectedOrderNumber = null;
      _detectedStoreName = null;
      _detectedStoreCandidates = const <String>[];
      _detectedStoreConfidence = 0;
      _detectedDate = null;
      _detectedCategory = null;
      _detectedItems = const <InvoiceLineItem>[];
      _rewardApplied = false;
    });
  }

  void _selectMerchantCandidate(String candidate) {
    setState(() {
      _detectedStoreName = candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan_invoice_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : _capturedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: kTeal, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'scan_invoice_frame_hint'.tr(),
                            style: kBodyTextStyle(size: 18, color: kInk),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => _captureImage(isPanorama: false),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: kWhite, size: 44),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _captureImage(isPanorama: true),
                        icon: Icon(Icons.upload_file, color: kInk.withValues(alpha: 0.6)),
                        label: Text(
                          'scan_invoice_capture_long'.tr(),
                          style: kBodyTextStyle(color: kInk.withValues(alpha: 0.65), size: 12),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ]
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 320,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kLine),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? (_webImageBytes == null
                                    ? const SizedBox.shrink()
                                    : Image.memory(
                                        _webImageBytes!,
                                        fit: BoxFit.contain,
                                      ))
                                : Image.file(File(_capturedImage!.path), fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                          ),
                        if (_error != null) const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: Colors.blueGrey.shade900,
                              fontSize: 15,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  InvoiceTextParser.isMerchantNameOnlyMode
                                      ? 'scan_invoice_engine_merchant_only'.tr()
                                      : 'scan_invoice_total_detected'.tr(namedArgs: {
                                          'total': _detectedTotal > 0 ? _detectedTotal.toStringAsFixed(2) : 'scan_invoice_not_available'.tr(),
                                        }),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                                if (!InvoiceTextParser.isMerchantNameOnlyMode && _detectedInvoiceNumber != null)
                                  Text('scan_invoice_invoice_number'.tr(namedArgs: {'value': _detectedInvoiceNumber!})),
                                if (!InvoiceTextParser.isMerchantNameOnlyMode && _detectedOrderNumber != null)
                                  Text('scan_invoice_order_number'.tr(namedArgs: {'value': _detectedOrderNumber!})),
                                if (_detectedStoreName != null)
                                  Text('scan_invoice_store_name'.tr(namedArgs: {'value': _detectedStoreName!})),
                                if (InvoiceTextParser.isMerchantNameOnlyMode && _detectedStoreCandidates.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _detectedStoreConfidence >= 0.7
                                        ? 'scan_invoice_confidence_high'.tr()
                                        : 'scan_invoice_confidence_low'.tr(),
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _detectedStoreCandidates.take(5).map((candidate) {
                                      final isSelected = candidate == _detectedStoreName;
                                      return ChoiceChip(
                                        label: Text(candidate),
                                        selected: isSelected,
                                        onSelected: (_) => _selectMerchantCandidate(candidate),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (!InvoiceTextParser.isMerchantNameOnlyMode && _detectedDate != null)
                                  Text('scan_invoice_date'.tr(namedArgs: {'value': _detectedDate!})),
                                if (!InvoiceTextParser.isMerchantNameOnlyMode && _detectedCategory != null)
                                  Text('scan_invoice_category'.tr(namedArgs: {'value': _detectedCategory!})),
                                if (!InvoiceTextParser.isMerchantNameOnlyMode && _detectedItems.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'scan_invoice_items_extracted'.tr(),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  ..._detectedItems.take(8).map((item) {
                                    final qty = item.quantity;
                                    final unit = item.unitPrice;
                                    final total = item.lineTotal;
                                    final inferredUnit = (unit == null && qty != null && total != null && qty > 0)
                                        ? (total / qty)
                                        : unit;
                                    return Text(
                                      'scan_invoice_item_template'.tr(namedArgs: {
                                        'name': item.name,
                                        'qtyLabel': 'scan_invoice_quantity_label'.tr(),
                                        'qty': (qty ?? '-').toString(),
                                        'unitLabel': 'scan_invoice_unit_price_label'.tr(),
                                        'unit': inferredUnit?.toStringAsFixed(2) ?? '-',
                                        'totalLabel': 'scan_invoice_line_total_label'.tr(),
                                        'total': total?.toStringAsFixed(2) ?? '-',
                                      }),
                                    );
                                  }),
                                ],
                                if (InvoiceTextParser.isMerchantNameOnlyMode)
                                  Text('scan_invoice_demo_mode'.tr())
                                else
                                  Text(
                                    _rewardApplied
                                        ? 'scan_invoice_reward_applied'.tr()
                                        : 'scan_invoice_reward_not_applied'.tr(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            (_ocrResult == null || _ocrResult!.isEmpty)
                                ? 'scan_invoice_no_text_extracted'.tr()
                                : _ocrResult!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _capturedImage == null ? null : _reanalyzeCurrentImage,
                              icon: const Icon(Icons.manage_search),
                              label: Text('scan_invoice_reanalyze'.tr()),
                            ),
                            ElevatedButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.refresh),
                              label: Text('scan_invoice_new_image'.tr()),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _captureImage(isPanorama: false),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text('scan_invoice_pick_other_image'.tr()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}