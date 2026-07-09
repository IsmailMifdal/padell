import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

/// Connexion par SMS : saisie du numéro → envoi OTP → saisie du code → tokens.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
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
      await ref.read(authRepositoryProvider).sendOtp(phone);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Code à 6 chiffres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtpLogin(_phone.text.trim(), _code.text.trim());
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion par SMS')),
      body: SafeArea(
        child: PageContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(_error!),
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
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : (_sent ? _verify : _sendCode),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_sent ? 'Valider le code' : 'Envoyer le code'),
              ),
              if (_sent)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _sent = false;
                            _code.clear();
                          }),
                  child: const Text('Changer de numéro'),
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
