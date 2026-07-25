import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';
import 'auth_repository.dart';

enum AuthStage { unknown, authenticated, unauthenticated }

/// Espace choisi pour la session : joueur ou propriétaire de club.
/// Un même compte peut cumuler les deux rôles ; ce mode ne fait que
/// déterminer quelle interface est affichée, cf. écran `/welcome`.
enum AppMode { player, owner }

/// Mode sélectionné sur l'écran de départ, avant même la connexion —
/// lu par [AuthController] au moment où l'authentification aboutit.
final pendingAuthModeProvider = StateProvider<AppMode>((ref) => AppMode.player);

class AuthState {
  const AuthState(this.stage, {this.user, this.mode = AppMode.player});
  final AuthStage stage;
  final User? user;
  final AppMode mode;

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
      final savedMode = await storage.mode;
      state = AuthState(
        AuthStage.authenticated,
        user: User.decode(userJson),
        mode: savedMode == 'owner' ? AppMode.owner : AppMode.player,
      );
    } else {
      state = const AuthState(AuthStage.unauthenticated);
    }
  }

  /// Persiste le mode choisi et publie l'état authentifié — appelé après
  /// chaque connexion/inscription réussie, quelle que soit la méthode.
  Future<void> _finish(User user) async {
    final mode = ref.read(pendingAuthModeProvider);
    await ref.read(tokenStorageProvider).saveMode(mode.name);
    state = AuthState(AuthStage.authenticated, user: user, mode: mode);
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? city,
  }) async {
    final mode = ref.read(pendingAuthModeProvider);
    final user = await _repo.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      city: city,
      intent: mode == AppMode.owner ? 'OWNER' : null,
    );
    await _finish(user);
  }

  Future<void> login(String identifier, String password) async {
    final user = await _repo.login(identifier, password);
    await _finish(user);
  }

  Future<void> verifyOtpLogin(String phone, String code) async {
    final user = await _repo.verifyOtpLogin(phone, code);
    await _finish(user);
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
    await _finish(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(AuthStage.unauthenticated);
  }

  /// Bascule le mode d'une session déjà connectée (ex. depuis le profil ou
  /// le menu de l'espace propriétaire) — sans nouvelle connexion.
  Future<void> switchMode(AppMode mode) async {
    await ref.read(tokenStorageProvider).saveMode(mode.name);
    state = AuthState(state.stage, user: state.user, mode: mode);
  }

  /// Appelé par le client HTTP quand le refresh token n'est plus valide.
  void onSessionExpired() {
    state = const AuthState(AuthStage.unauthenticated);
  }
}
