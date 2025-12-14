import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Lightweight helper around the free OCR.space API for prototyping.
class OcrSpaceService {
  static const _endpoint = 'https://api.ocr.space/parse/image';
  // Demo key provided by OCR.space for non-production usage.
  static const _demoApiKey = 'helloworld';

  /// Sends the image to OCR.space and returns the concatenated parsed text.
  static Future<String?> extractText(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'apikey': _demoApiKey,
          },
          body: {
            'language': 'ara',
            'isOverlayRequired': 'false',
            'scale': 'true',
            'OCREngine': '2',
            'base64Image': 'data:image/jpeg;base64,$base64Image',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['IsErroredOnProcessing'] == true) {
      return null;
    }

    final results = data['ParsedResults'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    for (final result in results) {
      final parsed = result['ParsedText']?.toString();
      if (parsed != null && parsed.trim().isNotEmpty) {
        buffer.writeln(parsed.trim());
      }
    }
    final text = buffer.toString().trim();
    return text.isEmpty ? null : text;
  }
}
