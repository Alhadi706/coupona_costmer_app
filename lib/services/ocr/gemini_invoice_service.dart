import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Result container coming back from the Gemini-powered endpoint.
class GeminiInvoiceResult {
  const GeminiInvoiceResult({
    required this.rawText,
    this.rawTextHash,
    this.merchantCode,
    this.merchantName,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceTime,
    this.currency,
    this.subtotalAmount,
    this.taxAmount,
    this.totalAmount,
    this.lineItems = const [],
  });

  factory GeminiInvoiceResult.fromJson(Map<String, dynamic> json) {
    return GeminiInvoiceResult(
      rawText: json['rawText']?.toString() ?? '',
      rawTextHash: json['rawTextHash']?.toString(),
      merchantCode: json['merchantCode']?.toString(),
      merchantName: json['merchantName']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate']?.toString(),
      invoiceTime: json['invoiceTime']?.toString(),
      currency: json['currency']?.toString(),
      subtotalAmount: _parseDouble(json['subtotalAmount']),
      taxAmount: _parseDouble(json['taxAmount']),
      totalAmount: _parseDouble(json['totalAmount']),
        lineItems: (json['lineItems'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GeminiInvoiceLineItem.fromJson)
          .toList(growable: false),
    );
  }

  final String rawText;
  final String? rawTextHash;
  final String? merchantCode;
  final String? merchantName;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? invoiceTime;
  final String? currency;
  final double? subtotalAmount;
  final double? taxAmount;
  final double? totalAmount;
  final List<GeminiInvoiceLineItem> lineItems;

  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      if (rawTextHash != null) 'rawTextHash': rawTextHash,
      if (merchantCode != null) 'merchantCode': merchantCode,
      if (merchantName != null) 'merchantName': merchantName,
      if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
      if (invoiceDate != null) 'invoiceDate': invoiceDate,
      if (invoiceTime != null) 'invoiceTime': invoiceTime,
      if (currency != null) 'currency': currency,
      if (subtotalAmount != null) 'subtotalAmount': subtotalAmount,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (lineItems.isNotEmpty)
        'lineItems': lineItems.map((item) => item.toJson()).toList(growable: false),
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

class GeminiInvoiceLineItem {
  const GeminiInvoiceLineItem({
    this.description,
    this.quantity,
    this.unitPrice,
    this.lineTotal,
  });

  factory GeminiInvoiceLineItem.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic value) => (value is num)
        ? value.toDouble()
        : (value == null ? null : double.tryParse(value.toString()));

    return GeminiInvoiceLineItem(
      description: json['description']?.toString(),
      quantity: parseNum(json['quantity']),
      unitPrice: parseNum(json['unitPrice']),
      lineTotal: parseNum(json['lineTotal']),
    );
  }

  final String? description;
  final double? quantity;
  final double? unitPrice;
  final double? lineTotal;

  Map<String, dynamic> toJson() {
    return {
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unitPrice': unitPrice,
      if (lineTotal != null) 'lineTotal': lineTotal,
    };
  }
}

/// Talks to the deployed Cloud Function that proxies invoices to Gemini.
class GeminiInvoiceService {
  static const Duration _timeout = Duration(seconds: 45);
  static const String _endpoint = String.fromEnvironment('GEMINI_OCR_ENDPOINT');

  static bool get isConfigured => _endpoint.isNotEmpty;

  /// Returns null when Gemini is not configured or the call fails.
  static Future<GeminiInvoiceResult?> analyze(XFile image) async {
    if (!isConfigured) {
      return null;
    }

    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? 'image/jpeg';
    final base64Image = base64Encode(bytes);

    final payload = jsonEncode({
      'imageBase64': 'data:$mimeType;base64,$base64Image',
      'extraInstructions': 'The receipt may contain Arabic text. '
          'Merchant codes often appear as "كود التاجر" or "Merchant Code".',
    });

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      return GeminiInvoiceResult.fromJson(data);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
