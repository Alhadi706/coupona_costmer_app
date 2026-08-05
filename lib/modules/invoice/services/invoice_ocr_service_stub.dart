import 'package:image_picker/image_picker.dart';

import 'invoice_ocr_service.dart';

class _UnsupportedInvoiceOcrService implements InvoiceOcrService {
  @override
  Future<String> extractText(XFile image) {
    throw UnsupportedError('OCR is not supported on this platform.');
  }
}

InvoiceOcrService createInvoiceOcrServiceImpl() => _UnsupportedInvoiceOcrService();