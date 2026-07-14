import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/token_storage.dart';
import '../../shared/models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider).dio,
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? city,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/register', data: {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      if (city != null && city.isNotEmpty) 'city': city,
    });
    return _persist(res.data!);
  }

  Future<User> login(String identifier, String password) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/login', data: {
      'identifier': identifier,
      'password': password,
    });
    return _persist(res.data!);
  }

  Future<void> sendOtp(String phone, {String purpose = 'LOGIN'}) async {
    await _dio.post<Map<String, dynamic>>('/auth/otp/send', data: {
      'phone': phone,
      'purpose': purpose,
    });
  }

  /// Connexion sociale : le backend vérifie l'id_token (Google/Apple)
  /// et rattache ou crée le compte.
  Future<User> socialLogin({
    required String provider, // GOOGLE | APPLE
    required String idToken,
    String? firstName,
    String? lastName,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/social', data: {
      'provider': provider,
      'idToken': idToken,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    });
    return _persist(res.data!);
  }

  Future<User> verifyOtpLogin(String phone, String code) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/otp/verify', data: {
      'phone': phone,
      'purpose': 'LOGIN',
      'code': code,
    });
    return _persist(res.data!);
  }

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) {
      try {
        await _dio.post<void>('/auth/logout', data: {'refreshToken': refresh});
      } on DioException {
        // Déconnexion locale même si l'appel échoue
      }
    }
    await _storage.clear();
  }

  Future<User> _persist(Map<String, dynamic> data) async {
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userJson: user.encode(),
    );
    return user;
  }
}
