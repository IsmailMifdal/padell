import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_mobile/core/api_client.dart';

/// Les messages d'erreur sont ce que voit l'utilisateur quand un paiement ou
/// une réservation échoue. Un message générique lui fait croire à un bug de
/// l'app alors que c'est souvent son réseau — ou un créneau déjà pris.
void main() {
  final req = RequestOptions(path: '/bookings');

  DioException withStatus(int code, {dynamic body}) => DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: code, data: body),
        type: DioExceptionType.badResponse,
      );

  group('isNetworkError — distingue le réseau du refus serveur', () {
    test('vrai pour les pannes réseau', () {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        expect(
          isNetworkError(DioException(requestOptions: req, type: type)),
          isTrue,
          reason: '$type devrait être considéré comme une erreur réseau',
        );
      }
    });

    test('vrai pour une SocketException nue ou enveloppée', () {
      expect(isNetworkError(const SocketException('pas de route')), isTrue);
      expect(
        isNetworkError(DioException(
          requestOptions: req,
          type: DioExceptionType.unknown,
          error: const SocketException('pas de route'),
        )),
        isTrue,
      );
    });

    test('faux quand le serveur a répondu (c’est un refus, pas le réseau)', () {
      expect(isNetworkError(withStatus(409)), isFalse);
      expect(isNetworkError(withStatus(500)), isFalse);
    });
  });

  group('apiErrorMessage — priorité au message métier du backend', () {
    test('affiche le message du backend quand il existe', () {
      final msg = apiErrorMessage(
        withStatus(400, body: {'message': 'Ce créneau est déjà réservé'}),
      );
      expect(msg, 'Ce créneau est déjà réservé');
    });

    test('joint les messages de validation multiples', () {
      final msg = apiErrorMessage(
        withStatus(400, body: {
          'message': ['Email invalide', 'Mot de passe trop court'],
        }),
      );
      expect(msg, contains('Email invalide'));
      expect(msg, contains('Mot de passe trop court'));
    });

    test('explique la perte de connexion plutôt que « une erreur est survenue »', () {
      final msg = apiErrorMessage(
        DioException(requestOptions: req, type: DioExceptionType.connectionError),
      );
      expect(msg.toLowerCase(), contains('connexion'));
      expect(msg, isNot(contains('Une erreur est survenue')));
    });

    test('distingue un serveur lent d’une absence de réseau', () {
      final slow = apiErrorMessage(
        DioException(requestOptions: req, type: DioExceptionType.receiveTimeout),
      );
      expect(slow.toLowerCase(), contains('trop de temps'));
    });

    test('traduit les codes sans message métier', () {
      // 409 = le cas réel du créneau pris entre l'affichage et le tap
      expect(apiErrorMessage(withStatus(409)).toLowerCase(), contains('créneau'));
      expect(apiErrorMessage(withStatus(404)).toLowerCase(), contains('introuvable'));
      expect(apiErrorMessage(withStatus(401)).toLowerCase(), contains('reconnect'));
      expect(apiErrorMessage(withStatus(503)).toLowerCase(), contains('serveur'));
    });

    test('retombe sur un message générique pour l’inconnu', () {
      expect(apiErrorMessage(Exception('boom')), 'Une erreur est survenue');
    });
  });
}
