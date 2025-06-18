// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://pedzvbkrlbhfguhkzznr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBlZHp2YmtybGJoZmd1aGt6em5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg2OTY5NjcsImV4cCI6MjA2NDI3Mjk2N30.fNM7yYuqauXXbnwEiYbBu86R5VDhe0Ie4Xc7iJgwZzg';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
