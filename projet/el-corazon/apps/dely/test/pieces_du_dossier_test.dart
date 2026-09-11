import 'package:elcora_dely/presentation/pieces_du_dossier.dart';
import 'package:elcora_dely/presentation/vehicules.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Les pièces du dossier livreur, et ce que l'application en déduit.
///
/// ## Ce que ces tests gardent
///
/// Le dépôt de pièces n'existait dans aucune application : le dossier d'un
/// livreur ne pouvait jamais être complété, et l'écran d'attente lui annonçait
/// qu'El Corazón vérifiait des pièces jamais envoyées. La règle centrale porte
/// donc sur **qui doit agir** : un dossier incomplet attend le livreur, un
/// dossier complet attend El Corazón, et confondre les deux est exactement ce
/// que faisait le bandeau.
///
/// Les tests sont écrits sur les **chaînes du serveur** (`pending`,
/// `rejected`, `id_document`…) plutôt que sur une énumération locale : c'est ce
/// couplage-là qui doit casser bruyamment si le contrat change, plutôt que
/// l'écran de se taire.
void main() {
  eccore.CourierProfile dossier({
    String verification = 'pending',
    String? identite,
    String? permis,
    String? carteGrise,
    String vehicule = 'motorcycle',
    String notes = '',
  }) {
    return eccore.CourierProfile.fromJson({
      'id': 'courier-1',
      'full_name': 'Yao Agbeko',
      'email': 'yao@elcorazon.test',
      'phone': '+22890111222',
      'restaurant': 'el-corazon-lome',
      'verification_status': verification,
      'verification_notes': notes,
      'verified_at': null,
      'national_id_number': 'TG-CNI-4417',
      'licence_number': 'PC-2291-B',
      'id_document': identite,
      'licence_document': permis,
      'vehicle_document': carteGrise,
      'vehicle_type': vehicule,
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

  const signee = 'https://cdn.test/documents/cni.jpg?sig=abc';

  group('Les trois emplacements du dossier', () {
    test('chaque pièce lit son propre champ du contrat', () {
      // La règle que l'écran de profil violait : il affichait la plaque
      // d'immatriculation sous le libellé « Numéro de permis ».
      final complet = dossier(
        identite: 'https://cdn.test/cni.jpg',
        permis: 'https://cdn.test/permis.jpg',
        carteGrise: 'https://cdn.test/carte.jpg',
      );

      expect(PieceDuDossier.identite.urlSur(complet), 'https://cdn.test/cni.jpg');
      expect(PieceDuDossier.permis.urlSur(complet), 'https://cdn.test/permis.jpg');
      expect(PieceDuDossier.carteGrise.urlSur(complet), 'https://cdn.test/carte.jpg');
    });

    test('les noms de champs sont ceux du serveur, pas des libellés', () {
      // Ce sont des identifiants d'API : les traduire ferait refuser le dépôt.
      expect(
        [for (final piece in PieceDuDossier.values) piece.champ],
        ['id_document', 'licence_document', 'vehicle_document'],
      );
    });

    test('une chaîne vide vaut une pièce absente', () {
      // Un champ fichier vide se sérialise en `""` selon la configuration du
      // stockage. Le lire comme « déposée » afficherait un emplacement rempli
      // sur un dossier qui ne l'est pas.
      final vide = dossier(identite: '');

      expect(PieceDuDossier.identite.estDeposeeSur(vide), isFalse);
      expect(piecesManquantes(vide), contains(PieceDuDossier.identite));
    });

    test('les pièces manquantes sortent dans l\'ordre où on les demande', () {
      expect(piecesManquantes(dossier(permis: signee)), [
        PieceDuDossier.identite,
        PieceDuDossier.carteGrise,
      ]);
    });
  });

  group('Ce que le dossier attend, et de qui', () {
    test('un dossier neuf attend le livreur', () {
      // Le cas de l'inscription : compte créé, dossier vide. Lui dire
      // « patientez » est la seule chose à ne pas faire — rien n'arrivera
      // jamais dans la file d'instruction.
      final exigence = ExigenceDuDossier.depuis(dossier());

      expect(exigence, ExigenceDuDossier.incomplet);
      expect(exigence.appelleUneAction, isTrue);
      expect(exigence.action, 'Déposer mes pièces');
    });

    test('un dossier complet en attente n\'attend plus rien du livreur', () {
      final exigence = ExigenceDuDossier.depuis(
        dossier(identite: signee, permis: signee, carteGrise: signee),
      );

      expect(exigence, ExigenceDuDossier.rienAFaire);
      expect(exigence.appelleUneAction, isFalse);
    });

    test('un dossier refusé appelle une correction', () {
      // La sortie qui manquait : le mur d'état ne proposait qu'« Actualiser »
      // et « Se déconnecter » à un livreur refusé pour une photo illisible.
      final exigence = ExigenceDuDossier.depuis(
        dossier(
          verification: 'rejected',
          identite: signee,
          permis: signee,
          carteGrise: signee,
        ),
      );

      expect(exigence, ExigenceDuDossier.aCorriger);
      expect(exigence.action, 'Corriger mon dossier');
    });

    test('un dossier refusé et incomplet demande d\'abord les pièces qui manquent', () {
      // « Incomplet » l'emporte sur « à corriger » : demander de *remplacer* ce
      // qui n'a jamais été déposé n'a pas de sens.
      expect(
        ExigenceDuDossier.depuis(dossier(verification: 'rejected', identite: signee)),
        ExigenceDuDossier.incomplet,
      );
    });

    test('un dossier validé n\'appelle aucune action', () {
      expect(
        ExigenceDuDossier.depuis(
          dossier(
            verification: 'approved',
            identite: signee,
            permis: signee,
            carteGrise: signee,
          ),
        ),
        ExigenceDuDossier.rienAFaire,
      );
    });

    test('un dossier suspendu n\'ouvre pas de correction par les pièces', () {
      // Une suspension est une sanction d'exploitation, pas un défaut de
      // pièce : le serveur refuse `SUSPENDED → PENDING`, et proposer le
      // bouton ferait promettre à l'écran ce que le serveur refuserait.
      expect(
        ExigenceDuDossier.depuis(
          dossier(
            verification: 'suspended',
            identite: signee,
            permis: signee,
            carteGrise: signee,
          ),
        ),
        ExigenceDuDossier.rienAFaire,
      );
    });

    test('un dossier pas encore lu ne réclame rien', () {
      // Il n'est chargé qu'après la première lecture ; afficher « incomplet »
      // par défaut ferait redéposer des pièces déjà présentes.
      expect(ExigenceDuDossier.depuis(null), ExigenceDuDossier.rienAFaire);
    });
  });

  group('Les véhicules', () {
    test('le code envoyé au serveur est celui de VehicleType', () {
      expect(
        [for (final vehicule in Vehicule.values) vehicule.code],
        ['motorcycle', 'scooter', 'bicycle', 'car'],
      );
    });

    test('un dossier s\'affiche en français, pas avec le code du contrat', () {
      // L'écran de profil affichait `motorcycle` dans un champ « Véhicule »,
      // quand le formulaire d'inscription proposait « Moto ».
      expect(Vehicule.libelleDe(dossier().vehicleType), 'Moto');
      expect(Vehicule.libelleDe('car'), 'Voiture');
    });

    test('un type inconnu de cette version s\'affiche tel quel', () {
      // Jamais un repli sur « Moto » : un livreur ne doit pas lire un véhicule
      // qui n'est pas celui de son dossier.
      expect(Vehicule.depuisServeur('tricycle'), isNull);
      expect(Vehicule.libelleDe('tricycle'), 'tricycle');
    });

    test('un dossier sans véhicule ne prétend pas en avoir un', () {
      expect(Vehicule.libelleDe(''), '—');
      expect(Vehicule.libelleDe(null), '—');
    });
  });

  group('Le dossier vu du socle', () {
    test('hasAllDocuments et piecesManquantes disent la même chose', () {
      // Deux lectures de la même vérité : l'une dans le socle, l'autre dans
      // la présentation. Elles divergeraient sans ce garde-fou.
      final complet = dossier(identite: signee, permis: signee, carteGrise: signee);

      expect(complet.hasAllDocuments, isTrue);
      expect(piecesManquantes(complet), isEmpty);
      expect(dossier().hasAllDocuments, isFalse);
      expect(piecesManquantes(dossier()), hasLength(3));
    });

    test('les numéros de pièces sont distincts de leurs photos', () {
      // Le numéro se relit et se compare, l'image se regarde. L'écran de
      // profil confondait la plaque et le permis ; le contrat, lui, distingue
      // quatre champs.
      final sansPhoto = dossier();

      expect(sansPhoto.licenceNumber, 'PC-2291-B');
      expect(sansPhoto.nationalIdNumber, 'TG-CNI-4417');
      expect(sansPhoto.licenceDocument, isNull);
      expect(sansPhoto.vehiclePlate, 'TG-1234');
    });
  });
}
