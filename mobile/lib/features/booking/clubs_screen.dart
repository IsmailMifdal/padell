import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'booking_providers.dart';

class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clubs = ref.watch(clubsProvider);
    final user = ref.watch(authControllerProvider).user;
    final firstName = user?.firstName ?? '';

    return Column(
      children: [
        _Header(
          firstName: firstName,
          controller: _searchCtrl,
          onSearch: (v) => ref.read(clubSearchProvider.notifier).state =
              v.trim().isEmpty ? null : v.trim(),
          onClear: () {
            _searchCtrl.clear();
            ref.read(clubSearchProvider.notifier).state = null;
          },
        ),
        Expanded(
          child: clubs.when(
            loading: () => const CenteredLoader(),
            error: (e, _) => ErrorRetry(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(clubsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Aucun club trouvé',
                  subtitle: 'Essayez une autre ville ou effacez le filtre.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(clubsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Clubs disponibles',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${list.length}',
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _ClubCard(club: list[i - 1]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final String firstName;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              firstName.isEmpty ? 'Bonjour 👋' : 'Bonjour, $firstName 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Où jouez-vous aujourd’hui ?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 0,
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Rechercher une ville…',
                  prefixIcon: const Icon(Icons.search, color: AppColors.slate),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: onClear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});
  final Club club;

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.coverFor(club.id);
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/clubs/${club.id}', extra: club),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Couverture
          Container(
            height: 116,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12,
                  bottom: -18,
                  child: Icon(
                    Icons.sports_tennis,
                    size: 110,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  club.city,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (club.ratingAvg != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 15, color: AppColors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    club.ratingAvg!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Corps
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 14, color: AppColors.slate),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              club.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (club.distanceM != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${(club.distanceM! / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: AppColors.slate,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_forward,
                      color: AppColors.primaryDark, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
