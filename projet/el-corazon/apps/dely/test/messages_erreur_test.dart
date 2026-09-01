import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce que le livreur lit quand une action échoue.
///
/// Ces cas ne sont pas théoriques : ils ont tous été observés contre le
/// backend réel pendant l'audit du parcours livreur. Le serveur écrit ses
/// refus en français, destinés à être affichés (RFC 9457, `detail`) ;
/// l'application les enterrait sous le nom de sa classe d'exception.
void main() {
  eccore.ApiException probleme(int statut, String code, String detail) =>
      eccore.ApiException(status: statut, code: code, detail: detail);

  group('Le message du serveur est celui qu\'on affiche', () {
    test('un dossier non validé dit pourquoi', () {
      // Observé : POST /delivery/me/online/ avec un dossier en attente.
      final erreur = probleme(
        409,
        'business_rule_violation',
        "Votre dossier n'est pas validé ; vous ne pouvez pas encore recevoir de courses.",
      );

      expect(
        messageErreur(erreur),
        "Votre dossier n'est pas validé ; vous ne pouvez pas encore recevoir de courses.",
      );
      // Et surtout : plus de nom de classe ni de code technique à l'écran.
      expect(messageErreur(erreur), isNot(contains('ApiException')));
      expect(messageErreur(erreur), isNot(contains('business_rule_violation')));
    });

    test('un retrait trop élevé dit combien est disponible', () {
      // Observé : POST /payments/withdrawals/ au-delà du solde.
      expect(
        messageErreur(probleme(409, 'insufficient_balance',
            'Le montant demandé dépasse les gains disponibles.')),
        'Le montant demandé dépasse les gains disponibles.',
      );
    });

    test('une transition refusée nomme la transition', () {
      // Observé : POST /delivery/assignments/{id}/status/ vers delivered
      // depuis accepted.
      expect(
        messageErreur(probleme(409, 'business_rule_violation',
            'Transition refusée : accepted → delivered.')),
        'Transition refusée : accepted → delivered.',
      );
    });

    test('une course introuvable garde le message du serveur', () {
      expect(
        messageErreur(probleme(404, 'not_found', 'Introuvable.')),
        'Introuvable.',
      );
    });
  });

  group('Ce que le serveur ne dit pas, on le nomme ici', () {
    test('une panne réseau demande de vérifier le réseau', () {
      // `ApiException.network` : statut 0, aucun `detail` utile — le serveur
      // n'a rien répondu du tout.
      final message = messageErreur(
        eccore.ApiException.network('SocketException: échec de connexion'),
      );

      expect(message, contains('connexion'));
      expect(message, isNot(contains('SocketException')));
    });

    test('un 401 renvoie à la reconnexion, pas au détail technique', () {
      expect(messageErreur(probleme(401, 'invalid_token', 'Token invalide')),
          contains('session'));
    });

    test('un 429 demande de patienter', () {
      expect(messageErreur(probleme(429, 'throttled', 'Trop de requêtes')),
          contains('Patientez'));
    });

    test('un 500 ne montre pas la trace du serveur', () {
      final message = messageErreur(
        probleme(500, 'server_error', 'IntegrityError at /api/v1/...'),
      );

      expect(message, isNot(contains('IntegrityError')));
      expect(message, contains('serveur'));
    });

    test('une liste périmée demande de rafraîchir', () {
      // `AppService._requireCourse` : la course a disparu de la liste, un
      // collègue l'a prise. Réessayer ne sert à rien, recharger si.
      final message = messageErreur(
        StateError('Aucune course connue pour la commande abc'),
      );

      expect(message, contains('Rafraîchissez'));
      expect(message, isNot(contains('StateError')));
    });

    test('une session expirée le dit', () {
      expect(messageErreur(const eccore.SessionExpiredException()),
          contains('session'));
    });

    test('un compte du mauvais type le dit', () {
      expect(
        messageErreur(const eccore.WrongAccountTypeException('customer', 'courier')),
        contains('livreur'),
      );
    });

    test('une erreur inconnue reste une phrase, pas un objet', () {
      final message =
          messageErreur(const FormatException('Unexpected token < at 0'));

      expect(message, isNot(contains('FormatException')));
      expect(message, isNot(contains('Unexpected token')));
      expect(message, contains('Réessayez'));
    });
  });
}
