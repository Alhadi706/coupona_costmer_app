import 'package:image_picker/image_picker.dart';

import 'invoice_ocr_service_stub.dart'
    if (dart.library.html) 'invoice_ocr_service_web.dart'
    if (dart.library.io) 'invoice_ocr_service_mobile.dart';

abstract class InvoiceOcrService {
  Future<String> extractText(XFile image);
}

InvoiceOcrService createInvoiceOcrService() => createInvoiceOcrServiceImpl();