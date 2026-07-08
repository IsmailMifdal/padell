import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_providers.dart';

class ClubsScreen extends ConsumerWidget {
  const ClubsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(clubsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Filtrer par ville…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: ref.watch(clubSearchProvider) != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          ref.read(clubSearchProvider.notifier).state = null,
                    )
                  : null,
            ),
            onSubmitted: (v) => ref.read(clubSearchProvider.notifier).state =
                v.trim().isEmpty ? null : v.trim(),
          ),
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
                return const Center(child: Text('Aucun club trouvé.'));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(clubsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ClubCard(club: list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club});
  final Club club;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: const Text('🎾'),
        ),
        title: Text(
          club.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${club.address}\n${club.city}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (club.ratingAvg != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' ${club.ratingAvg!.toStringAsFixed(1)}'),
                ],
              ),
            if (club.distanceM != null)
              Text(
                '${(club.distanceM! / 1000).toStringAsFixed(1)} km',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
          ],
        ),
        onTap: () => context.push('/clubs/${club.id}', extra: club),
      ),
    );
  }
}
