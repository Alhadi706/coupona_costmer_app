class InvoiceParser {
  /// يحلل النص الخام المستخرج من الفاتورة ويستخلص أهم الحقول.
  static Map<String, dynamic> parseInvoiceData(String rawText) {
    final normalizedText = rawText.replaceAll('\r', '');
    final extractedData = <String, dynamic>{};

    final merchantCodeRegex = RegExp(
      r'(?:كود\s*التاجر|merchant\s*(?:code|id)|store\s*code)\s*[:：#-]*\s*([A-Z0-9\-]{4,12})',
      caseSensitive: false,
    );
    final merchantMatch = merchantCodeRegex.firstMatch(normalizedText.toUpperCase());
    final rawCode = merchantMatch?.group(1) ?? '';
    final normalizedCode = rawCode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    extractedData['merchant_code'] = normalizedCode;

    final totalRegex = RegExp(
      r'(?:الإجمالي|المجموع|total)\s*[:：-]?\s*([\d.,]+)',
      caseSensitive: false,
    );
    final totalMatch = totalRegex.firstMatch(normalizedText);
    if (totalMatch != null) {
      final cleanTotal = totalMatch.group(1)!.replaceAll(',', '').replaceAll(' ', '');
      extractedData['total_amount'] = double.tryParse(cleanTotal) ?? 0.0;
    } else {
      extractedData['total_amount'] = 0.0;
    }

    extractedData['raw_text'] = rawText;
    return extractedData;
  }
}
