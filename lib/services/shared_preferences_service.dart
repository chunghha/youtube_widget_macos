// lib/services/shared_preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static const String _lastPlayedUrlKey = 'last_played_youtube_url';
  static const String _lastVolumeKey = 'last_volume';

  static Future<void> saveLastPlayedUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPlayedUrlKey, url);
  }

  static Future<String?> loadLastPlayedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastPlayedUrlKey);
  }

  static Future<void> saveVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastVolumeKey, volume);
  }

  static Future<double> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_lastVolumeKey) ?? 100.0;
  }
}
