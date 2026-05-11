import 'package:shared_preferences/shared_preferences.dart';

enum Environment { local, staging }

class EnvironmentConfig {
  static const _key = 'app_environment';

  static const _urls = {
    Environment.local: 'http://88.88.1.22:8000/api/v1',
    // Environment.local: 'http://192.168.0.17:8000/api/v1',
    Environment.staging: 'https://api-staging.citadelgroup.com.my/api/v1',
  };

  static Environment _current = Environment.local;

  static Environment get current => _current;

  static String get baseUrl => _urls[_current]!;

  static String get label => _current == Environment.local ? 'LOCAL' : 'STAGING';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'staging') {
      _current = Environment.staging;
    } else {
      _current = Environment.local;
    }
  }

  static Future<void> setEnvironment(Environment env) async {
    _current = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, env == Environment.staging ? 'staging' : 'local');
  }
}