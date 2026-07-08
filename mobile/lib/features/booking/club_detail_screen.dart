import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
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
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmSheet(club: widget.club, slot: slot),
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
    final gradient = AppColors.coverFor(widget.club.id);

    return Scaffold(
      body: Column(
        children: [
          // Hero
          Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        Icon(Icons.sports_tennis,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.club.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${widget.club.address} · ${widget.club.city}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
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
            ),
          ),
          _DateStrip(
            selected: _day,
            onSelect: (d) => setState(() => _day = d),
          ),
          Expanded(
            child: slots.when(
              loading: () => const CenteredLoader(),
              error: (e, _) => ErrorRetry(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(availabilityProvider(args)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Complet ce jour-là',
                    subtitle: 'Aucun créneau disponible.\nEssayez un autre jour.',
                  );
                }
                return AbsorbPointer(
                  absorbing: _booking,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${list.length} créneau${list.length > 1 ? 'x' : ''} disponible${list.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }
                      return _SlotTile(slot: list[i - 1], onBook: _book);
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

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onBook});
  final Slot slot;
  final ValueChanged<Slot> onBook;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      onTap: () => onBook(slot),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.schedule,
                color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('HH:mm').format(slot.startsAt)} – '
                  '${DateFormat('HH:mm').format(slot.endsAt)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slot.courtName} · ${slot.durationMin} min',
                  style: const TextStyle(color: AppColors.slate, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${slot.priceMad.toStringAsFixed(0)} MAD',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Réserver',
                style: TextStyle(color: AppColors.slate, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bandeau horizontal des 14 prochains jours (pastilles).
class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelect});
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: 14,
        itemBuilder: (context, i) {
          final d = DateTime(today.year, today.month, today.day + i);
          final isSel = d == selected;
          return GestureDetector(
            onTap: () => onSelect(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: isSel ? AppColors.heroGradient : null,
                color: isSel ? null : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSel ? softShadow(0.12) : softShadow(0.04),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0
                        ? 'AUJ'
                        : DateFormat('E', 'fr').format(d).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : AppColors.ink,
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

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.club, required this.slot});
  final Club club;
  final Slot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 5,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Confirmer la réservation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _row(Icons.stadium_outlined, club.name),
          _row(Icons.sports_tennis, slot.courtName),
          _row(
            Icons.event,
            '${DateFormat('EEEE d MMM', 'fr').format(slot.startsAt)} · '
            '${DateFormat('HH:mm').format(slot.startsAt)}–${DateFormat('HH:mm').format(slot.endsAt)}',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total (paiement sur place)',
                    style: TextStyle(color: AppColors.slate)),
                Text(
                  '${slot.priceMad.toStringAsFixed(0)} MAD',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer ma réservation'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
