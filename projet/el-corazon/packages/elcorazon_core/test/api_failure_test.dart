import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

/// La nature d'un échec — avant toute conclusion métier.
///
/// Ce que ces cas verrouillent : une panne ne se classe jamais comme un refus,
/// et un refus jamais comme une panne. C'est la condition pour qu'aucun écran ne
/// traduise « serveur injoignable » en « aucune cuisine ne vous livre ».
void main() {
  ApiException api(int status, [String code = 'x']) =>
      ApiException(status: status, code: code, detail: 'd');

  group('ApiFailure.of', () {
    test('aucune réponse : réseau', () {
      expect(ApiFailure.of(ApiException.network('refusé')), ApiFailure.network);
      expect(ApiFailure.of(TimeoutException('lent')), ApiFailure.network);
    });

    test('401 et session expirée : authentification', () {
      expect(ApiFailure.of(api(401)), ApiFailure.authentication);
      expect(ApiFailure.of(const SessionExpiredException()), ApiFailure.authentication);
    });

    test('403 : autorisation, distincte de l’authentification', () {
      expect(ApiFailure.of(api(403, 'permission_denied')), ApiFailure.authorization);
    });

    test('5xx, lisible ou non : serveur', () {
      expect(ApiFailure.of(api(503, 'service_unavailable')), ApiFailure.server);
      expect(ApiFailure.of(ApiException.unreadable(500)), ApiFailure.server);
    });

    test('un refus argumenté reste un refus', () {
      expect(ApiFailure.of(api(409, 'kitchen_not_orderable')), ApiFailure.rejected);
      expect(ApiFailure.of(api(400, 'validation_error')), ApiFailure.rejected);
    });

    test('404 et 429 ont leur nature', () {
      expect(ApiFailure.of(api(404, 'not_found')), ApiFailure.notFound);
      expect(ApiFailure.of(api(429, 'throttled')), ApiFailure.throttled);
    });

    test('une réponse qui ne suit pas le contrat : réponse invalide', () {
      expect(ApiFailure.of(const FormatException('pas du JSON')), ApiFailure.invalidResponse);
      expect(ApiFailure.of(ApiException.unreadable(302)), ApiFailure.invalidResponse);
      // Ce que lève `Restaurant.fromJson` quand un champ attendu manque.
      Object? typeError;
      try {
        final brut = <String, dynamic>{};
        fail('attendu une TypeError, lu ${brut['id'] as String}');
      } on TypeError catch (e) {
        typeError = e;
      }
      expect(ApiFailure.of(typeError), ApiFailure.invalidResponse);
    });

    test('le reste est inconnu, jamais « rien à afficher »', () {
      expect(ApiFailure.of(StateError('bug')), ApiFailure.unknown);
    });
  });

  group('codes et reprise', () {
    test('les codes stables attendus par les écrans', () {
      expect(ApiFailure.network.code, 'NETWORK_ERROR');
      expect(ApiFailure.authentication.code, 'AUTHENTICATION_ERROR');
      expect(ApiFailure.authorization.code, 'AUTHORIZATION_ERROR');
      expect(ApiFailure.server.code, 'SERVER_ERROR');
    });

    test('seules les pannes méritent un nouvel essai à l’identique', () {
      expect(ApiFailure.network.isTransient, isTrue);
      expect(ApiFailure.server.isTransient, isTrue);
      expect(ApiFailure.authorization.isTransient, isFalse);
      expect(ApiFailure.rejected.isTransient, isFalse);
    });
  });

  group('DeliveryAvailability', () {
    test('lit le motif stable du refus', () {
      final reponse = DeliveryAvailability.fromJson({
        'is_available': false,
        'reason': 'Aucune cuisine El Corazón ne dessert cette adresse pour le moment.',
        'unavailable_code': 'no_kitchen_available',
        'restaurant': null,
      });

      expect(reponse.unavailableCode, MotifIndisponibilite.aucuneCuisine);
      expect(reponse.aucuneCuisine, isTrue);
    });

    test('une adresse hors desserte n’est pas « aucune cuisine »', () {
      final reponse = DeliveryAvailability.fromJson({
        'is_available': false,
        'reason': 'Cette adresse n’est couverte par aucune zone de livraison.',
        'unavailable_code': 'address_not_served',
        'restaurant': {
          'id': 'r1',
          'name': 'El Corazón',
          'slug': 'el-corazon-lome',
        },
      });

      expect(reponse.unavailableCode, MotifIndisponibilite.adresseNonDesservie);
      expect(reponse.aucuneCuisine, isFalse);
    });
  });
}
