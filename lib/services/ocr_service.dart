import 'dart:io';

/// Placeholder interface for OCR pipeline. The implementation should upload the
/// image to your OCR provider, receive structured data, then discard the image
/// after extracting text. This class returns mocked data for now.
class OcrService {
  Future<Map<String, dynamic>> parseInvoice(File imageFile) async {
    // TODO: call your OCR API here. For now we return sample data built from
    // file name to make local testing deterministic.
    final fakeMerchantId = 'merchant_${imageFile.path.hashCode.abs()}';
    return {
      'merchantId': fakeMerchantId,
      'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch}',
      'totalAmount': 0,
      'items': <Map<String, dynamic>>[],
      'ocrText': 'Mock OCR content from ${imageFile.path}',
    };
  }
}
