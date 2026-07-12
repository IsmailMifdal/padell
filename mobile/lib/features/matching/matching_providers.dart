import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location_service.dart';
import '../../shared/models.dart';
import 'matching_repository.dart';

/// Rayon de recherche (km) sélectionné par l'utilisateur.
final matchRadiusProvider = StateProvider<double>((ref) => 25);

/// Matchs ouverts autour de la position du joueur.
final nearbyMatchesProvider =
    FutureProvider.autoDispose<List<PadelMatch>>((ref) async {
  final center = await ref.watch(geoCenterProvider.future);
  final radius = ref.watch(matchRadiusProvider);
  return ref.watch(matchingRepositoryProvider).searchNearby(
        lat: center.lat,
        lng: center.lng,
        radiusKm: radius,
      );
});

final matchDetailProvider =
    FutureProvider.autoDispose.family<PadelMatch, String>((ref, id) {
  return ref.watch(matchingRepositoryProvider).detail(id);
});

/// Onglet Matchs : false = autour de moi, true = mes matchs.
final showMyMatchesProvider = StateProvider<bool>((ref) => false);

/// Matchs auxquels je participe (créés ou rejoints).
final myMatchesProvider = FutureProvider.autoDispose<List<PadelMatch>>((ref) {
  return ref.watch(matchingRepositoryProvider).mine();
});

/// Suggestions « Pour toi » (score de compatibilité).
final suggestionsProvider =
    FutureProvider.autoDispose<List<PadelMatch>>((ref) async {
  final center = await ref.watch(geoCenterProvider.future);
  return ref
      .watch(matchingRepositoryProvider)
      .suggestions(lat: center.lat, lng: center.lng);
});

/// Joueurs que j'ai déjà notés sur un match.
final myRatingsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, matchId) {
  return ref.watch(matchingRepositoryProvider).myRatings(matchId);
});
