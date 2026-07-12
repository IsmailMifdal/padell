import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../profile/stats_favorites.dart';
import 'booking_providers.dart';

/// Affichage carte (true) ou liste (false).
final clubsMapViewProvider = StateProvider<bool>((ref) => false);

/// Filtre : ne montrer que mes clubs favoris.
final favoritesOnlyProvider = StateProvider<bool>((ref) => false);

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
    final mapView = ref.watch(clubsMapViewProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final favoriteIds =
        ref.watch(favoriteClubIdsProvider).valueOrNull ?? const <String>{};

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
        // Bascule liste/carte + filtre favoris
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: PageContainer(
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.list, size: 17),
                        label: Text('Liste'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.map_outlined, size: 17),
                        label: Text('Carte'),
                      ),
                    ],
                    selected: {mapView},
                    onSelectionChanged: (s) => ref
                        .read(clubsMapViewProvider.notifier)
                        .state = s.first,
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('❤ Favoris'),
                  selected: favoritesOnly,
                  selectedColor: AppColors.danger.withValues(alpha: 0.15),
                  onSelected: (v) =>
                      ref.read(favoritesOnlyProvider.notifier).state = v,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: clubs.when(
            loading: () => const CenteredLoader(),
            error: (e, _) => ErrorRetry(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(clubsProvider),
            ),
            data: (all) {
              final list = favoritesOnly
                  ? all.where((c) => favoriteIds.contains(c.id)).toList()
                  : all;
              if (list.isEmpty) {
                return EmptyState(
                  icon: favoritesOnly
                      ? Icons.favorite_border
                      : Icons.location_off_outlined,
                  title: favoritesOnly
                      ? 'Aucun club favori'
                      : 'Aucun club trouvé',
                  subtitle: favoritesOnly
                      ? 'Touchez le cœur d’un club pour l’ajouter ici.'
                      : 'Essayez une autre ville ou effacez le filtre.',
                );
              }
              if (mapView) {
                return _ClubsMap(clubs: list);
              }
              final title = Padding(
                padding: const EdgeInsets.only(bottom: 14),
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

              final wide = isWide(context);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(clubsProvider),
                child: PageContainer(
                  child: wide
                      // Grille 2-3 colonnes sur écran large
                      ? CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              sliver: SliverToBoxAdapter(child: title),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 28),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isDesktop(context) ? 3 : 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: 216,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _ClubCard(club: list[i]),
                                  childCount: list.length,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          itemCount: list.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, i) {
                            if (i == 0) return title;
                            return _ClubCard(club: list[i - 1]);
                          },
                        ),
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
        child: PageContainer(
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
      ),
    );
  }
}

/// Carte OpenStreetMap des clubs (sans clé API).
class _ClubsMap extends ConsumerWidget {
  const _ClubsMap({required this.clubs});
  final List<Club> clubs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(geoCenterProvider).valueOrNull;
    final located = clubs
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();
    final mapCenter = located.isNotEmpty
        ? LatLng(located.first.latitude!, located.first.longitude!)
        : LatLng(center?.lat ?? 33.5899, center?.lng ?? -7.6039);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: PageContainer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FlutterMap(
            options: MapOptions(initialCenter: mapCenter, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ma.padel.padel_mobile',
              ),
              MarkerLayer(
                markers: [
                  if (center != null && center.isReal)
                    Marker(
                      point: LatLng(center.lat, center.lng),
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.my_location,
                          color: AppColors.info, size: 22),
                    ),
                  ...located.map(
                    (c) => Marker(
                      point: LatLng(c.latitude!, c.longitude!),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/clubs/${c.id}', extra: c),
                        child: Tooltip(
                          message: c.name,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: softShadow(0.25),
                            ),
                            child: const Icon(Icons.sports_tennis,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubCard extends ConsumerWidget {
  const _ClubCard({required this.club});
  final Club club;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = AppColors.coverFor(club.id);
    final favoriteIds =
        ref.watch(favoriteClubIdsProvider).valueOrNull ?? const <String>{};
    final isFavorite = favoriteIds.contains(club.id);

    Future<void> toggleFavorite() async {
      final repo = ref.read(favoritesRepositoryProvider);
      try {
        isFavorite ? await repo.remove(club.id) : await repo.add(club.id);
        ref.invalidate(favoriteClubIdsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiErrorMessage(e))),
          );
        }
      }
    }
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (club.ratingAvg != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
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
                              // Cœur favori
                              GestureDetector(
                                onTap: toggleFavorite,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 17,
                                    color: isFavorite
                                        ? AppColors.danger
                                        : AppColors.slate,
                                  ),
                                ),
                              ),
                            ],
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
