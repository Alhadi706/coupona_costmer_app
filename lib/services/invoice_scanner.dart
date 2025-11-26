import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class InvoiceScanResult {
  const InvoiceScanResult({
    this.image,
    this.text,
    this.errorMessage,
  });

  final XFile? image;
  final String? text;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  bool get hasText => (text ?? '').isNotEmpty;
}

class InvoiceScanner {
  /// يفتح الكاميرا، يلتقط صورة للفاتورة، ثم يعالجها لاستخراج النص الخام.
  static Future<InvoiceScanResult> scanInvoiceText() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) {
      return const InvoiceScanResult(errorMessage: 'no_image_captured');
    }

    final textRecognizer = _buildTextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return InvoiceScanResult(
        image: image,
        text: recognizedText.text,
      );
    } on Exception catch (error) {
      return InvoiceScanResult(
        image: image,
        errorMessage: 'ocr_error:${error.runtimeType}',
      );
    } finally {
      await textRecognizer.close();
    }
  }

  static TextRecognizer _buildTextRecognizer() {
    try {
      final arabicScript = TextRecognitionScript.values.byName('arabic');
      return TextRecognizer(script: arabicScript);
    } catch (_) {
      return TextRecognizer();
    }
  }
}
