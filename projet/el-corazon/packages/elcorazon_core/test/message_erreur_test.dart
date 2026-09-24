import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que les trois applications montrent quand une action échoue.
///
/// Le test décisif est le dernier : rien de ce qui sort d'ici ne doit contenir
/// le nom d'une classe Dart. C'est exactement ce qui était affiché avant —
/// `ApiException(409, …)`, `DioException [connection error]` — et aucune de ces
/// chaînes ne dit à quelqu'un ce qu'il peut faire.
void main() {
  group('Le serveur a écrit la phrase', () {
    test('un refus métier est rendu tel quel', () {
      const erreur = ApiException(
        status: 409,
        code: 'business_rule_violation',
        detail: 'Ce livreur n’est pas rattaché à l’établissement de la commande.',
      );

      expect(
        messageErreurApi(erreur),
        'Ce livreur n’est pas rattaché à l’établissement de la commande.',
      );
    });

    test('un refus de permission est rendu tel quel', () {
      const erreur = ApiException(
        status: 403,
        code: 'permission_denied',
        detail: 'Vous n’avez pas le droit d’instruire un dossier livreur.',
      );

      expect(messageErreurApi(erreur), contains('instruire un dossier'));
    });
  });

  group('Le serveur a répondu champ par champ', () {
    test('un refus de validation rend les raisons, pas le repli', () {
      // Forme exacte d'un 400 DRF passé par `problem_detail_handler` : pas de
      // `detail`, les raisons dans `errors`.
      final erreur = ApiException.fromProblemDetail(400, {
        'type': 'https://api.elcorazon.app/errors/invalid',
        'title': 'Requête invalide.',
        'status': 400,
        'code': 'invalid',
        'errors': {
          'password': ['Ce mot de passe est trop courant.'],
          'email': ['Un utilisateur avec cette adresse existe déjà.'],
        },
      });

      final message = messageErreurApi(erreur);

      expect(message, contains('Ce mot de passe est trop courant.'));
      expect(message, contains('Un utilisateur avec cette adresse existe déjà.'));
      expect(message, isNot(contains('Une erreur est survenue')));
    });

    test('une phrase d’ensemble, quand il y en a une, reste prioritaire', () {
      const erreur = ApiException(
        status: 400,
        code: 'invalid',
        detail: 'Le motif est obligatoire.',
        errors: {
          'reason': ['Le motif est obligatoire.'],
        },
      );

      expect(messageErreurApi(erreur), 'Le motif est obligatoire.');
    });
  });

  group('Le serveur n’a rien dit d’utile', () {
    test('une panne de transport parle de réseau, pas du serveur', () {
      final erreur = ApiException.network('Connection refused');

      final message = messageErreurApi(erreur);

      expect(message, contains('connexion'));
      // Le detail d'un échec réseau est un message de bibliothèque, en
      // anglais : le rendre reviendrait à recommencer ce qu'on corrige.
      expect(message, isNot(contains('Connection refused')));
    });

    test('un 500 ne montre pas ce que le serveur a lâché', () {
      const erreur = ApiException(
        status: 500,
        code: 'server_error',
        detail: 'IntegrityError at /api/v1/orders/',
      );

      expect(messageErreurApi(erreur), isNot(contains('IntegrityError')));
    });

    test('un 401 oriente vers la reconnexion', () {
      const erreur = ApiException(status: 401, code: 'not_authenticated', detail: '');

      expect(messageErreurApi(erreur), contains('session'));
    });

    test('un 429 demande d’attendre, sans accuser le réseau', () {
      const erreur = ApiException(status: 429, code: 'throttled', detail: '');

      expect(messageErreurApi(erreur), contains('Patientez'));
    });
  });

  group('Les erreurs qui ne viennent pas de l’API', () {
    test('une session expirée le dit', () {
      expect(messageErreurApi(const SessionExpiredException()), contains('session'));
    });

    test('le mauvais type de compte nomme celui qu’attend l’application', () {
      final message = messageErreurApi(
        const WrongAccountTypeException('customer', 'courier'),
        compteAttendu: 'livreur',
      );

      expect(message, contains('livreur'));
    });

    test('sans type attendu, la phrase reste vraie sans inventer', () {
      final message = messageErreurApi(
        const WrongAccountTypeException('customer', 'courier'),
      );

      expect(message, 'Ce compte ne peut pas ouvrir cette application.');
    });

    test('une erreur inconnue tombe sur le repli, que l’appelant peut nommer', () {
      expect(
        messageErreurApi(StateError('boom'), repli: 'Rafraîchissez l’écran.'),
        'Rafraîchissez l’écran.',
      );
    });
  });

  plus();

  test('aucune phrase ne laisse fuir le nom d’une classe', () {
    final erreurs = <Object>[
      ApiException.network('Connection refused'),
      const ApiException(status: 500, code: 'server_error', detail: 'boom'),
      const ApiException(status: 401, code: 'not_authenticated', detail: ''),
      const ApiException(status: 429, code: 'throttled', detail: ''),
      const SessionExpiredException(),
      const WrongAccountTypeException('customer', 'courier'),
      StateError('boom'),
      Exception('brut'),
    ];

    for (final erreur in erreurs) {
      final message = messageErreurApi(erreur);
      expect(message, isNot(contains('Exception')), reason: '$erreur');
      expect(message, isNot(contains('Error')), reason: '$erreur');
    }
  });
}

/// Ajouts : ce que le serveur n'a pas écrit, et ce qu'il a écrit trop profond.
void plus() {
  group('Le serveur n’a écrit ni phrase ni champ', () {
    test('un 403 dit ce qui manque, et n’invite pas à réessayer', () {
      final erreur = ApiException.fromProblemDetail(403, {'code': 'permission_denied'});

      final message = messageErreurApi(erreur);

      expect(message, contains('autorisation'));
      expect(message, isNot(contains('Réessayez')));
    });

    test('un 404 parle d’un élément introuvable', () {
      final erreur = ApiException.fromProblemDetail(404, {'code': 'not_found'});

      expect(messageErreurApi(erreur), contains('introuvable'));
    });
  });

  group('Les erreurs imbriquées', () {
    test('une erreur de ligne rend la phrase, pas la structure', () {
      // Forme d'un sérialiseur imbriqué : DRF range par index, puis par champ.
      final erreur = ApiException.fromProblemDetail(400, {
        'code': 'invalid',
        'errors': {
          'lines': [
            {
              'quantity': ['Au moins un article.'],
            },
          ],
        },
      });

      final message = messageErreurApi(erreur);

      expect(message, 'Au moins un article.');
      expect(message, isNot(contains('{')));
      expect(message, isNot(contains('quantity')));
    });
  });
}
