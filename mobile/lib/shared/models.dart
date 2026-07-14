import 'dart:convert';

/// Modèles partagés (parseurs tolérants au camelCase et snake_case renvoyés
/// selon les endpoints de l'API).

/// L'API sérialise les dates en UTC ("...Z") : conversion systématique en
/// heure locale de l'appareil pour l'affichage et les envois.
DateTime parseLocal(dynamic iso) => DateTime.parse(iso as String).toLocal();

class User {
  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.roles = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final List<String> roles;

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        firstName: (j['firstName'] ?? '') as String,
        lastName: (j['lastName'] ?? '') as String,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        roles: (j['roles'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'roles': roles,
      };

  String encode() => jsonEncode(toJson());
  static User decode(String s) =>
      User.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class Club {
  Club({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.ratingAvg,
    this.distanceM,
    this.paymentOnSiteAllowed = true,
    this.latitude,
    this.longitude,
    this.amenities = const [],
  });

  final String id;
  final String name;
  final String city;
  final String address;
  final double? ratingAvg;
  final double? distanceM;
  final bool paymentOnSiteAllowed;
  final double? latitude;
  final double? longitude;
  final List<String> amenities;

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        ratingAvg: _toDouble(j['ratingAvg'] ?? j['rating_avg']),
        distanceM: _toDouble(j['distanceM'] ?? j['distance_m']),
        paymentOnSiteAllowed:
            (j['paymentOnSiteAllowed'] ?? j['payment_on_site_allowed'] ?? true)
                as bool,
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        amenities: (j['amenities'] as List?)?.cast<String>() ?? const [],
      );
}

class Slot {
  Slot({
    required this.courtId,
    required this.courtName,
    required this.startsAt,
    required this.endsAt,
    required this.durationMin,
    required this.priceMad,
  });

  final String courtId;
  final String courtName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMin;
  final double priceMad;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        courtId: j['courtId'] as String,
        courtName: (j['courtName'] ?? '') as String,
        startsAt: parseLocal(j['startsAt']),
        endsAt: parseLocal(j['endsAt']),
        durationMin: (j['durationMin'] as num).toInt(),
        priceMad: (j['priceMad'] as num).toDouble(),
      );
}

class MatchParticipant {
  MatchParticipant({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.level,
    this.hasPaid = false,
  });

  final String playerId;
  final String firstName;
  final String lastName;
  final String status; // REQUESTED | ACCEPTED | ...
  final double? level;

  /// Part du match payée (paiement au statut PAID).
  final bool hasPaid;

  String get fullName => '$firstName $lastName';
  String get initial => firstName.isEmpty ? '?' : firstName[0].toUpperCase();

  factory MatchParticipant.fromJson(Map<String, dynamic> j) {
    final player = (j['player'] ?? {}) as Map<String, dynamic>;
    final profile = (player['profile'] ?? {}) as Map<String, dynamic>;
    final payment = j['payment'] as Map<String, dynamic>?;
    return MatchParticipant(
      // Selon l'endpoint, l'id est dans player.id ou directement playerId
      playerId: (player['id'] ?? j['playerId'] ?? '') as String,
      firstName: (profile['firstName'] ?? '') as String,
      lastName: (profile['lastName'] ?? '') as String,
      status: (j['status'] ?? 'ACCEPTED') as String,
      level: profile['level'] == null
          ? null
          : double.tryParse(profile['level'].toString()),
      hasPaid: payment?['status'] == 'PAID',
    );
  }
}

class PadelMatch {
  PadelMatch({
    required this.id,
    required this.clubName,
    required this.city,
    required this.startsAt,
    required this.durationMin,
    required this.levelMin,
    required this.levelMax,
    required this.pricePerPlayerMad,
    required this.status,
    required this.acceptedCount,
    this.creatorId,
    this.distanceM,
    this.players = const [],
    this.winnerIds = const [],
    this.scoreText,
    this.suggestionScore,
  });

  final String id;
  final String clubName;
  final String city;
  final DateTime startsAt;
  final int durationMin;
  final double levelMin;
  final double levelMax;
  final double pricePerPlayerMad;
  final String status;
  final int acceptedCount;
  final String? creatorId;
  final double? distanceM;
  final List<MatchParticipant> players;

  /// Vainqueurs et score affiché (match PLAYED).
  final List<String> winnerIds;
  final String? scoreText;

  /// Score de compatibilité 0-100 (endpoint suggestions).
  final int? suggestionScore;

  static const size = 4;
  int get spotsLeft => (size - acceptedCount).clamp(0, size);
  DateTime get endsAt => startsAt.add(Duration(minutes: durationMin));

  static double _d(dynamic v) => double.tryParse(v.toString()) ?? 0;

  factory PadelMatch.fromJson(Map<String, dynamic> j) {
    final club = (j['club'] ?? {}) as Map<String, dynamic>;
    final rawPlayers =
        (j['players'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final parsed = rawPlayers.map(MatchParticipant.fromJson).toList();
    final accepted = parsed.where((p) => p.status == 'ACCEPTED').length;
    return PadelMatch(
      id: j['id'] as String,
      clubName: (club['name'] ?? 'Club') as String,
      city: (club['city'] ?? '') as String,
      startsAt: parseLocal(j['startsAt']),
      durationMin: (j['durationMin'] as num).toInt(),
      levelMin: _d(j['levelMin']),
      levelMax: _d(j['levelMax']),
      pricePerPlayerMad: _d(j['pricePerPlayerMad']),
      status: (j['status'] ?? 'OPEN') as String,
      acceptedCount: parsed.isEmpty ? 0 : accepted,
      creatorId: j['creatorId'] as String?,
      distanceM: j['distanceM'] == null
          ? null
          : double.tryParse(j['distanceM'].toString()),
      players: parsed,
      winnerIds: (j['score'] is Map)
          ? ((j['score']['winnerIds'] as List?)?.cast<String>() ?? const [])
          : const [],
      scoreText: (j['score'] is Map) ? j['score']['score'] as String? : null,
      suggestionScore: (j['compatScore'] as num?)?.toInt(),
    );
  }
}

class Booking {
  Booking({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.priceMad,
    this.qrCode,
    this.courtName,
    this.clubName,
    this.clubId,
  });

  final String id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final double priceMad;
  final String? qrCode;
  final String? courtName;
  final String? clubName;
  final String? clubId;

  factory Booking.fromJson(Map<String, dynamic> j) {
    final court = j['court'] as Map<String, dynamic>?;
    final club = court?['club'] as Map<String, dynamic>?;
    return Booking(
      id: j['id'] as String,
      status: (j['status'] ?? '') as String,
      startsAt: parseLocal(j['startsAt']),
      endsAt: parseLocal(j['endsAt']),
      priceMad: (j['priceMad'] as num).toDouble(),
      qrCode: j['qrCode'] as String?,
      courtName: court?['name'] as String?,
      clubName: club?['name'] as String?,
      clubId: club?['id'] as String?,
    );
  }
}
