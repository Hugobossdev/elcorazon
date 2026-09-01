import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce que les écrans lisent sur une course pour décider quoi afficher.
///
/// L'enjeu de ce fichier tient en une phrase : **la machine à états est celle
/// du serveur**. Elle vit dans `DELIVERY_MACHINE`
/// (`backend/apps/delivery/states.py`), voyage sur chaque affectation dans
/// `allowed_transitions`, et ne doit être recopiée nulle part côté client.
///
/// Elle l'était pourtant trois fois — un `switch` dans l'écran d'accueil, un
/// dans l'écran des livraisons, un troisième implicite dans l'écran de suivi —
/// et chacun avait un trou différent :
///
/// * l'écran des livraisons n'avait **pas de cas pour `accepted`** : sur une
///   course fraîchement acceptée, son bouton « Suivant » tombait dans le
///   `default` et ne faisait rien, sans message ;
/// * l'écran de suivi affichait « Livré » **dès l'acceptation**, une
///   transition que la machine refuse — l'appui produisait une erreur d'API
///   pour un geste que rien n'avait signalé comme impossible.
void main() {
  eccore.Assignment affectation({
    required String statut,
    required List<String> transitions,
    String reference = 'CMD-0001',
    String? livreeLe,
  }) {
    return eccore.Assignment.fromJson({
      'id': 'course-1',
      'order': 'a1b2c3d4-0000-0000-0000-000000000001',
      'order_reference': reference,
      'restaurant_name': 'El Corazón Lomé',
      'pickup_location': {'lat': 6.13, 'lon': 1.22},
      'delivery_address_line': 'Rue du Commerce, Lomé',
      'delivery_landmark': '',
      'delivery_location': {'lat': 6.14, 'lon': 1.23},
      'recipient_name': 'Awa',
      'recipient_phone': '+22890000000',
      'courier': {
        'id': 'livreur-7',
        'full_name': 'Kodjo',
        'vehicle_type': 'moto',
        'rating_average': '4.8',
        'rating_count': 12,
      },
      'status': statut,
      'allowed_transitions': transitions,
      'courier_fee': {'amount': '1000', 'currency': 'XOF'},
      'offered_at': '2026-08-02T12:00:00Z',
      'delivered_at': livreeLe,
      'created_at': '2026-08-02T11:59:00Z',
      'updated_at': '2026-08-02T12:00:00Z',
    });
  }

  Course course({
    required String statut,
    required List<String> transitions,
    String reference = 'CMD-0001',
    String? livreeLe,
  }) {
    return Course(
      assignment: affectation(
        statut: statut,
        transitions: transitions,
        reference: reference,
        livreeLe: livreeLe,
      ),
    );
  }

  group('La prochaine étape vient du serveur', () {
    test('une course acceptée mène à la récupération', () {
      // Le trou de l'écran des livraisons : ce cas-là rendait `null` et le
      // bouton ne faisait rien.
      final c = course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const ['cancelled', 'picked_up'],
      );

      expect(c.prochaineEtape, EtapeCourse.recuperee);
    });

    test('une course récupérée mène au départ', () {
      final c = course(
        statut: eccore.DeliveryStatus.pickedUp,
        transitions: const ['on_the_way'],
      );

      expect(c.prochaineEtape, EtapeCourse.enRoute);
    });

    test('une course en route mène à la livraison', () {
      final c = course(
        statut: eccore.DeliveryStatus.onTheWay,
        transitions: const ['delivered'],
      );

      expect(c.prochaineEtape, EtapeCourse.livree);
    });

    test('une course livrée ne mène nulle part', () {
      // La machine est acyclique : rejouer `delivered` réincrémenterait les
      // compteurs du livreur (constat C3 de l'audit).
      final c = course(
        statut: eccore.DeliveryStatus.delivered,
        transitions: const [],
      );

      expect(c.prochaineEtape, isNull);
    });

    test('la livraison n\'est pas proposée depuis l\'acceptation', () {
      // Le défaut de l'écran de suivi : « Livré » s'affichait dès
      // l'acceptation, sur une transition que le serveur refuse.
      final c = course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const ['cancelled', 'picked_up'],
      );

      expect(c.prochaineEtape, isNot(EtapeCourse.livree));
    });

    test('une annulation n\'est jamais l\'étape suivante', () {
      // `cancelled` et `declined` sont des issues, pas des progressions : les
      // laisser tomber sous le bouton « suivant » ferait annuler une course
      // d'un geste destiné à la faire avancer.
      final c = course(
        statut: eccore.DeliveryStatus.offered,
        transitions: const ['accepted', 'cancelled', 'declined'],
      );

      expect(c.prochaineEtape, isNull);
    });
  });

  group('Accepter et refuser suivent le serveur', () {
    test('une course proposée peut être acceptée et refusée', () {
      final c = course(
        statut: eccore.DeliveryStatus.offered,
        transitions: const ['accepted', 'cancelled', 'declined'],
      );

      expect(c.peutAccepter, isTrue);
      expect(c.peutRefuser, isTrue);
      expect(c.estProposee, isTrue);
    });

    test('une course déjà acceptée ne se réaccepte ni ne se refuse', () {
      // L2 — l'exclusivité est tenue côté serveur ; l'écran ne doit pas
      // proposer un geste voué au refus.
      final c = course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const ['cancelled', 'picked_up'],
      );

      expect(c.peutAccepter, isFalse);
      expect(c.peutRefuser, isFalse);
    });
  });

  group('La destination dépend de l\'étape', () {
    test('avant la récupération, le livreur va au restaurant', () {
      final c = course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const ['picked_up'],
      );

      expect(c.repasRecupere, isFalse);
    });

    test('après la récupération, il va chez le client', () {
      for (final statut in [
        eccore.DeliveryStatus.pickedUp,
        eccore.DeliveryStatus.onTheWay,
        eccore.DeliveryStatus.delivered,
      ]) {
        expect(
          course(statut: statut, transitions: const []).repasRecupere,
          isTrue,
          reason: 'le repas est en main à l\'étape $statut',
        );
      }
    });

    test('les deux points viennent de l\'affectation', () {
      // L'écran de suivi géocodait la chaîne d'adresse et retombait sur
      // `LatLng(5.3599, -4.0083)` — Abidjan — quand le géocodage échouait ;
      // le restaurant, lui, était écrit en dur.
      final c = course(
        statut: eccore.DeliveryStatus.accepted,
        transitions: const ['picked_up'],
      );

      expect(c.latitudeRetrait, 6.13);
      expect(c.longitudeRetrait, 1.22);
      expect(c.latitudeLivraison, 6.14);
      expect(c.longitudeLivraison, 1.23);
    });
  });

  group('Références et dates', () {
    test('la référence est celle du serveur', () {
      final c = course(
        statut: eccore.DeliveryStatus.onTheWay,
        transitions: const ['delivered'],
      );

      expect(c.reference, 'CMD-0001');
    });

    test('une référence absente retombe sur un identifiant court', () {
      final c = course(
        statut: eccore.DeliveryStatus.onTheWay,
        transitions: const ['delivered'],
        reference: '',
      );

      expect(c.reference, 'COURSE-1');
    });

    test('la date de livraison est celle que le serveur horodate', () {
      // Les gains et l'historique se groupaient sur `passeeLe`, qui vaut
      // `offered_at` sur une course livrée : une course proposée avant minuit
      // et livrée après comptait pour la veille.
      final c = course(
        statut: eccore.DeliveryStatus.delivered,
        transitions: const [],
        livreeLe: '2026-08-03T00:10:00Z',
      );

      expect(c.livreeLe, DateTime.utc(2026, 8, 3, 0, 10));
      expect(c.passeeLe, DateTime.utc(2026, 8, 2, 12));
    });

    test('une course non livrée n\'a pas de date de livraison', () {
      final c = course(
        statut: eccore.DeliveryStatus.onTheWay,
        transitions: const ['delivered'],
      );

      expect(c.livreeLe, isNull);
    });
  });
}
