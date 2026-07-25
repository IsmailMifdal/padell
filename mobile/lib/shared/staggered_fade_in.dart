import 'package:flutter/material.dart';

/// Entrée en cascade pour les listes (source : ui-ux-pro-max, catalogue
/// motion « Stagger List — Subtle » : 250-350ms, easing doux, délai
/// 20-40ms/item plafonné pour éviter un déroulé trop long sur les longues
/// listes — cf. règle « ne pas dépasser 0.1s/item, ça devient lent »).
///
/// Usage : envelopper chaque carte de liste avec `StaggeredFadeIn(index: i, ...)`.
class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  /// Délai par item plafonné aux 8 premiers — au-delà, tout arrive ensemble
  /// (sinon la 20e carte d'une longue liste apparaîtrait après 1 seconde).
  static const _stepMs = 40;
  static const _maxSteps = 8;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, _maxSteps)) * _stepMs;
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
