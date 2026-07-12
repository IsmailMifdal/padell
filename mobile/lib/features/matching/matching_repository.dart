import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';

final matchingRepositoryProvider = Provider<MatchingRepository>(
  (ref) => MatchingRepository(ref.watch(apiClientProvider).dio),
);

class MatchingRepository {
  MatchingRepository(this._dio);
  final Dio _dio;

  static final _localFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  Future<List<PadelMatch>> searchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>('/matches', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
    });
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(PadelMatch.fromJson).toList();
  }

  Future<List<PadelMatch>> mine() async {
    final res = await _dio.get<List<dynamic>>('/matches/mine');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(PadelMatch.fromJson)
        .toList();
  }

  Future<PadelMatch> detail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/matches/$id');
    return PadelMatch.fromJson(res.data!);
  }

  Future<void> join(String id) async {
    await _dio.post<void>('/matches/$id/join');
  }

  /// L'organisateur accepte ou refuse une demande de participation.
  Future<void> respond(String matchId, String playerId, {required bool accept}) async {
    await _dio.post<void>(
      '/matches/$matchId/players/$playerId/${accept ? 'accept' : 'decline'}',
    );
  }

  /// Session de paiement CMI pour sa part du match (formulaire à poster).
  Future<Map<String, dynamic>> paymentSession(String matchId) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/payments/matches/$matchId/session');
    return res.data!;
  }

  Future<void> withdraw(String id) async {
    await _dio.post<void>('/matches/$id/withdraw');
  }

  Future<void> cancel(String id) async {
    await _dio.post<void>('/matches/$id/cancel');
  }

  /// Suggestions « Pour toi » (score de compatibilité 0-100).
  Future<List<PadelMatch>> suggestions({
    required double lat,
    required double lng,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/matches/suggestions',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(PadelMatch.fromJson)
        .toList();
  }

  /// L'organisateur enregistre le score (2 vainqueurs + score affiché).
  Future<void> submitScore(
    String matchId, {
    required List<String> winnerIds,
    String? score,
  }) async {
    await _dio.post<void>('/matches/$matchId/score', data: {
      'winnerIds': winnerIds,
      if (score != null && score.isNotEmpty) 'score': score,
    });
  }

  /// Notation des partenaires (1-5 par critère).
  Future<void> ratePlayers(
    String matchId,
    List<Map<String, dynamic>> items,
  ) async {
    await _dio.post<void>('/matches/$matchId/rate', data: {'items': items});
  }

  /// Ids des joueurs déjà notés par moi sur ce match.
  Future<List<String>> myRatings(String matchId) async {
    final res = await _dio.get<List<dynamic>>('/matches/$matchId/my-ratings');
    return res.data!.cast<String>();
  }

  Future<PadelMatch> create({
    required String courtId,
    required DateTime startsAt,
    required int durationMin,
    required double levelMin,
    required double levelMax,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/matches', data: {
      'courtId': courtId,
      'startsAt': _localFmt.format(startsAt),
      'durationMin': durationMin,
      'levelMin': levelMin,
      'levelMax': levelMax,
    });
    return PadelMatch.fromJson(res.data!);
  }
}
