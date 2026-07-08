import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des jetons (Keychain iOS / Keystore Android).
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUser = 'user_json';

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);
  Future<String?> get userJson => _storage.read(key: _kUser);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kUser, value: userJson);
  }

  Future<void> updateAccessToken(String accessToken, String refreshToken) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
