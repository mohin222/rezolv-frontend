import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves the last successful API response under a given key, so it can be
/// shown as a fallback if a later fetch fails (no internet, backend down).
class OfflineCache {
  static const String _prefix = 'offline_cache_';

  static Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
  }

  static Future<dynamic> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
