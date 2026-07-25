import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/responsive.dart';
import 'auth_controller.dart';

/// Écran de départ : choix de l'espace (joueur ou propriétaire de club)
/// avant même la connexion, pour deux parcours bien distincts.
class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  void _choose(BuildContext context, WidgetRef ref, AppMode mode) {
    ref.read(pendingAuthModeProvider.notifier).state = mode;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PageContainer(
        maxWidth: 560,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('🎾', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PADEL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                const Text(
                  'Bienvenue 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vous êtes ?',
                  style: TextStyle(fontSize: 15, color: AppColors.slate),
                ),
                const SizedBox(height: 28),
                _RoleCard(
                  icon: Icons.sports_tennis_rounded,
                  title: 'Joueur',
                  subtitle: 'Réservez un terrain, trouvez un match, jouez.',
                  gradient: AppColors.heroGradient,
                  onTap: () => _choose(context, ref, AppMode.player),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.stadium_outlined,
                  title: 'Propriétaire de club',
                  subtitle:
                      'Gérez vos terrains, réservations, tarifs et statistiques.',
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.ink, Color(0xFF2A362F)],
                  ),
                  onTap: () => _choose(context, ref, AppMode.owner),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
