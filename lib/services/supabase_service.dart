// lib/services/supabase_service.dart
// Shim for legacy Supabase usage. Supabase has been removed from the
// project in favor of Firebase (Firestore/Storage). Keep this shim so
// in-progress migration doesn't break imports; callers should move to
// `FirebaseService` and remove their Supabase usages.

class SupabaseService {
  /// No-op initializer kept for compatibility. Use `FirebaseService.init()`
  /// in your `main.dart` instead.
  static Future<void> init() async {
    // Supabase disabled — do nothing.
    return;
  }

  /// Accessing a Supabase client is unsupported. Callers should migrate to
  /// `FirebaseService.firestore` or `FirebaseService.storage` instead.
  static dynamic get client =>
      throw UnsupportedError('Supabase removed; use FirebaseService instead.');
}
