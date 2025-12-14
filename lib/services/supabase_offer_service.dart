import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class SupabaseOfferService {
  /// Upload image to Firebase Storage and return URL (used as replacement).
  static Future<String?> uploadImage(XFile image) async {
    try {
      final cleanName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final fileName = 'offers/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final bytes = await image.readAsBytes();
      final ref = FirebaseService.storage.ref().child(fileName);
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload image error: $e');
      return null;
    }
  }

  /// Add offer to Firestore (replaces previous Supabase insert).
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
    await FirebaseService.firestore.collection('offers').add({
      'offerType': offerType,
      'category': category,
      'titleType': titleType,
      'discountValue': discountValue,
      'price': price,
      'description': description,
      'startDate': startDate != null ? Timestamp.fromDate(DateTime.parse(startDate)) : null,
      'endDate': endDate != null ? Timestamp.fromDate(DateTime.parse(endDate)) : null,
      'location': location,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
    });
  }
}
