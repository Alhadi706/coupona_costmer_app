import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class SupabaseOfferService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// رفع صورة إلى Supabase Storage وإرجاع الرابط
  static Future<String?> uploadImage(XFile image) async {
    try {
      // اسم الملف بدون أحرف عربية أو رموز خاصة
      String cleanName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final fileName = 'offers/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final bytes = await image.readAsBytes();
      final response = await _client.storage.from('offers').uploadBinary(
        fileName, bytes, fileOptions: const FileOptions(upsert: true));
      if (response.isNotEmpty) {
        final publicUrl = _client.storage.from('offers').getPublicUrl(fileName);
        return publicUrl;
      }
      return null;
    } catch (e) {
      print('Upload image error: $e');
      return null;
    }
  }

  /// إضافة عرض جديد إلى جدول offers في Supabase
  static Future<void> addOffer({
    required String offerType,
    required String category,
    String? titleType,
    String? discountValue,
    String? price,
    String? description,
    String? startDate,
    String? endDate,
    String? location,
    String? imageUrl,
  }) async {
    await _client.from('offers').insert({
      'offerType': offerType,
      'category': category,
      'titleType': titleType,
      'discountValue': discountValue,
      'price': price,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'location': location,
      'imageUrl': imageUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
