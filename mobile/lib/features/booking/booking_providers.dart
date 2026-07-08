import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models.dart';
import 'booking_repository.dart';

/// Recherche courante (filtre ville). null = tous les clubs.
final clubSearchProvider = StateProvider<String?>((ref) => null);

final clubsProvider = FutureProvider.autoDispose<List<Club>>((ref) {
  final city = ref.watch(clubSearchProvider);
  return ref.watch(bookingRepositoryProvider).searchClubs(city: city);
});

/// Clés de la recherche de disponibilités : (idClub, jour à minuit).
typedef AvailabilityArgs = ({String clubId, DateTime day});

final availabilityProvider = FutureProvider.autoDispose
    .family<List<Slot>, AvailabilityArgs>((ref, args) {
  return ref
      .watch(bookingRepositoryProvider)
      .availability(args.clubId, args.day);
});

final myBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).myBookings();
});
