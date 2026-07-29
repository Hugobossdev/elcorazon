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

    test('détecte le throttling (429)', () {
      final error = ApiException.fromProblemDetail(429, {
        'code': 'throttled',
        'detail': 'Trop de tentatives.',
      });

      expect(error.isThrottled, isTrue);
      expect(error.isUnauthorized, isFalse);
    });
  });
}
