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

class PricingRule {
  PricingRule({
    required this.id,
    required this.dayOfWeek,
    required this.startMin,
    required this.endMin,
    required this.durationMin,
    required this.priceMad,
  });

  final String id;
  final int dayOfWeek;
  final int startMin;
  final int endMin;
  final int durationMin;
  final double priceMad;

  factory PricingRule.fromJson(Map<String, dynamic> j) => PricingRule(
        id: j['id'] as String,
        dayOfWeek: (j['dayOfWeek'] as num).toInt(),
        startMin: (j['startMin'] as num).toInt(),
        endMin: (j['endMin'] as num).toInt(),
        durationMin: (j['durationMin'] as num).toInt(),
        priceMad: double.tryParse(j['priceMad'].toString()) ?? 0,
      );
}

class OwnerCourt {
  OwnerCourt({
    required this.id,
    required this.name,
    this.type = 'OUTDOOR',
    this.rules = const [],
  });

  final String id;
  final String name;
  final String type;
  final List<PricingRule> rules;

  factory OwnerCourt.fromJson(Map<String, dynamic> j) => OwnerCourt(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? 'OUTDOOR') as String,
        rules: ((j['pricingRules'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PricingRule.fromJson)
            .toList(),
      );
}

class OpeningHour {
  OpeningHour({
    required this.dayOfWeek,
    required this.openMin,
    required this.closeMin,
  });

  final int dayOfWeek;
  final int openMin;
  final int closeMin;

  factory OpeningHour.fromJson(Map<String, dynamic> j) => OpeningHour(
        dayOfWeek: (j['dayOfWeek'] as num).toInt(),
        openMin: (j['openMin'] as num).toInt(),
        closeMin: (j['closeMin'] as num).toInt(),
      );
}

class OwnerClub {
  OwnerClub({
    required this.id,
    required this.name,
    required this.city,
    required this.status,
    required this.courts,
    this.openingHours = const [],
  });

  final String id;
  final String name;
  final String city;
  final String status;
  final List<OwnerCourt> courts;
  final List<OpeningHour> openingHours;

  factory OwnerClub.fromJson(Map<String, dynamic> j) => OwnerClub(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        courts: ((j['courts'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OwnerCourt.fromJson)
            .toList(),
        openingHours: ((j['openingHours'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OpeningHour.fromJson)
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

class OwnerStats {
  OwnerStats({
    required this.days,
    required this.totalBookings,
    required this.cancelledBookings,
    required this.revenueMad,
    required this.manualShare,
    required this.byHour,
  });

  final int days;
  final int totalBookings;
  final int cancelledBookings;
  final double revenueMad;
  final int manualShare;
  final Map<int, int> byHour;

  factory OwnerStats.fromJson(Map<String, dynamic> j) => OwnerStats(
        days: (j['days'] as num?)?.toInt() ?? 30,
        totalBookings: (j['totalBookings'] as num?)?.toInt() ?? 0,
        cancelledBookings: (j['cancelledBookings'] as num?)?.toInt() ?? 0,
        revenueMad: double.tryParse(j['revenueMad'].toString()) ?? 0,
        manualShare: (j['manualShare'] as num?)?.toInt() ?? 0,
        byHour: ((j['byHour'] as Map?) ?? {}).map(
          (k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt()),
        ),
      );
}

final ownerStatsProvider =
    FutureProvider.autoDispose.family<OwnerStats, String>((ref, clubId) {
  return ref.watch(ownerRepositoryProvider).stats(clubId);
});

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

  // ------------------------------------------------- création & configuration

  /// Dépose une demande de club (statut PENDING jusqu'à validation admin).
  Future<OwnerClub> createClub({
    required String name,
    required String address,
    required String city,
    required double latitude,
    required double longitude,
    String? description,
    String? phone,
    List<String> amenities = const [],
    bool paymentOnSiteAllowed = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/clubs', data: {
      'name': name,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'amenities': amenities,
      'paymentOnSiteAllowed': paymentOnSiteAllowed,
    });
    return OwnerClub.fromJson(res.data!);
  }

  Future<void> addCourt(String clubId,
      {required String name, required String type}) async {
    await _dio.post<void>('/clubs/$clubId/courts',
        data: {'name': name, 'type': type});
  }

  /// Remplace l'intégralité des horaires (une entrée par jour ouvert).
  Future<void> setOpeningHours(
      String clubId, List<OpeningHour> hours) async {
    await _dio.put<void>('/clubs/$clubId/opening-hours', data: {
      'hours': hours
          .map((h) => {
                'dayOfWeek': h.dayOfWeek,
                'openMin': h.openMin,
                'closeMin': h.closeMin,
              })
          .toList(),
    });
  }

  Future<void> addPricingRule(
    String clubId,
    String courtId, {
    required int dayOfWeek,
    required int startMin,
    required int endMin,
    required int durationMin,
    required double priceMad,
  }) async {
    await _dio.post<void>('/clubs/$clubId/courts/$courtId/pricing', data: {
      'dayOfWeek': dayOfWeek,
      'startMin': startMin,
      'endMin': endMin,
      'durationMin': durationMin,
      'priceMad': priceMad,
    });
  }

  Future<void> deletePricingRule(String clubId, String ruleId) async {
    await _dio.delete<void>('/clubs/$clubId/pricing/$ruleId');
  }

  /// Statistiques d'exploitation du club (30 derniers jours).
  Future<OwnerStats> stats(String clubId) async {
    final res = await _dio
        .get<Map<String, dynamic>>('/owner/clubs/$clubId/stats');
    return OwnerStats.fromJson(res.data!);
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
