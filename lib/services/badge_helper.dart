import 'package:shared_preferences/shared_preferences.dart';

class BadgeHelper {
  static const String offersKey = 'offersLastCount';
  static const String communityKey = 'communityLastCount';
  static const String rewardsKey = 'rewardsLastCount';

  static Future<int> getLastCount(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  static Future<void> setLastCount(String key, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, count);
  }
}
