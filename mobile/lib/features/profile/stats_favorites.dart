import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';

// ------------------------------------------------------------------- favoris

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(apiClientProvider).dio),
);

/// Ids des clubs favoris (pour l'état des cœurs).
final favoriteClubIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final clubs = await ref.watch(favoritesRepositoryProvider).list();
  return clubs.map((c) => c.id).toSet();
});

class FavoritesRepository {
  FavoritesRepository(this._dio);
  final Dio _dio;

  Future<List<Club>> list() async {
    final res = await _dio.get<List<dynamic>>('/users/me/favorites/clubs');
    return res.data!.cast<Map<String, dynamic>>().map(Club.fromJson).toList();
  }

  Future<void> add(String clubId) async {
    await _dio.put<void>('/users/me/favorites/clubs/$clubId');
  }

  Future<void> remove(String clubId) async {
    await _dio.delete<void>('/users/me/favorites/clubs/$clubId');
  }
}

// --------------------------------------------------------------------- stats

class PlayerStats {
  PlayerStats({
    required this.level,
    required this.eloRating,
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.bookingsCount,
    required this.clubsVisited,
    required this.ratingsReceived,
    this.avgPunctuality,
    this.avgFairplay,
    this.avgLevelAccuracy,
  });

  final double level;
  final int eloRating;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int bookingsCount;
  final int clubsVisited;
  final int ratingsReceived;
  final double? avgPunctuality;
  final double? avgFairplay;
  final double? avgLevelAccuracy;

  static double? _d(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats(
        level: _d(j['level']) ?? 0,
        eloRating: (j['eloRating'] as num?)?.toInt() ?? 1000,
        matchesPlayed: (j['matchesPlayed'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        bookingsCount: (j['bookingsCount'] as num?)?.toInt() ?? 0,
        clubsVisited: (j['clubsVisited'] as num?)?.toInt() ?? 0,
        ratingsReceived: (j['ratingsReceived'] as num?)?.toInt() ?? 0,
        avgPunctuality: _d(j['avgPunctuality']),
        avgFairplay: _d(j['avgFairplay']),
        avgLevelAccuracy: _d(j['avgLevelAccuracy']),
      );
}

final playerStatsProvider = FutureProvider.autoDispose<PlayerStats>((ref) async {
  final dio = ref.watch(apiClientProvider).dio;
  final res = await dio.get<Map<String, dynamic>>('/users/me/stats');
  return PlayerStats.fromJson(res.data!);
});
