// lib/services/supabase_user_service.dart
import 'firebase_service.dart';

class SupabaseUserService {
  /// Adds a user document to Firestore `users` collection.
  static Future<void> addUser({
    required String email,
    required String role,
    int points = 0,
    int? age,
    String? gender,
    double? latitude,
    double? longitude,
  }) async {
    await FirebaseService.firestore.collection('users').add({
      'email': email,
      'role': role,
      'points': points,
      'created_at': DateTime.now().toIso8601String(),
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }
}
