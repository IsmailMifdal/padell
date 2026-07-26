import 'dart:io' show SocketException;

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

  /// Refresh en cours, partagé entre toutes les requêtes 401 simultanées.
  /// Indispensable : le refresh token est à rotation — deux refresh parallèles
  /// feraient échouer le second et déconnecteraient l'utilisateur.
  Future<bool>? _refreshing;

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

  Future<bool> _tryRefresh() {
    // Single-flight : les 401 concurrents attendent le même refresh.
    return _refreshing ??=
        _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
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

/// Vrai si l'erreur vient du réseau (et non d'un refus du serveur).
/// Sert à proposer « Réessayer » plutôt qu'un message définitif.
bool isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return true;
    case DioExceptionType.unknown:
      return error.error is SocketException;
    default:
      return false;
  }
}

/// Extrait un message d'erreur lisible d'une [DioException].
///
/// Le message du backend prime toujours (il est déjà en français et
/// contextuel) ; on ne retombe sur un texte générique qu'à défaut.
String apiErrorMessage(Object error) {
  // En debug, trace l'erreur réelle (ex : erreur de parse d'un modèle)
  assert(() {
    // ignore: avoid_print
    print('apiErrorMessage: $error');
    return true;
  }());

  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      return msg is List ? msg.join(', ') : msg.toString();
    }

    if (isNetworkError(error)) {
      return error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout
          ? 'Le serveur met trop de temps à répondre. Réessayez.'
          : 'Pas de connexion. Vérifiez votre réseau et réessayez.';
    }

    // Codes sans message métier : on explique quand même ce qui se passe
    final code = error.response?.statusCode;
    if (code != null) {
      if (code == 401 || code == 403) return 'Accès refusé. Reconnectez-vous.';
      if (code == 404) return 'Élément introuvable.';
      if (code == 409) return 'Ce créneau vient d’être pris. Choisissez-en un autre.';
      if (code >= 500) return 'Le serveur rencontre un problème. Réessayez dans un instant.';
    }
  }

  if (isNetworkError(error)) {
    return 'Pas de connexion. Vérifiez votre réseau et réessayez.';
  }
  return 'Une erreur est survenue';
}
