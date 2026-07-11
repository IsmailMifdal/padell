import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';

/// Réinitialisation du mot de passe par SMS (comptes avec téléphone).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _error;

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\+212[5-7]\d{8}$').hasMatch(phone)) {
      setState(() => _error = 'Numéro attendu au format +212XXXXXXXXX');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _dio.post<void>('/auth/otp/send', data: {
        'phone': phone,
        'purpose': 'RESET_PASSWORD',
      });
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Code à 6 chiffres');
      return;
    }
    if (_password.text.length < 8 ||
        !RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(_password.text)) {
      setState(() =>
          _error = 'Mot de passe : 8 caractères min., une lettre et un chiffre');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _dio.post<void>('/auth/password/reset', data: {
        'phone': _phone.text.trim(),
        'code': _code.text.trim(),
        'newPassword': _password.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mot de passe réinitialisé, connectez-vous ✅')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: PageContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ErrorBanner(_error!),
                const Text(
                  'Saisissez le numéro de téléphone associé à votre compte : '
                  'un code de vérification vous sera envoyé par SMS.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phone,
                  enabled: !_sent,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    hintText: '+212XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (_sent) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Code reçu par SMS',
                      prefixIcon: Icon(Icons.sms_outlined),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : (_sent ? _reset : _sendCode),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(_sent
                          ? 'Réinitialiser le mot de passe'
                          : 'Envoyer le code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
