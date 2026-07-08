import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

/// Client HTTP basé sur dio.
///
/// - Ajoute automatiquement le jeton d'accès aux requêtes.
/// - Sur `401`, tente un refresh (rotation du refresh token) puis rejoue la
///   requête. Si le refresh échoue, purge la session et déclenche [onSessionExpired].
class ApiClient {
  ApiClient(this._storage, {this.onSessionExpired}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  late final Dio dio;
  late final Dio _refreshDio;
  final TokenStorage _storage;
  final void Function()? onSessionExpired;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.accessToken;
    if (token != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthCall = err.requestOptions.path.startsWith('/auth/');
    if (err.response?.statusCode != 401 ||
        isAuthCall ||
        err.requestOptions.extra['retried'] == true) {
      return handler.next(err);
    }

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      await _storage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      final token = await _storage.accessToken;
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token'
        ..extra['retried'] = true;
      final response = await dio.fetch<dynamic>(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data!;
      await _storage.updateAccessToken(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}

/// Extrait un message d'erreur lisible d'une [DioException].
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.join(', ') : msg.toString();
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Impossible de joindre le serveur';
    }
  }
  return 'Une erreur est survenue';
}
