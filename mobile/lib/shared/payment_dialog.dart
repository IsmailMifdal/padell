import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/palette.dart';
import 'payments_api.dart';

/// Feuille de paiement CMI : crée la session puis propose de finaliser.
///
/// En production, le formulaire retourné par l'API est posté vers la page
/// bancaire CMI (webview). En développement, un bouton permet de simuler
/// le paiement réussi pour tester la boucle complète.
///
/// Retourne `true` si le paiement a été finalisé (simulation dev).
Future<bool> showPaymentSheet({
  required BuildContext context,
  required PaymentsApi api,
  required double amountMad,
  required Future<Map<String, dynamic>> Function() createSession,
}) async {
  final Map<String, dynamic> session;
  try {
    session = await createSession();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    rethrow;
  }
  if (!context.mounted) return false;

  final fields = (session['fields'] ?? {}) as Map<String, dynamic>;
  final oid = (fields['oid'] ?? '') as String;

  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PaymentSheet(api: api, amountMad: amountMad, oid: oid),
  );
  return paid == true;
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.api,
    required this.amountMad,
    required this.oid,
  });

  final PaymentsApi api;
  final double amountMad;
  final String oid;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _simulate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.simulateDev(widget.oid);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Simulation impossible (indisponible en production)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 5,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Paiement sécurisé CMI',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant', style: TextStyle(color: AppColors.slate)),
                Text(
                  '${widget.amountMad.toStringAsFixed(0)} MAD',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commande ${widget.oid}',
            style: const TextStyle(fontSize: 12, color: AppColors.slate),
          ),
          const SizedBox(height: 12),
          const Text(
            'La session de paiement est créée. En production, vous seriez '
            'redirigé vers la page bancaire sécurisée du CMI.',
            style: TextStyle(fontSize: 13, color: AppColors.slate),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          if (kDebugMode)
            FilledButton.icon(
              onPressed: _busy ? null : _simulate,
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.bolt, size: 20),
              label: const Text('Payer maintenant (simulation dev)'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
