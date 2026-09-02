import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const String _tokenKey = 'server_auth_token';
  static const String _userIdKey = 'server_user_id';
  static const String _emailKey = 'server_user_email';
  static const String _roleKey = 'server_user_role';

  static Future<void> save({
    required String token,
    required String userId,
    required String email,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_roleKey, role);
  }

  static Future<void> setEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
  }

  static Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && _isExpiredJwt(token)) {
      await clear();
      return null;
    }
    return token;
  }

  static bool _isExpiredJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final expiresAt = payload is Map ? payload['exp'] : null;
      if (expiresAt is! num) return false;
      return DateTime.now().millisecondsSinceEpoch >= expiresAt.toInt() * 1000;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> email() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String> role() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? 'customer';
  }

  static Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }
}
