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
import '../notifications/notifications_screen.dart';
import '../profile/profile_repository.dart';
import '../profile/stats_favorites.dart';
import 'booking_providers.dart';

/// Affichage carte (true) ou liste (false).
final clubsMapViewProvider = StateProvider<bool>((ref) => false);

/// Tri de la liste : distance (défaut) ou note.
final clubsSortProvider = StateProvider<String>((ref) => 'distance');

/// Filtre : ne montrer que mes clubs favoris.
final favoritesOnlyProvider = StateProvider<bool>((ref) => false);

const _amenityIcons = <String, IconData>{
  'parking': Icons.local_parking,
  'douches': Icons.shower_outlined,
  'vestiaires': Icons.checkroom,
  'cafétéria': Icons.local_cafe_outlined,
  'wifi': Icons.wifi,
  'location de matériel': Icons.sports_tennis,
};

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
    final mapView = ref.watch(clubsMapViewProvider);
    final sort = ref.watch(clubsSortProvider);
    final favoritesOnly = ref.watch(favoritesOnlyProvider);
    final favoriteIds =
        ref.watch(favoriteClubIdsProvider).valueOrNull ?? const <String>{};

    return Column(
      children: [
        _Header(
          controller: _searchCtrl,
          onSearch: (v) => ref.read(clubSearchProvider.notifier).state =
              v.trim().isEmpty ? null : v.trim(),
          onClear: () {
            _searchCtrl.clear();
            ref.read(clubSearchProvider.notifier).state = null;
          },
        ),
        // Barre d'outils : tris + favoris + bascule liste/carte
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: PageContainer(
            child: Row(
              children: [
                _SortChip(
                  label: 'Proches',
                  icon: Icons.near_me_outlined,
                  selected: sort == 'distance' && !favoritesOnly,
                  onTap: () {
                    ref.read(clubsSortProvider.notifier).state = 'distance';
                    ref.read(favoritesOnlyProvider.notifier).state = false;
                  },
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Mieux notés',
                  icon: Icons.star_outline_rounded,
                  selected: sort == 'rating' && !favoritesOnly,
                  onTap: () {
                    ref.read(clubsSortProvider.notifier).state = 'rating';
                    ref.read(favoritesOnlyProvider.notifier).state = false;
                  },
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Favoris',
                  icon: Icons.favorite_border,
                  selected: favoritesOnly,
                  accent: AppColors.danger,
                  onTap: () => ref.read(favoritesOnlyProvider.notifier).state =
                      !favoritesOnly,
                ),
                const Spacer(),
                // Bascule liste / carte
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: softShadow(0.05),
                  ),
                  child: Row(
                    children: [
                      _ViewToggle(
                        icon: Icons.view_agenda_outlined,
                        selected: !mapView,
                        onTap: () => ref
                            .read(clubsMapViewProvider.notifier)
                            .state = false,
                      ),
                      _ViewToggle(
                        icon: Icons.map_outlined,
                        selected: mapView,
                        onTap: () => ref
                            .read(clubsMapViewProvider.notifier)
                            .state = true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: clubs.when(
            loading: () => const _SkeletonList(),
            error: (e, _) => ErrorRetry(
              message: apiErrorMessage(e),
              onRetry: () => ref.invalidate(clubsProvider),
            ),
            data: (all) {
              var list = favoritesOnly
                  ? all.where((c) => favoriteIds.contains(c.id)).toList()
                  : List.of(all);
              if (sort == 'rating') {
                list.sort((a, b) =>
                    (b.ratingAvg ?? 0).compareTo(a.ratingAvg ?? 0));
              } else {
                list.sort((a, b) => (a.distanceM ?? double.infinity)
                    .compareTo(b.distanceM ?? double.infinity));
              }

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
              if (mapView) return _ClubsMap(clubs: list);

              final wide = isWide(context);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(clubsProvider),
                child: PageContainer(
                  child: wide
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop(context) ? 3 : 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            mainAxisExtent: 248,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              _ClubCard(club: list[i]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, i) =>
                              _ClubCard(club: list[i]),
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

// -------------------------------------------------------------------- header

class _Header extends ConsumerWidget {
  const _Header({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final fallback = ref.watch(authControllerProvider).user;
    final firstName = me?.firstName ?? fallback?.firstName ?? '';
    final initial = firstName.isEmpty ? '🎾' : firstName[0].toUpperCase();
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final searching = ref.watch(clubSearchProvider) != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: SafeArea(
        bottom: false,
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Avatar + salutation + cloche
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      image: me?.avatarUrl == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(me!.avatarUrl!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: me?.avatarUrl != null
                        ? null
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName.isEmpty
                              ? 'Bonjour 👋'
                              : 'Bonjour, $firstName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Trouvez votre terrain de padel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notifications
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: unread > 0
                          ? Badge(
                              label: Text('$unread'),
                              backgroundColor: AppColors.danger,
                              child: const Icon(Icons.notifications_none,
                                  color: Colors.white, size: 22),
                            )
                          : const Icon(Icons.notifications_none,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Recherche
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Ville, quartier…',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.slate),
                    suffixIcon: searching
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: onClear,
                          )
                        : null,
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

// ------------------------------------------------------------- barre d'outils

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? accent : AppColors.slate),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? accent : AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.heroGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 19,
          color: selected ? Colors.white : AppColors.slate,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- squelettes

/// Squelettes de chargement animés (effet « pulse »), plus pro qu'un spinner.
class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return PageContainer(
      child: FadeTransition(
        opacity: _pulse,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => Container(
            height: 230,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.line.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppColors.line.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 12,
                        width: 240,
                        decoration: BoxDecoration(
                          color: AppColors.line.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- carte

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
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
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

// -------------------------------------------------------------- carte de club

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
      radius: 22,
      onTap: () => context.push('/clubs/${club.id}', extra: club),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Couverture illustrée
          Container(
            height: 118,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Filet stylisé en fond
                Positioned(
                  right: -14,
                  bottom: -20,
                  child: Icon(
                    Icons.sports_tennis,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Positioned(
                  left: -30,
                  top: -30,
                  child: Container(
                    height: 110,
                    width: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ville (verre dépoli)
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (club.ratingAvg != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: AppColors.amber),
                              const SizedBox(width: 3),
                              Text(
                                club.ratingAvg!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Cœur favori
                      GestureDetector(
                        onTap: toggleFavorite,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: isFavorite
                                ? AppColors.danger
                                : AppColors.slate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Distance en bas de la couverture
                if (club.distanceM != null)
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${(club.distanceM! / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Corps de carte
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // CTA réserver
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Réserver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                            color: AppColors.slate, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                // Équipements
                if (club.amenities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...club.amenities.take(4).map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Tooltip(
                                message: a,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    _amenityIcons[a] ?? Icons.check,
                                    size: 15,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      if (club.amenities.length > 4)
                        Text(
                          '+${club.amenities.length - 4}',
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
