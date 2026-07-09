import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../booking/home_screen.dart';
import 'matching_providers.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(nearbyMatchesProvider);
    final radius = ref.watch(matchRadiusProvider);
    final center = ref.watch(geoCenterProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/matches/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer un match'),
      ),
      body: SafeArea(
        bottom: false,
        child: PageContainer(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const ScreenHeader(
              title: 'Trouver un match',
              subtitle: 'Rejoignez des joueurs près de chez vous',
            ),
            const SizedBox(height: 12),
            // Zone + statut géoloc
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: center.maybeWhen(
                data: (c) => Row(
                  children: [
                    Icon(
                      c.isReal ? Icons.my_location : Icons.location_off,
                      size: 15,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.isReal
                            ? 'Autour de votre position'
                            : 'Position indisponible · zone Casablanca',
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 10),
            // Sélecteur de rayon
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [10.0, 25.0, 50.0, 100.0].map((r) {
                  final sel = radius == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(matchRadiusProvider.notifier).state = r,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.heroGradient : null,
                          color: sel ? null : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: softShadow(0.04),
                        ),
                        child: Text(
                          '${r.toInt()} km',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: sel ? Colors.white : AppColors.slate,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.when(
                loading: () => const CenteredLoader(),
                error: (e, _) => ErrorRetry(
                  message: apiErrorMessage(e),
                  onRetry: () => ref.invalidate(nearbyMatchesProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.groups_2_outlined,
                      title: 'Aucun match ouvert',
                      subtitle:
                          'Personne ne joue dans un rayon de ${radius.toInt()} km.\n'
                          'Élargissez la zone ou créez votre match.',
                    );
                  }
                  final wide = isWide(context);
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(nearbyMatchesProvider),
                    child: wide
                        ? GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isDesktop(context) ? 3 : 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: 152,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, i) =>
                                _MatchCard(match: list[i]),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, i) =>
                                _MatchCard(match: list[i]),
                          ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});
  final PadelMatch match;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => context.push('/matches/${match.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.coverFor(match.id),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sports_tennis, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.clubName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE d MMM · HH:mm', 'fr').format(match.startsAt),
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (match.distanceM != null)
                InfoChip(
                  label: '${(match.distanceM! / 1000).toStringAsFixed(1)} km',
                  icon: Icons.near_me,
                  color: AppColors.primaryDark,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _spots(match),
              const Spacer(),
              InfoChip(
                label: 'Niveau ${_lvl(match.levelMin)}–${_lvl(match.levelMax)}',
                icon: Icons.equalizer,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              Text(
                '${match.pricePerPlayerMad.toStringAsFixed(0)} MAD',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _lvl(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _spots(PadelMatch m) {
    return Row(
      children: [
        for (int i = 0; i < PadelMatch.size; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.person,
              size: 18,
              color: i < m.acceptedCount
                  ? AppColors.primary
                  : AppColors.line,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          m.spotsLeft == 0 ? 'Complet' : '${m.spotsLeft} place(s)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: m.spotsLeft == 0 ? AppColors.slate : AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}
