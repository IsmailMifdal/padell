import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider).dio),
);

class BookingRepository {
  BookingRepository(this._dio);
  final Dio _dio;

  static final _dayFmt = DateFormat('yyyy-MM-dd');
  // Heure locale du club, sans fuseau (l'API l'interprète en local)
  static final _localFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  Future<List<Club>> searchClubs({String? city}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/clubs',
      queryParameters: {if (city != null && city.isNotEmpty) 'city': city},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Club.fromJson).toList();
  }

  Future<List<Slot>> availability(String clubId, DateTime day) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/clubs/$clubId/availability',
      queryParameters: {'date': _dayFmt.format(day)},
    );
    final slots = (res.data!['slots'] as List).cast<Map<String, dynamic>>();
    return slots.map(Slot.fromJson).toList();
  }

  /// [paymentMode] : 'ON_SITE' (confirmation immédiate + QR) ou 'ONLINE'
  /// (réservation en attente, à finaliser via la session CMI).
  Future<Booking> book(Slot slot, {String paymentMode = 'ON_SITE'}) async {
    final res = await _dio.post<Map<String, dynamic>>('/bookings', data: {
      'courtId': slot.courtId,
      'startsAt': _localFmt.format(slot.startsAt),
      'durationMin': slot.durationMin,
      'paymentMode': paymentMode,
    });
    return Booking.fromJson(res.data!);
  }

  Future<List<Booking>> myBookings() async {
    final res = await _dio.get<List<dynamic>>('/bookings/mine');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();
  }

  Future<void> cancel(String bookingId) async {
    await _dio.post<void>('/bookings/$bookingId/cancel', data: {});
  }

  // -------------------------------------------------------------------- avis

  Future<void> addReview(
    String clubId, {
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _dio.post<void>('/clubs/$clubId/reviews', data: {
      'bookingId': bookingId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> reviews(String clubId) async {
    final res = await _dio.get<List<dynamic>>('/clubs/$clubId/reviews');
    return res.data!.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------- liste d'attente

  Future<bool> waitlistStatus(String clubId, DateTime day) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/clubs/$clubId/waitlist',
      queryParameters: {'date': _dayFmt.format(day)},
    );
    return res.data!['waitlisted'] == true;
  }

  Future<void> joinWaitlist(String clubId, DateTime day) async {
    await _dio.post<void>(
      '/clubs/$clubId/waitlist',
      queryParameters: {'date': _dayFmt.format(day)},
    );
  }

  Future<void> leaveWaitlist(String clubId, DateTime day) async {
    await _dio.post<void>(
      '/clubs/$clubId/waitlist/leave',
      queryParameters: {'date': _dayFmt.format(day)},
    );
  }
}
