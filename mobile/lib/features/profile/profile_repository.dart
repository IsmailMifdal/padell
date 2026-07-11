import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider).dio),
);

/// Profil complet renvoyé par GET /users/me.
final meProvider = FutureProvider.autoDispose<Me>(
  (ref) => ref.watch(profileRepositoryProvider).me(),
);

class Me {
  Me({
    required this.id,
    required this.roles,
    this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    this.city,
    this.level,
    this.courtPosition,
    this.handedness,
    this.matchesPlayed = 0,
  });

  final String id;
  final List<String> roles;
  final String? email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String? city;
  final double? level;
  final String? courtPosition;
  final String? handedness;
  final int matchesPlayed;

  String get fullName => '$firstName $lastName';
  bool get isOwner => roles.contains('OWNER');

  factory Me.fromJson(Map<String, dynamic> j) {
    final p = (j['profile'] ?? {}) as Map<String, dynamic>;
    return Me(
      id: j['id'] as String,
      roles: (j['roles'] as List?)?.cast<String>() ?? const [],
      email: j['email'] as String?,
      phone: j['phone'] as String?,
      firstName: (p['firstName'] ?? '') as String,
      lastName: (p['lastName'] ?? '') as String,
      city: p['city'] as String?,
      level: p['level'] == null ? null : double.tryParse(p['level'].toString()),
      courtPosition: p['courtPosition'] as String?,
      handedness: p['handedness'] as String?,
      matchesPlayed: (p['matchesPlayed'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Me> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return Me.fromJson(res.data!);
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? city,
    double? level,
    String? courtPosition,
    String? handedness,
  }) async {
    await _dio.patch<Map<String, dynamic>>('/users/me/profile', data: {
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      if (city != null) 'city': city,
      if (level != null) 'level': level,
      if (courtPosition != null) 'courtPosition': courtPosition,
      if (handedness != null) 'handedness': handedness,
    });
  }
}
