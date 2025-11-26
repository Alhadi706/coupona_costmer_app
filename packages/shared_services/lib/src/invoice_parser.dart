class InvoiceParser {
  /// يحلل النص الخام المستخرج من الفاتورة ويستخلص أهم الحقول.
  static Map<String, dynamic> parseInvoiceData(String rawText) {
    final normalizedText = rawText.replaceAll('\r', '');
    final extractedData = <String, dynamic>{};

    final merchantIdRegex = RegExp(
      r'(?<=كود\s+التاجر[:：]?\s*|merchant\s*id[:：]?\s*)([\w\d-]+)',
      caseSensitive: false,
    );
    final merchantMatch = merchantIdRegex.firstMatch(normalizedText);
    extractedData['merchant_id'] = merchantMatch?.group(1)?.trim() ?? 'UUID_لم_يتم_استخلاصه';

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
