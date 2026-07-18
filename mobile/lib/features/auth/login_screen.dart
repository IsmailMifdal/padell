import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_identifier.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ButtonStyle get _socialStyle => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.line),
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      );

  /// Bouton visible seulement si le client OAuth est configuré au build.
  bool get _googleEnabled => AppConfig.googleWebClientId.isNotEmpty;

  /// Apple Sign-In : iOS/macOS uniquement (obligatoire sur iOS, cf. stores).
  bool get _appleEnabled =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final google = GoogleSignIn(
        clientId: kIsWeb ? AppConfig.googleWebClientId : null,
        serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
      );
      final account = await google.signIn();
      if (account == null) return; // annulé par l'utilisateur
      final idToken = (await account.authentication).idToken;
      if (idToken == null) {
        setState(() => _error = 'Google n’a pas fourni de jeton, réessayez');
        return;
      }
      final names = account.displayName?.split(' ') ?? const [];
      await ref.read(authControllerProvider.notifier).socialLogin(
            provider: 'GOOGLE',
            idToken: idToken,
            firstName: names.isNotEmpty ? names.first : null,
            lastName: names.length > 1 ? names.sublist(1).join(' ') : null,
          );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        setState(() => _error = 'Apple n’a pas fourni de jeton, réessayez');
        return;
      }
      await ref.read(authControllerProvider.notifier).socialLogin(
            provider: 'APPLE',
            idToken: idToken,
            firstName: credential.givenName,
            lastName: credential.familyName,
          );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageContainer(
        maxWidth: 560,
        child: Column(
        children: [
          // Hero de marque : dégradé + halos décoratifs + wordmark
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  top: -40,
                  child: Container(
                    height: 190,
                    width: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  top: 70,
                  child: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lime.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                Positioned(
                  right: -10,
                  bottom: -26,
                  child: Icon(
                    Icons.sports_tennis,
                    size: 130,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 68, 28, 42),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wordmark
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('🎾',
                                  style: TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'PADEL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 3, top: 10),
                            height: 7,
                            width: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Jouez.\nRéservez.\nProgressez.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Le padel au Maroc, à portée de main.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Feuille de formulaire
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Connexion',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null) ErrorBanner(_error!),
                        TextFormField(
                          controller: _identifier,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Email ou téléphone',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Champ requis' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _loading ? null : () => context.push('/forgot'),
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GradientButton(
                          label: 'Se connecter',
                          loading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _loading ? null : () => context.push('/otp'),
                          icon: const Icon(Icons.sms_outlined, size: 20),
                          label: const Text('Continuer par SMS'),
                          style: _socialStyle,
                        ),
                        // Auth sociale : boutons affichés si configurés
                        if (_googleEnabled) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _googleLogin,
                            icon: const Text('G',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Color(0xFF4285F4),
                                )),
                            label: const Text('Continuer avec Google'),
                            style: _socialStyle,
                          ),
                        ],
                        if (_appleEnabled) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _appleLogin,
                            icon: const Icon(Icons.apple, size: 22),
                            label: const Text('Continuer avec Apple'),
                            style: _socialStyle,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Pas encore de compte ?',
                              style: TextStyle(color: AppColors.slate),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => context.push('/register'),
                              child: const Text('Créer un compte'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
