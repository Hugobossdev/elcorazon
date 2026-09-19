import 'package:admin/presentation/expiration_piece.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'expiration des pièces d'un dossier livreur, à l'écran.
///
/// Le cahier des charges la demande (§4.2.5) ; l'ancien modèle avait un champ
/// que rien ne renseignait. Le seuil d'alerte suit le premier rappel du
/// serveur : un mois.
void main() {
  final maintenant = DateTime(2026, 9, 19, 15, 30);

  group('L’état', () {
    test('sans date, on ne sait pas — ni bon ni mauvais', () {
      expect(EtatExpiration.de(null, maintenant: maintenant), EtatExpiration.inconnue);
    });

    test('une pièce qui expire aujourd’hui vaut encore toute la journée', () {
      // Comparer à l'instant la déclarerait expirée dès minuit passé d'une
      // minute — ce que le document lui-même ne dit pas.
      expect(
        EtatExpiration.de(DateTime(2026, 9, 19), maintenant: maintenant),
        EtatExpiration.bientot,
      );
    });

    test('hier, elle est expirée', () {
      expect(
        EtatExpiration.de(DateTime(2026, 9, 18), maintenant: maintenant),
        EtatExpiration.expiree,
      );
    });

    test('à trente jours on alerte, à trente et un non', () {
      expect(
        EtatExpiration.de(DateTime(2026, 10, 19), maintenant: maintenant),
        EtatExpiration.bientot,
      );
      expect(
        EtatExpiration.de(DateTime(2026, 10, 20), maintenant: maintenant),
        EtatExpiration.valide,
      );
    });
  });

  group('Le libellé', () {
    test('dit la date et le délai', () {
      expect(
        libelleExpiration(DateTime(2026, 9, 26), maintenant: maintenant),
        'Expire dans 7 jours (26/09/2026)',
      );
      expect(libelleExpiration(DateTime(2026, 9, 20), maintenant: maintenant), 'Expire demain');
      expect(
        libelleExpiration(DateTime(2026, 9, 10), maintenant: maintenant),
        'Expirée depuis le 10/09/2026',
      );
      expect(
        libelleExpiration(DateTime(2027, 3), maintenant: maintenant),
        'Valable jusqu’au 01/03/2027',
      );
    });

    test('invite à saisir quand on ne sait pas', () {
      expect(libelleExpiration(null), contains('non saisie'));
    });
  });
}
