import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../shared/models.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(ref.watch(apiClientProvider).dio),
);

/// Mes clubs (propriétaire), avec leurs terrains.
final myClubsProvider = FutureProvider.autoDispose<List<OwnerClub>>(
  (ref) => ref.watch(ownerRepositoryProvider).myClubs(),
);

typedef OwnerCalendarArgs = ({String clubId, DateTime day});

final ownerCalendarProvider = FutureProvider.autoDispose
    .family<List<OwnerBooking>, OwnerCalendarArgs>((ref, args) {
  return ref.watch(ownerRepositoryProvider).calendar(args.clubId, args.day);
});

class OwnerCourt {
  OwnerCourt({required this.id, required this.name});
  final String id;
  final String name;

  factory OwnerCourt.fromJson(Map<String, dynamic> j) =>
      OwnerCourt(id: j['id'] as String, name: (j['name'] ?? '') as String);
}

class OwnerClub {
  OwnerClub({
    required this.id,
    required this.name,
    required this.city,
    required this.status,
    required this.courts,
  });

  final String id;
  final String name;
  final String city;
  final String status;
  final List<OwnerCourt> courts;

  factory OwnerClub.fromJson(Map<String, dynamic> j) => OwnerClub(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        courts: ((j['courts'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OwnerCourt.fromJson)
            .toList(),
      );
}

class OwnerBooking {
  OwnerBooking({
    required this.id,
    required this.courtName,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.source,
    this.customer,
    this.note,
    this.matchId,
  });

  final String id;
  final String courtName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String source; // APP | MANUAL | BLOCKED
  final String? customer;
  final String? note;
  final String? matchId;

  factory OwnerBooking.fromJson(Map<String, dynamic> j) {
    final court = (j['court'] ?? {}) as Map<String, dynamic>;
    final bookedBy = j['bookedBy'] as Map<String, dynamic>?;
    final profile = bookedBy?['profile'] as Map<String, dynamic>?;
    final match = j['match'] as Map<String, dynamic>?;
    return OwnerBooking(
      id: j['id'] as String,
      courtName: (court['name'] ?? '') as String,
      startsAt: parseLocal(j['startsAt']),
      endsAt: parseLocal(j['endsAt']),
      status: (j['status'] ?? '') as String,
      source: (j['source'] ?? 'APP') as String,
      customer: profile == null
          ? null
          : '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim(),
      note: j['note'] as String?,
      matchId: match?['id'] as String?,
    );
  }
}

class OwnerRepository {
  OwnerRepository(this._dio);
  final Dio _dio;

  static final _dayFmt = DateFormat('yyyy-MM-dd');
  static final _localFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  Future<List<OwnerClub>> myClubs() async {
    final res = await _dio.get<List<dynamic>>('/clubs/mine');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(OwnerClub.fromJson)
        .toList();
  }

  Future<List<OwnerBooking>> calendar(String clubId, DateTime day) async {
    final d = _dayFmt.format(day);
    final res = await _dio.get<List<dynamic>>(
      '/owner/clubs/$clubId/calendar',
      queryParameters: {'from': d, 'to': d},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(OwnerBooking.fromJson)
        .toList();
  }

  Future<void> manualBooking(
    String clubId, {
    required String courtId,
    required DateTime startsAt,
    required int durationMin,
    double? priceMad,
    String? customerName,
  }) async {
    await _dio.post<void>('/owner/clubs/$clubId/bookings/manual', data: {
      'courtId': courtId,
      'startsAt': _localFmt.format(startsAt),
      'durationMin': durationMin,
      if (priceMad != null) 'priceMad': priceMad,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
    });
  }

  Future<void> blockSlot(
    String clubId, {
    required String courtId,
    required DateTime startsAt,
    required int durationMin,
    String? reason,
  }) async {
    await _dio.post<void>('/owner/clubs/$clubId/bookings/block', data: {
      'courtId': courtId,
      'startsAt': _localFmt.format(startsAt),
      'durationMin': durationMin,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> cancelBooking(String clubId, String bookingId) async {
    await _dio.post<void>(
      '/owner/clubs/$clubId/bookings/$bookingId/cancel',
      data: {'reason': 'Annulée par le club'},
    );
  }

  /// Check-in par code QR : retourne le nom du terrain confirmé.
  Future<String> checkin(String clubId, String qrCode) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/owner/clubs/$clubId/checkin',
      data: {'qrCode': qrCode},
    );
    final court = (res.data!['court'] ?? {}) as Map<String, dynamic>;
    return (court['name'] ?? 'Terrain') as String;
  }
}
