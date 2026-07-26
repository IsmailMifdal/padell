import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'deep_links.dart';

/// Notifications de l'application.
///
/// Deux circuits distincts :
///
/// 1. **Locales** — programmées par l'app elle-même sur l'appareil (rappel
///    « votre match commence dans 2 h »). Fonctionnent sans aucun service
///    tiers, y compris hors ligne.
///
/// 2. **Distantes (push)** — envoyées par le serveur. Le backend sait déjà les
///    produire et expose `PUT /notifications/device` ; il ne manque que le
///    jeton de l'appareil, fourni par FCM. Tant que Firebase n'est pas
///    configuré, [registerDeviceToken] n'est simplement jamais appelé et
///    l'app fonctionne normalement — voir `docs/08-push-firebase.md`.
///
/// Dans les deux cas, toucher une notification ouvre le bon écran grâce au
/// `payload`, qui contient un lien profond (`padel://match/<id>`).
class NotificationsService {
  NotificationsService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static GoRouter? _router;

  /// Canal Android dédié : permet à l'utilisateur de régler finement
  /// (ou de couper) les rappels sans désactiver toutes les notifications.
  static const _channel = AndroidNotificationChannel(
    'padel_reminders',
    'Rappels de match',
    description: 'Rappel avant le début d’un match ou d’une réservation',
    importance: Importance.high,
  );

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// À appeler une fois au démarrage, après la création du routeur.
  static Future<void> init(GoRouter router) async {
    _router = router;
    if (!_supported || _ready) return;

    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Les autorisations sont demandées explicitement plus tard, au moment
        // où l'utilisateur comprend pourquoi (après une réservation).
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) => _openPayload(response.payload),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Notification ayant lancé l'app depuis un état fermé
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openPayload(launch!.notificationResponse?.payload);
      }

      _ready = true;
    } catch (e) {
      // Une notification qui échoue ne doit jamais empêcher l'app de démarrer
      debugPrint('NotificationsService.init: $e');
    }
  }

  /// Ouvre l'écran visé par une notification touchée.
  static void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final route = DeepLinks.routeFor(Uri.parse(payload));
    if (route != null) _router?.go(route);
  }

  /// Demande l'autorisation d'afficher des notifications.
  ///
  /// À appeler à un moment qui a du sens pour l'utilisateur (juste après une
  /// réservation), jamais au premier lancement : une demande sans contexte se
  /// fait refuser, et le refus est définitif sur iOS.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      if (Platform.isIOS) {
        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('NotificationsService.requestPermission: $e');
      return false;
    }
  }

  /// Programme un rappel avant un match ou une réservation.
  ///
  /// [id] doit être stable pour un même événement : reprogrammer avec le même
  /// identifiant remplace le rappel au lieu d'en empiler un second (cas d'une
  /// réservation modifiée).
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime startsAt,
    String? deepLink,
    Duration before = const Duration(hours: 2),
  }) async {
    if (!_supported || !_ready) return;

    final when = startsAt.subtract(before);
    // Un rappel dans le passé n'a pas de sens et lèverait une erreur
    if (!when.isAfter(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: deepLink,
        // `inexact` évite d'exiger l'autorisation « alarmes exactes »
        // (Android 12+), refusée par défaut : un rappel à quelques minutes
        // près suffit largement ici.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationsService.scheduleReminder: $e');
    }
  }

  /// Annule un rappel (réservation annulée, match quitté).
  static Future<void> cancel(int id) async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('NotificationsService.cancel: $e');
    }
  }

  /// Identifiant de rappel dérivé d'un id métier.
  ///
  /// `hashCode` peut être négatif et dépasser la plage acceptée par Android
  /// pour un identifiant de notification : on le ramène dans un entier 31 bits.
  static int reminderId(String businessId) => businessId.hashCode & 0x7fffffff;
}
