import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'invoice_ocr_service.dart';

class _MobileInvoiceOcrService implements InvoiceOcrService {
  @override
  Future<String> extractText(XFile image) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      recognizer.close();
    }
  }
}

InvoiceOcrService createInvoiceOcrServiceImpl() => _MobileInvoiceOcrService();