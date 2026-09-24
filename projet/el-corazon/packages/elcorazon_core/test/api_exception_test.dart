import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

void main() {
  group('ApiException.fromProblemDetail', () {
    test('lit code, detail et status — le format RFC 9457 du serveur', () {
      final error = ApiException.fromProblemDetail(409, {
        'type': 'https://api.elcorazon.app/errors/business-rule-violation',
        'title': 'Règle métier non respectée',
        'status': 409,
        'code': 'business_rule_violation',
        'detail': 'Le mot de passe actuel est incorrect.',
      });

      expect(error.status, 409);
      expect(error.code, 'business_rule_violation');
      expect(error.detail, 'Le mot de passe actuel est incorrect.');
      expect(error.errors, isEmpty);
    });

    test('normalise `errors` — un champ peut porter une chaîne ou une liste', () {
      final error = ApiException.fromProblemDetail(400, {
        'code': 'validation_error',
        'detail': 'Requête invalide.',
        'errors': {
          'email': ['Ce champ est requis.'],
          'password': 'Trop court.',
        },
      });

      expect(error.errors['email'], ['Ce champ est requis.']);
      expect(error.errors['password'], ['Trop court.']);
    });

    test('un refus de validation sans phrase se dit par ses champs', () {
      // Ce que rend DRF sur un 400 : aucune phrase d'ensemble, la raison est
      // rangée champ par champ. Une soixantaine d'écrans affichent `detail`
      // directement ; ils lisaient « Une erreur est survenue. ».
      final error = ApiException.fromProblemDetail(400, {
        'code': 'validation_error',
        'errors': {
          'notes': ['Dites au livreur pourquoi : il lira ce motif dans son application.'],
          'lines': [
            {'quantity': ['Au moins un article.']},
          ],
        },
      });

      expect(
        error.detail,
        'Dites au livreur pourquoi : il lira ce motif dans son application. Au moins un article.',
      );
    });

    test('la phrase du serveur prime sur ses champs', () {
      final error = ApiException.fromProblemDetail(400, {
        'code': 'validation_error',
        'detail': 'Requête invalide.',
        'errors': {
          'email': ['Ce champ est requis.'],
        },
      });

      expect(error.detail, 'Requête invalide.');
    });

    test('sans phrase ni champ, le repli reste reconnaissable', () {
      final error = ApiException.fromProblemDetail(403, {'code': 'permission_denied'});

      expect(error.detail, ApiException.detailParDefaut);
    });

    test('détecte le throttling (429)', () {
      final error = ApiException.fromProblemDetail(429, {
        'code': 'throttled',
        'detail': 'Trop de tentatives.',
      });

      expect(error.isThrottled, isTrue);
      expect(error.isUnauthorized, isFalse);
    });
  });

  group('ApiException.network', () {
    test('dit la panne en français, et garde la cause technique pour le diagnostic', () {
      final error = ApiException.network('The connection errored: Failed host lookup');

      // Le message du transport — anglais, technique — était le `detail`, et
      // les écrans qui affichent `detail` le montraient au client.
      expect(error.detail, ApiException.detailReseau);
      expect(error.members['cause'], 'The connection errored: Failed host lookup');
      expect(error.toString(), contains('Failed host lookup'));
      expect(error.isNetworkError, isTrue);
    });
  });
}
