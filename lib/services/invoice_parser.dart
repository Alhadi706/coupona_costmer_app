import 'dart:convert';
import 'package:crypto/crypto.dart';

class ParsedInvoice {
  final String invoiceNumber;
  final String storeName;
  final DateTime date;
  final List<Map<String,dynamic>> products;
  final double total;
  final String uniqueHash;
  final String merchantCode;

  ParsedInvoice({
    required this.invoiceNumber,
    required this.storeName,
    required this.date,
    required this.products,
    required this.total,
    required this.uniqueHash,
    required this.merchantCode,
  });
}

String _normalizeArabicDigits(String input) {
  const map = {
    '٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'
  };
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}

ParsedInvoice parseInvoiceText(String raw, {required String merchantCode}) {
  raw = _normalizeArabicDigits(raw);
  final lines = raw.split('\n').map((l)=>l.trim()).where((l)=>l.isNotEmpty).toList();

  String storeName = lines.isNotEmpty ? lines.first : 'Store';
  if (storeName.length < 4 && lines.length > 1) storeName = lines[1];

  final dateRx = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})');
  DateTime date = DateTime.now();
  for (final l in lines) {
    final m = dateRx.firstMatch(l);
    if (m != null) {
      final d = m.group(1); final mo = m.group(2); final y = m.group(3);
      try { date = DateTime.parse('$y-$mo-$d'); } catch (_) {}
      break;
    }
  }

  final invRx = RegExp(r'(?:فاتورة|Invoice|رقم الفاتورة|No)\s*[:#-]?\s*(\d{3,})');
  String invoiceNumber = '';
  for (final l in lines) {
    final m = invRx.firstMatch(l);
    if (m != null) { invoiceNumber = m.group(1) ?? ''; break; }
  }
  if (invoiceNumber.isEmpty) {
    final numericLine = lines.firstWhere(
      (l) => RegExp(r'^\d{5,8}$').hasMatch(l),
      orElse: () => ''
    );
    if (numericLine.isNotEmpty) invoiceNumber = numericLine;
  }
  if (invoiceNumber.isEmpty) {
    invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
  }

  final productLineRx = RegExp(r'([\u0600-\u06FFA-Za-z\s]+?)\s+(\d+[\.,]?\d{0,2})$');
  final products = <Map<String,dynamic>>[];
  double total = 0;
  for (final l in lines) {
    final pm = productLineRx.firstMatch(l);
    if (pm != null) {
      final name = pm.group(1)!.trim();
      final priceStr = pm.group(2)!.replaceAll(',', '.');
      final price = double.tryParse(priceStr) ?? 0;
      if (price > 0 && name.length > 1) {
        products.add({
          'name': name,
          'quantity': 1,
          'unit_price': price,
          'total_price': price,
        });
      }
    }
  }

  final totalRx = RegExp(r'(?:الإجمالي|المجموع|Total|DL\s*المجموع)\D*(\d+[\.,]?\d{0,2})');
  for (final l in lines) {
    final tm = totalRx.firstMatch(l);
    if (tm != null) {
      total = double.tryParse(tm.group(1)!.replaceAll(',', '.')) ?? total;
      break;
    }
  }
  if (total == 0 && products.isNotEmpty) {
    total = products.fold(0.0, (p, e)=> p + (e['total_price'] as num).toDouble());
  }

  final uniqueHash = sha1.convert(utf8.encode(raw)).toString();

  return ParsedInvoice(
    invoiceNumber: invoiceNumber,
    storeName: storeName,
    date: date,
    products: products,
    total: total,
    uniqueHash: uniqueHash,
    merchantCode: merchantCode,
  );
}
