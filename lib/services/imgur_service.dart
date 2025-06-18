// lib/services/imgur_service.dart
// خدمة رفع الصور إلى Imgur API
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImgurService {
  // ضع هنا الـ Client ID الخاص بك من Imgur
  static const String clientId = 'c0ee0242bbcf8fc'; // استبدلها بالمعرف الفعلي

  /// يرفع صورة إلى Imgur من ملف (للموبايل/ديسكتوب)
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await uploadImageFromBytes(bytes);
    } catch (e) {
      debugPrint('Imgur upload error: $e');
      return null;
    }
  }

  /// يرفع صورة إلى Imgur من bytes (للويب)
  static Future<String?> uploadImageFromBytes(List<int> bytes) async {
    try {
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          'Authorization': 'Client-ID $clientId',
        },
        body: {
          'image': base64Image,
          'type': 'base64',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data']['link'] as String;
      } else {
        debugPrint('Imgur upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Imgur upload error: $e');
      return null;
    }
  }
}
