import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/auth_controller.dart';
import 'api_client.dart';
import 'token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
