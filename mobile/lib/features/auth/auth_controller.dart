import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';
import 'auth_repository.dart';

enum AuthStage { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.stage, {this.user});
  final AuthStage stage;
  final User? user;

  bool get isAuthenticated => stage == AuthStage.authenticated;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState(AuthStage.unknown);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.accessToken;
    final userJson = await storage.userJson;
    if (token != null && userJson != null) {
      state = AuthState(AuthStage.authenticated, user: User.decode(userJson));
    } else {
      state = const AuthState(AuthStage.unauthenticated);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? city,
  }) async {
    final user = await _repo.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      city: city,
    );
    state = AuthState(AuthStage.authenticated, user: user);
  }

  Future<void> login(String identifier, String password) async {
    final user = await _repo.login(identifier, password);
    state = AuthState(AuthStage.authenticated, user: user);
  }

  Future<void> verifyOtpLogin(String phone, String code) async {
    final user = await _repo.verifyOtpLogin(phone, code);
    state = AuthState(AuthStage.authenticated, user: user);
  }

  Future<void> socialLogin({
    required String provider,
    required String idToken,
    String? firstName,
    String? lastName,
  }) async {
    final user = await _repo.socialLogin(
      provider: provider,
      idToken: idToken,
      firstName: firstName,
      lastName: lastName,
    );
    state = AuthState(AuthStage.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(AuthStage.unauthenticated);
  }

  /// Appelé par le client HTTP quand le refresh token n'est plus valide.
  void onSessionExpired() {
    state = const AuthState(AuthStage.unauthenticated);
  }
}
