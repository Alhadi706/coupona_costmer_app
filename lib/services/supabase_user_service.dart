// lib/services/supabase_user_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class SupabaseUserService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// إضافة مستخدم جديد إلى جدول users في Supabase
  static Future<void> addUser({
    required String email,
    required String role,
    int points = 0,
  }) async {
    if (!SupabaseService.enabled) return;
    await _client.from('users').insert({
      'email': email,
      'role': role,
      'points': points,
      'created_at': DateTime.now().toIso8601String(),
    });
    // يمكنك معالجة response أو إرجاعه إذا أردت
  }
}
