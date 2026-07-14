import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/responsive.dart';
import '../../shared/models.dart';
import '../../shared/widgets.dart';
import 'booking_providers.dart';
import 'booking_repository.dart';
import 'home_screen.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    return SafeArea(
      bottom: false,
      child: PageContainer(
        maxWidth: 860,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const ScreenHeader(
            title: 'Mes réservations',
            subtitle: 'Vos terrains réservés et leur QR d’accès',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bookings.when(
              loading: () => const CenteredLoader(),
              error: (e, _) => ErrorRetry(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(myBookingsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Aucune réservation',
                    subtitle:
                        'Réservez un terrain depuis l’onglet Clubs\npour le voir apparaître ici.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myBookingsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _BookingCard(booking: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  ({Color color, String label, IconData icon}) _status() {
    switch (booking.status) {
      case 'CONFIRMED':
        return (color: AppColors.primary, label: 'Confirmée', icon: Icons.check_circle);
      case 'PENDING_PAYMENT':
        return (color: AppColors.amber, label: 'À payer', icon: Icons.schedule);
      case 'COMPLETED':
        return (color: AppColors.info, label: 'Terminée', icon: Icons.done_all);
      case 'CANCELLED':
        return (color: AppColors.danger, label: 'Annulée', icon: Icons.cancel);
      default:
        return (color: AppColors.slate, label: booking.status, icon: Icons.info);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
    final st = _status();
    final canCancel =
        booking.status == 'CONFIRMED' || booking.status == 'PENDING_PAYMENT';
    final upcoming = booking.startsAt.isAfter(DateTime.now());

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  booking.clubName ?? 'Club',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              InfoChip(
                label: st.label,
                icon: st.icon,
                color: st.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _line(Icons.event, DateFormat('EEEE d MMMM · HH:mm', 'fr')
              .format(booking.startsAt)),
          const SizedBox(height: 6),
          _line(Icons.sports_tennis,
              '${booking.courtName ?? ''} · ${booking.priceMad.toStringAsFixed(0)} MAD'),
          if (booking.status == 'CONFIRMED' && booking.qrCode != null) ...[
            const SizedBox(height: 14),
            // QR de check-in : toucher pour l'agrandir à l'accueil du club
            GestureDetector(
              onTap: () => _showQr(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: booking.qrCode!,
                        size: 64,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('QR de check-in',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text(
                            'Touchez pour agrandir et présenter à l’accueil',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (canCancel && upcoming) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancel(context, ref),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Annuler'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
          ],
          // Réservation honorée → possibilité de noter le club
          if (booking.status == 'COMPLETED' && booking.clubId != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _reviewClub(context, ref),
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Noter le club'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF92600A)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Avis sur le club (note 1-5 + commentaire) après une venue.
  Future<void> _reviewClub(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final comment = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Noter ${booking.clubName ?? 'le club'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int s = 1; s <= 5; s++)
                    GestureDetector(
                      onTap: () => setState(() => rating = s),
                      child: Icon(
                        s <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.amber,
                        size: 36,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  hintText: 'Terrains, accueil, vestiaires…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await ref.read(bookingRepositoryProvider).addReview(
            booking.clubId!,
            bookingId: booking.id,
            rating: rating,
            comment: comment.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci pour votre avis ⭐')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  /// QR plein écran pour le scan à l'accueil.
  void _showQr(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                booking.clubName ?? 'Réservation',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE d MMM · HH:mm', 'fr').format(booking.startsAt),
                style: const TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 18),
              QrImageView(data: booking.qrCode!, size: 240),
              const SizedBox(height: 12),
              const Text(
                'Présentez ce code à l’accueil du club',
                style: TextStyle(color: AppColors.slate, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      );
}
