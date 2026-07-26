import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/notifications_screen.dart';

/// Fournit le jeton d'appareil utilisé pour les notifications push.
///
/// Abstrait volontairement : l'app ne dépend pas directement de Firebase.
/// Brancher FCM revient à fournir une implémentation qui appelle
/// `FirebaseMessaging.instance.getToken()` — le reste du circuit est déjà là.
abstract class PushTokenSource {
  Future<String?> getToken();
}

/// Repli utilisé tant qu'aucun fournisseur n'est configuré.
///
/// Ne renvoie aucun jeton : l'app fonctionne normalement, simplement sans
/// push distants. Les notifications *locales* (rappels) continuent, elles,
/// de fonctionner — elles ne dépendent d'aucun service tiers.
class NoopPushTokenSource implements PushTokenSource {
  const NoopPushTokenSource();

  @override
  Future<String?> getToken() async {
    debugPrint(
      'PushService : aucun fournisseur de jeton configuré — '
      'push distants inactifs (voir docs/08-push-firebase.md). '
      'Les rappels locaux restent actifs.',
    );
    return null;
  }
}

/// Remplacer cette valeur par une source FCM pour activer les push.
final pushTokenSourceProvider =
    Provider<PushTokenSource>((ref) => const NoopPushTokenSource());

/// Enregistre l'appareil auprès du backend après connexion.
///
/// Idempotent côté serveur : réenregistrer le même jeton ne crée pas de
/// doublon. Toute erreur est avalée — ne pas recevoir de push est gênant,
/// mais ne doit jamais bloquer l'usage de l'app.
class PushService {
  PushService(this._ref);

  final Ref _ref;

  Future<void> registerCurrentDevice() async {
    if (kIsWeb) return; // les push web exigent une configuration distincte

    try {
      final token = await _ref.read(pushTokenSourceProvider).getToken();
      if (token == null || token.isEmpty) return;

      final platform = Platform.isIOS ? 'ios' : 'android';
      await _ref
          .read(notificationsRepositoryProvider)
          .registerDevice(token, platform);
      debugPrint('PushService : appareil enregistré ($platform)');
    } catch (e) {
      debugPrint('PushService.registerCurrentDevice: $e');
    }
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
