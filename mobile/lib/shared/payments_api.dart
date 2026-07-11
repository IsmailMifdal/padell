import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';

final paymentsApiProvider = Provider<PaymentsApi>(
  (ref) => PaymentsApi(ref.watch(apiClientProvider).dio),
);

/// Appels de paiement communs (réservations et parts de match).
class PaymentsApi {
  PaymentsApi(this._dio);
  final Dio _dio;

  /// Session CMI d'une réservation en attente de paiement.
  Future<Map<String, dynamic>> bookingSession(String bookingId) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/payments/bookings/$bookingId/session');
    return res.data!;
  }

  /// Session CMI de sa part dans un match.
  Future<Map<String, dynamic>> matchSession(String matchId) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/payments/matches/$matchId/session');
    return res.data!;
  }

  /// DEV uniquement : simule le paiement réussi d'une commande (403 en prod).
  Future<void> simulateDev(String oid) async {
    await _dio.post<void>('/payments/dev/simulate', data: {'oid': oid});
  }
}
