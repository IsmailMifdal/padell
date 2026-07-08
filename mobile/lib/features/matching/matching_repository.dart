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

  Future<void> withdraw(String id) async {
    await _dio.post<void>('/matches/$id/withdraw');
  }

  Future<void> cancel(String id) async {
    await _dio.post<void>('/matches/$id/cancel');
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
