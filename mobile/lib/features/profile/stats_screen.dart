import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import 'stats_favorites.dart';

/// Historique et statistiques du joueur.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes statistiques')),
      body: PageContainer(
        maxWidth: 640,
        child: stats.when(
          loading: () => const CenteredLoader(),
          error: (e, _) => ErrorRetry(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(playerStatsProvider),
          ),
          data: (s) {
            final winRate = s.matchesPlayed == 0
                ? 0
                : (s.wins / s.matchesPlayed * 100).round();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Niveau + ELO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _hero('Niveau', s.level.toStringAsFixed(1)),
                      _hero('ELO', '${s.eloRating}'),
                      _hero('Victoires', '$winRate %'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _tile('🎾', 'Matchs joués', '${s.matchesPlayed}')),
                    const SizedBox(width: 12),
                    Expanded(child: _tile('🏆', 'Victoires', '${s.wins}')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child:
                            _tile('📅', 'Réservations', '${s.bookingsCount}')),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _tile('🏟️', 'Clubs visités', '${s.clubsVisited}')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Notes reçues des partenaires',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (s.ratingsReceived == 0)
                  const Text(
                    'Aucune note pour l’instant — jouez des matchs pour en recevoir !',
                    style: TextStyle(color: AppColors.slate),
                  )
                else ...[
                  _ratingBar('Ponctualité', s.avgPunctuality ?? 0),
                  _ratingBar('Fair-play', s.avgFairplay ?? 0),
                  _ratingBar('Niveau annoncé', s.avgLevelAccuracy ?? 0),
                  const SizedBox(height: 4),
                  Text(
                    'Basé sur ${s.ratingsReceived} note(s)',
                    style:
                        const TextStyle(color: AppColors.slate, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(String label, String value) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      );

  Widget _tile(String emoji, String label, String value) => SoftCard(
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _ratingBar(String label, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value / 5,
                  minHeight: 8,
                  backgroundColor: AppColors.line,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}
