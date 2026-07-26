import 'package:flutter_test/flutter_test.dart';
import 'package:padel_mobile/shared/models.dart';

/// Tests des parcours qui touchent à l'argent.
///
/// Contexte : la page « Mes réservations » a déjà planté en production parce
/// que Prisma sérialise les `Decimal` en **chaîne** (`"300"`) et non en
/// nombre, alors que le modèle faisait un cast strict `as num`. Ces tests
/// verrouillent le parsing tolérant pour que la régression ne repasse pas.
void main() {
  group('Booking — parsing des montants', () {
    Map<String, dynamic> payload(dynamic price) => {
          'id': 'b1',
          'status': 'CONFIRMED',
          'startsAt': '2026-08-01T18:00:00.000Z',
          'endsAt': '2026-08-01T19:30:00.000Z',
          'priceMad': price,
          'qrCode': 'QR-123',
          'court': {
            'name': 'Terrain 1',
            'club': {'id': 'c1', 'name': 'Padel Center Anfa'},
          },
        };

    test('accepte un Decimal Prisma sérialisé en chaîne', () {
      // C'est exactement le cas qui cassait la page Réservations
      final b = Booking.fromJson(payload('300'));
      expect(b.priceMad, 300);
    });

    test('accepte un montant numérique', () {
      expect(Booking.fromJson(payload(300)).priceMad, 300);
      expect(Booking.fromJson(payload(300.5)).priceMad, 300.5);
    });

    test('accepte les décimales en chaîne', () {
      expect(Booking.fromJson(payload('249.99')).priceMad, 249.99);
    });

    test('ne plante pas sur un montant absent ou invalide', () {
      // Mieux vaut 0 affiché qu'un écran d'erreur : l'utilisateur garde
      // accès à sa réservation et au QR code d'entrée.
      expect(Booking.fromJson(payload(null)).priceMad, 0);
      expect(Booking.fromJson(payload('abc')).priceMad, 0);
    });

    test('expose le QR code et le club (accès au terrain)', () {
      final b = Booking.fromJson(payload('300'));
      expect(b.qrCode, 'QR-123');
      expect(b.clubName, 'Padel Center Anfa');
      expect(b.courtName, 'Terrain 1');
      expect(b.clubId, 'c1');
    });

    test('convertit les dates UTC du serveur en heure locale', () {
      final b = Booking.fromJson(payload('300'));
      expect(b.startsAt.isUtc, isFalse);
      expect(b.endsAt.isAfter(b.startsAt), isTrue);
    });
  });

  group('Slot — créneaux réservables', () {
    Map<String, dynamic> payload(dynamic price, dynamic duration) => {
          'courtId': 'court-1',
          'courtName': 'Terrain 2',
          'startsAt': '2026-08-01T18:00:00.000Z',
          'endsAt': '2026-08-01T19:30:00.000Z',
          'durationMin': duration,
          'priceMad': price,
        };

    test('parse prix et durée quel que soit leur type', () {
      final fromString = Slot.fromJson(payload('180', '90'));
      expect(fromString.priceMad, 180);
      expect(fromString.durationMin, 90);

      final fromNumber = Slot.fromJson(payload(180, 90));
      expect(fromNumber.priceMad, 180);
      expect(fromNumber.durationMin, 90);
    });

    test('retombe sur 90 min si la durée est illisible', () {
      // Une durée nulle rendrait le créneau inréservable côté UI
      expect(Slot.fromJson(payload('180', null)).durationMin, 90);
    });
  });

  group('User — rôles et aiguillage joueur / propriétaire', () {
    User parse(List<String> roles) => User.fromJson({
          'id': 'u1',
          'firstName': 'Sara',
          'lastName': 'B.',
          'email': 'sara@padel.ma',
          'roles': roles,
        });

    test('lit les rôles renvoyés par le backend', () {
      expect(parse(['PLAYER']).roles, ['PLAYER']);
      expect(parse(['PLAYER', 'OWNER']).roles, containsAll(['PLAYER', 'OWNER']));
    });

    test('tolère un payload sans rôles', () {
      final u = User.fromJson({
        'id': 'u1',
        'firstName': 'Sara',
        'lastName': 'B.',
      });
      expect(u.roles, isEmpty);
    });

    test('survit à un aller-retour encode/decode (session persistée)', () {
      // Si ce round-trip casse, l'utilisateur est déconnecté au redémarrage
      final original = parse(['PLAYER', 'OWNER']);
      final restored = User.decode(original.encode());
      expect(restored.id, original.id);
      expect(restored.firstName, original.firstName);
      expect(restored.roles, containsAll(['PLAYER', 'OWNER']));
    });
  });
}
