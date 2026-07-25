import 'package:flutter/services.dart';

/// Retour haptique sur les actions clés (audit ui-ux-pro-max — Interaction §2).
/// Usage discipliné : uniquement sur les confirmations et bascules d'état,
/// jamais sur chaque tap (règle « Don't overuse vibration feedback »).
class Haptics {
  Haptics._();

  /// Bascule d'état légère (favori, sélection d'onglet/segment).
  static void select() => HapticFeedback.selectionClick();

  /// Confirmation d'action (réserver, rejoindre, payer, accepter).
  static void confirm() => HapticFeedback.lightImpact();

  /// Action destructive ou refus (annuler, refuser, supprimer).
  static void warn() => HapticFeedback.mediumImpact();
}
