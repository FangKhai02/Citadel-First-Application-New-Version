import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userTypeKey = 'user_type';
  static const _userIdKey = 'user_id';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userType,
    required int userId,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _userTypeKey, value: userType),
      _storage.write(key: _userIdKey, value: userId.toString()),
    ]);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  static Future<String?> getUserType() => _storage.read(key: _userTypeKey);

  static Future<void> clearAll() => _storage.deleteAll();
}
