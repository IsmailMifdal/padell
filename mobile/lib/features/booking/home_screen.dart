import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../auth/auth_controller.dart';
import '../matching/matches_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_repository.dart';
import 'clubs_screen.dart';
import 'my_bookings_screen.dart';

/// Onglet actif de l'accueil (permet aux écrans de changer d'onglet).
final homeTabProvider = StateProvider<int>((ref) => 0);

/// Écran principal après connexion : navigation par onglets.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    ClubsScreen(),
    MatchesScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    final body = IndexedStack(index: index, children: _tabs);
    void select(int i) => ref.read(homeTabProvider.notifier).state = i;
    final t = T.of(ref.watch(localeProvider));

    // Badge de notifications non lues sur l'onglet Profil
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final profileIcon = unread > 0
        ? Badge(
            label: Text('$unread'),
            backgroundColor: AppColors.danger,
            child: const Icon(Icons.person_outline),
          )
        : const Icon(Icons.person_outline);
    final profileIconSelected = unread > 0
        ? Badge(
            label: Text('$unread'),
            backgroundColor: AppColors.danger,
            child: const Icon(Icons.person),
          )
        : const Icon(Icons.person);

    // Grand écran (web/desktop) : rail de navigation latéral
    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: select,
              extended: isDesktop(context),
              minExtendedWidth: 190,
              backgroundColor: Theme.of(context).colorScheme.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.14),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('🎾', style: TextStyle(fontSize: 30)),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.search_outlined),
                  selectedIcon: const Icon(Icons.search),
                  label: Text(t['clubs']),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.groups_2_outlined),
                  selectedIcon: const Icon(Icons.groups_2),
                  label: Text(t['matches']),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.confirmation_number_outlined),
                  selectedIcon: const Icon(Icons.confirmation_number),
                  label: Text(t['bookingsLong']),
                ),
                NavigationRailDestination(
                  icon: profileIcon,
                  selectedIcon: profileIconSelected,
                  label: Text(t['profile']),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Mobile : barre de navigation en bas
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: t['clubs'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_2_outlined),
            selectedIcon: const Icon(Icons.groups_2),
            label: t['matches'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.confirmation_number_outlined),
            selectedIcon: const Icon(Icons.confirmation_number),
            label: t['bookings'],
          ),
          NavigationDestination(
            icon: profileIcon,
            selectedIcon: profileIconSelected,
            label: t['profile'],
          ),
        ],
      ),
    );
  }
}

/// En-tête de section réutilisable (titre + sous-titre) pour les onglets simples.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.slate, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = T.of(ref.watch(localeProvider));
    final me = ref.watch(meProvider).valueOrNull;
    final fallback = ref.watch(authControllerProvider).user;
    final firstName = me?.firstName ?? fallback?.firstName ?? '';
    final fullName = me?.fullName ?? fallback?.fullName ?? '';
    final contact = me?.email ?? me?.phone ?? fallback?.email ?? '';
    final initial = firstName.isEmpty ? '?' : firstName[0].toUpperCase();

    return PageContainer(
      maxWidth: 720,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // En-tête dégradé avec avatar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: const EdgeInsets.only(bottom: 24),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      height: 92,
                      width: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (me != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stat('Niveau',
                              me.level?.toStringAsFixed(1) ?? '—'),
                          const SizedBox(width: 10),
                          _stat('Matchs', '${me.matchesPlayed}'),
                          if (me.city != null && me.city!.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            _stat('Ville', me.city!),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (me?.isOwner == true)
                    _ProfileTile(
                      icon: Icons.stadium_outlined,
                      label: t['clubSpace'],
                      onTap: () => context.push('/owner'),
                    ),
                  _ProfileTile(
                    icon: Icons.event_available_outlined,
                    label: t['myBookings'],
                    onTap: () =>
                        ref.read(homeTabProvider.notifier).state = 2,
                  ),
                  _ProfileTile(
                    icon: Icons.sports_tennis_outlined,
                    label: t['myGameProfile'],
                    onTap: () => context.push('/profile/edit'),
                  ),
                  _ProfileTile(
                    icon: Icons.bar_chart_rounded,
                    label: t['myStats'],
                    onTap: () => context.push('/profile/stats'),
                  ),
                  _ProfileTile(
                    icon: Icons.notifications_none_rounded,
                    label: t['notifications'],
                    onTap: () => context.push('/notifications'),
                  ),
                  _ProfileTile(
                    icon: Icons.translate_rounded,
                    label: t['language'],
                    onTap: () => _pickLanguage(context, ref),
                  ),
                  _ProfileTile(
                    icon: Icons.help_outline_rounded,
                    label: t['help'],
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Aide & support'),
                        content: const Text(
                          'Une question, un souci de réservation ou de '
                          'paiement ?\n\nÉcrivez-nous : support@padel.ma\n'
                          'Nous répondons sous 24 h.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 20),
                    label: Text(t['logout']),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de langue (fr / ar RTL / en).
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    const names = {'fr': 'Français', 'ar': 'العربية', 'en': 'English'};
    final current = ref.read(localeProvider).languageCode;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Langue · اللغة · Language'),
        children: names.entries
            .map(
              (e) => ListTile(
                leading: Icon(
                  e.key == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: e.key == current ? AppColors.primary : AppColors.slate,
                ),
                title: Text(e.value),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            )
            .toList(),
      ),
    );
    if (choice != null) {
      await ref.read(localeProvider.notifier).set(Locale(choice));
    }
  }

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
