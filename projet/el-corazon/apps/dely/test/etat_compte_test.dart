import 'package:elcora_dely/presentation/etat_compte.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// L'état du compte livreur — la lecture croisée de trois sources.
///
/// Ces tests portent la règle que `DriverGate` applique sans la connaître :
/// qui entre, qui reste devant la porte, et ce qu'on lui dit. Ils sont écrits
/// sur les **chaînes du serveur** (`pending`, `approved`, `rejected`,
/// `suspended`) et non sur une énumération locale : c'est ce couplage-là qui
/// doit casser si le serveur change son vocabulaire, plutôt que l'écran de se
/// taire.
void main() {
  eccore.User compte({
    bool isActive = true,
    String? emailVerifiedAt = '2026-09-02T10:00:00Z',
  }) {
    return eccore.User.fromJson({
      'id': 'user-1',
      'email': 'yao@elcorazon.test',
      'phone': '+22890111222',
      'full_name': 'Yao Agbeko',
      'user_type': eccore.UserAccountType.courier,
      'avatar': null,
      'is_active': isActive,
      'permissions': const <String>[],
      'email_verified_at': emailVerifiedAt,
      'phone_verified_at': null,
      'last_seen_at': null,
      'created_at': '2026-09-01T09:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
    });
  }

  eccore.CourierProfile dossier(String verification) {
    return eccore.CourierProfile.fromJson({
      'id': 'courier-1',
      'full_name': 'Yao Agbeko',
      'email': 'yao@elcorazon.test',
      'phone': '+22890111222',
      'restaurant': 'el-corazon-lome',
      'verification_status': verification,
      'verification_notes': '',
      'verified_at': null,
      'id_document': null,
      'licence_document': null,
      'vehicle_document': null,
      'vehicle_type': 'motorcycle',
      'vehicle_plate': 'TG-1234',
      'is_online': false,
      'can_accept_orders': false,
      'last_location': null,
      'last_location_at': null,
      'deliveries_completed': 0,
      'deliveries_cancelled': 0,
      'rating_average': '0.00',
      'rating_count': 0,
      'total_earnings': null,
      'created_at': '2026-09-01T09:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
    });
  }

  group('Lecture de l\'état', () {
    test('un compte désactivé prime sur tout le reste', () {
      // Le plus fort des états : peu importe que l'adresse soit vérifiée et le
      // dossier validé, il n'y a plus de compte.
      final etat = EtatCompte.depuis(compte(isActive: false), dossier('approved'));

      expect(etat, EtatCompte.bloque);
    });

    test('une adresse non vérifiée prime sur le dossier', () {
      final etat = EtatCompte.depuis(compte(emailVerifiedAt: null), dossier('approved'));

      expect(etat, EtatCompte.verificationRequise);
    });

    test('les quatre statuts de dossier sont traduits', () {
      expect(EtatCompte.depuis(compte(), dossier('pending')), EtatCompte.enAttente);
      expect(EtatCompte.depuis(compte(), dossier('approved')), EtatCompte.actif);
      expect(EtatCompte.depuis(compte(), dossier('rejected')), EtatCompte.refuse);
      expect(EtatCompte.depuis(compte(), dossier('suspended')), EtatCompte.suspendu);
    });

    test('un dossier pas encore lu ne barre rien', () {
      // Le dossier n'arrive qu'après la première lecture des courses. Supposer
      // « suspendu » en attendant afficherait un mur d'une demi-seconde à
      // chaque démarrage.
      final etat = EtatCompte.depuis(compte(), null);

      expect(etat, EtatCompte.actif);
      expect(etat.barreLApplication, isFalse);
    });

    test('un statut inconnu de cette version ne barre rien non plus', () {
      // Un statut ajouté côté serveur ne doit pas enfermer dehors les
      // applications déjà installées : le serveur reste seul juge, et il
      // refusera de lui-même ce qu'il faut refuser (L1).
      final etat = EtatCompte.depuis(compte(), dossier('pending'));
      expect(etat, EtatCompte.enAttente);

      // `verification_status` hors énumération connue.
      expect(EtatCompte.depuis(compte(), dossier('en_revision')), EtatCompte.actif);
    });
  });

  group('Ce que l\'état autorise', () {
    test('seuls les états irréparables depuis l\'application barrent la route', () {
      expect(EtatCompte.verificationRequise.barreLApplication, isTrue);
      expect(EtatCompte.suspendu.barreLApplication, isTrue);
      expect(EtatCompte.refuse.barreLApplication, isTrue);
      expect(EtatCompte.bloque.barreLApplication, isTrue);

      // Un dossier en attente laisse entrer : le livreur consulte son profil,
      // son historique, ses réglages. Ce qu'il n'a pas, ce sont des courses —
      // et c'est le serveur qui les lui refuse.
      expect(EtatCompte.enAttente.barreLApplication, isFalse);
      expect(EtatCompte.actif.barreLApplication, isFalse);
    });

    test('le bandeau ne s\'affiche que pour l\'attente', () {
      expect(EtatCompte.enAttente.meriteUnBandeau, isTrue);
      for (final autre in EtatCompte.values.where((e) => e != EtatCompte.enAttente)) {
        expect(autre.meriteUnBandeau, isFalse, reason: '$autre');
      }
    });

    test('chaque état porte un titre et une explication non vides', () {
      // Un état sans phrase laisserait un écran muet — c'est la panne qu'on ne
      // voit qu'en production, sur le seul cas qu'on n'a jamais ouvert.
      for (final etat in EtatCompte.values) {
        expect(etat.titre, isNotEmpty, reason: '$etat');
        expect(etat.explication, isNotEmpty, reason: '$etat');
      }
    });
  });
}
