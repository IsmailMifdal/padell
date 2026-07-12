import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Langues supportées. L'arabe active automatiquement le sens RTL.
const supportedLocales = [Locale('fr'), Locale('ar'), Locale('en')];

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() {
    _restore();
    return const Locale('fr');
  }

  Future<void> _restore() async {
    final saved = await ref.read(secureStorageProvider).read(key: _key);
    if (saved != null &&
        supportedLocales.any((l) => l.languageCode == saved)) {
      state = Locale(saved);
    }
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(secureStorageProvider)
        .write(key: _key, value: locale.languageCode);
  }
}

/// Traductions des libellés principaux (navigation, profil, communs).
/// Les écrans de détail restent en français par défaut (couverture progressive).
class T {
  T._(this._map);
  final Map<String, String> _map;

  static T of(Locale locale) =>
      T._(_translations[locale.languageCode] ?? _translations['fr']!);

  String operator [](String key) => _map[key] ?? _translations['fr']![key] ?? key;

  static const _translations = <String, Map<String, String>>{
    'fr': {
      'clubs': 'Clubs',
      'matches': 'Matchs',
      'bookings': 'Résas',
      'bookingsLong': 'Réservations',
      'profile': 'Profil',
      'myBookings': 'Mes réservations',
      'myGameProfile': 'Mon profil de jeu',
      'myStats': 'Mes statistiques',
      'notifications': 'Notifications',
      'help': 'Aide & support',
      'clubSpace': 'Espace club',
      'language': 'Langue',
      'logout': 'Se déconnecter',
    },
    'en': {
      'clubs': 'Clubs',
      'matches': 'Matches',
      'bookings': 'Bookings',
      'bookingsLong': 'Bookings',
      'profile': 'Profile',
      'myBookings': 'My bookings',
      'myGameProfile': 'My game profile',
      'myStats': 'My statistics',
      'notifications': 'Notifications',
      'help': 'Help & support',
      'clubSpace': 'Club space',
      'language': 'Language',
      'logout': 'Log out',
    },
    'ar': {
      'clubs': 'النوادي',
      'matches': 'المباريات',
      'bookings': 'الحجوزات',
      'bookingsLong': 'الحجوزات',
      'profile': 'الملف الشخصي',
      'myBookings': 'حجوزاتي',
      'myGameProfile': 'ملفي الرياضي',
      'myStats': 'إحصائياتي',
      'notifications': 'الإشعارات',
      'help': 'المساعدة والدعم',
      'clubSpace': 'فضاء النادي',
      'language': 'اللغة',
      'logout': 'تسجيل الخروج',
    },
  };
}
