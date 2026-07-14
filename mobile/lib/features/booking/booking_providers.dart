import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location_service.dart';
import '../../shared/models.dart';
import 'booking_repository.dart';

/// Recherche courante (filtre ville). null = autour de ma position.
final clubSearchProvider = StateProvider<String?>((ref) => null);

final clubsProvider = FutureProvider.autoDispose<List<Club>>((ref) async {
  final city = ref.watch(clubSearchProvider);
  if (city != null && city.isNotEmpty) {
    return ref.watch(bookingRepositoryProvider).searchClubs(city: city);
  }
  // Sans filtre ville : recherche géolocalisée → distances réelles
  final center = await ref.watch(geoCenterProvider.future);
  return ref
      .watch(bookingRepositoryProvider)
      .searchClubs(lat: center.lat, lng: center.lng);
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

/// Suis-je inscrit en liste d'attente pour ce club/jour ?
final waitlistStatusProvider =
    FutureProvider.autoDispose.family<bool, AvailabilityArgs>((ref, args) {
  return ref
      .watch(bookingRepositoryProvider)
      .waitlistStatus(args.clubId, args.day);
});
