import 'dart:convert';

/// Modèles partagés (parseurs tolérants au camelCase et snake_case renvoyés
/// selon les endpoints de l'API).

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
  });

  final String id;
  final String name;
  final String city;
  final String address;
  final double? ratingAvg;
  final double? distanceM;

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        ratingAvg: _toDouble(j['ratingAvg'] ?? j['rating_avg']),
        distanceM: _toDouble(j['distanceM'] ?? j['distance_m']),
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
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        durationMin: (j['durationMin'] as num).toInt(),
        priceMad: (j['priceMad'] as num).toDouble(),
      );
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
  });

  final String id;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final double priceMad;
  final String? qrCode;
  final String? courtName;
  final String? clubName;

  factory Booking.fromJson(Map<String, dynamic> j) {
    final court = j['court'] as Map<String, dynamic>?;
    final club = court?['club'] as Map<String, dynamic>?;
    return Booking(
      id: j['id'] as String,
      status: (j['status'] ?? '') as String,
      startsAt: DateTime.parse(j['startsAt'] as String),
      endsAt: DateTime.parse(j['endsAt'] as String),
      priceMad: (j['priceMad'] as num).toDouble(),
      qrCode: j['qrCode'] as String?,
      courtName: court?['name'] as String?,
      clubName: club?['name'] as String?,
    );
  }
}
