import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';

/// Liens profonds : ouvrir l'app directement sur un match ou un club.
///
/// Deux formes acceptées :
///  - schéma privé  `padel://match/<id>` — utilisé par les notifications ;
///  - lien web      `https://<domaine>/match/<id>` — partageable sur WhatsApp,
///    et qui reste cliquable même si l'app n'est pas installée.
///
/// Sans cela, le bouton « Partager » envoyait un texte sans lien : le
/// destinataire n'avait aucun moyen de rejoindre le match.
class DeepLinks {
  DeepLinks._();

  static StreamSubscription<Uri>? _sub;

  /// Destination demandée avant d'être connecté, rejouée après connexion.
  static String? _pending;

  /// Routes qui valent la peine d'être mémorisées le temps de se connecter.
  static bool _isShareable(String route) =>
      route.startsWith('/matches/') || route.startsWith('/clubs/');

  /// Mémorise la cible d'un lien ouvert par un utilisateur non connecté.
  static void remember(String route) {
    if (_isShareable(route)) _pending = route;
  }

  /// Récupère (et oublie) la destination mise de côté.
  static String? takePending() {
    final route = _pending;
    _pending = null;
    return route;
  }

  /// Construit le lien partageable d'un match.
  static String matchUrl(String matchId) => '${AppConfig.publicWebUrl}/match/$matchId';

  /// Traduit une URL entrante en route interne, ou null si non reconnue.
  ///
  /// Volontairement tolérant sur la forme : `padel://match/1` place « match »
  /// dans l'hôte, alors que `https://site/match/1` le place dans le chemin.
  static String? routeFor(Uri uri) {
    final segments = [
      if (uri.scheme == 'padel' && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();

    if (segments.length < 2) return null;
    final id = segments[1];
    switch (segments[0]) {
      case 'match':
      case 'matches':
        return '/matches/$id';
      case 'club':
      case 'clubs':
        return '/clubs/$id';
      default:
        return null;
    }
  }

  /// Démarre l'écoute des liens (démarrage à froid + app déjà ouverte).
  static Future<void> init(GoRouter router) async {
    // Le web gère déjà ses URL nativement via l'historique du navigateur.
    if (kIsWeb) return;

    final links = AppLinks();

    void handle(Uri uri) {
      final route = routeFor(uri);
      if (route != null) router.go(route);
    }

    try {
      final initial = await links.getInitialLink();
      if (initial != null) handle(initial);
    } catch (_) {
      // Lien de démarrage illisible : l'app s'ouvre normalement sur l'accueil
    }

    await _sub?.cancel();
    _sub = links.uriLinkStream.listen(
      handle,
      onError: (_) {
        // Un lien malformé ne doit pas faire tomber l'app
      },
    );
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
