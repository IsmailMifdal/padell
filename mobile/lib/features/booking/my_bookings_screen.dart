import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    return bookings.when(
      loading: () => const CenteredLoader(),
      error: (e, _) => ErrorRetry(
        message: apiErrorMessage(e),
        onRetry: () => ref.invalidate(myBookingsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('Vous n’avez aucune réservation.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myBookingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BookingCard(booking: list[i]),
          ),
        );
      },
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  ({Color bg, Color fg, String label}) _statusStyle(ColorScheme s) {
    switch (booking.status) {
      case 'CONFIRMED':
        return (bg: s.primaryContainer, fg: s.onPrimaryContainer, label: 'Confirmée');
      case 'PENDING_PAYMENT':
        return (bg: s.tertiaryContainer, fg: s.onTertiaryContainer, label: 'À payer');
      case 'COMPLETED':
        return (bg: s.secondaryContainer, fg: s.onSecondaryContainer, label: 'Terminée');
      case 'CANCELLED':
        return (bg: s.errorContainer, fg: s.onErrorContainer, label: 'Annulée');
      default:
        return (bg: s.surfaceContainerHighest, fg: s.onSurface, label: booking.status);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text(
          'Le remboursement éventuel suit la politique du club.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler la résa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(booking.id);
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final st = _statusStyle(scheme);
    final canCancel =
        booking.status == 'CONFIRMED' || booking.status == 'PENDING_PAYMENT';
    final upcoming = booking.startsAt.isAfter(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.clubName ?? 'Club',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    st.label,
                    style: TextStyle(
                      color: st.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE d MMM · HH:mm', 'fr').format(booking.startsAt),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.sports_tennis, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Text(
                  '${booking.courtName ?? ''} · '
                  '${booking.priceMad.toStringAsFixed(0)} MAD',
                ),
              ],
            ),
            if (booking.status == 'CONFIRMED' && booking.qrCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Code de check-in',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SelectableText(
                            booking.qrCode!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (canCancel && upcoming) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancel(context, ref),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Annuler'),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
