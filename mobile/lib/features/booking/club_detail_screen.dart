import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';

class ClubDetailScreen extends ConsumerStatefulWidget {
  const ClubDetailScreen({super.key, required this.club});
  final Club club;

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  late DateTime _day;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  Future<void> _book(Slot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réservation'),
        content: Text(
          '${widget.club.name}\n'
          '${slot.courtName} · ${DateFormat('EEEE d MMM', 'fr').format(slot.startsAt)} '
          'à ${DateFormat('HH:mm').format(slot.startsAt)}\n'
          '${slot.durationMin} min · ${slot.priceMad.toStringAsFixed(0)} MAD\n\n'
          'Paiement sur place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _booking = true);
    try {
      await ref.read(bookingRepositoryProvider).book(slot);
      ref.invalidate(myBookingsProvider);
      ref.invalidate(
        availabilityProvider((clubId: widget.club.id, day: _day)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation confirmée ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (clubId: widget.club.id, day: _day);
    final slots = ref.watch(availabilityProvider(args));

    return Scaffold(
      appBar: AppBar(title: Text(widget.club.name)),
      body: Column(
        children: [
          _DateStrip(
            selected: _day,
            onSelect: (d) => setState(() => _day = d),
          ),
          const Divider(height: 1),
          Expanded(
            child: slots.when(
              loading: () => const CenteredLoader(),
              error: (e, _) => ErrorRetry(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(availabilityProvider(args)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Aucun créneau disponible ce jour.'),
                  );
                }
                return AbsorbPointer(
                  absorbing: _booking,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.sports_tennis),
                          title: Text(
                            '${DateFormat('HH:mm').format(s.startsAt)} – '
                            '${DateFormat('HH:mm').format(s.endsAt)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${s.courtName} · ${s.durationMin} min'),
                          trailing: FilledButton.tonal(
                            onPressed: () => _book(s),
                            child: Text('${s.priceMad.toStringAsFixed(0)} MAD'),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau horizontal des 14 prochains jours.
class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelect});
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: 14,
        itemBuilder: (context, i) {
          final d = DateTime(today.year, today.month, today.day + i);
          final isSel = d == selected;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr').format(d).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSel ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSel ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
