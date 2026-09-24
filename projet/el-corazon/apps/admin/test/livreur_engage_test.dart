import 'package:admin/presentation/statut_livreur.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// L6 — le siège cesse de proposer un livreur déjà en route.
///
/// ## Ce que le back-office ne savait pas
///
/// `StatutLivreur` n'a que trois états, et son en-tête le documente : le
/// quatrième — « en livraison » — avait été retiré parce que *rien ne le
/// produisait*. `CourierProfile` ne porte pas ses affectations, et aucune route
/// ne les listait alors par livreur.
///
/// L'écran affichait donc « Disponible » en face de quelqu'un qui roulait vers
/// un autre client, et le proposait à l'assignation. Le serveur l'acceptait —
/// rien ne l'interdisait — et `Dely`, qui ne suit qu'une course, laissait le
/// second client devant un livreur figé.
///
/// Le serveur refuse désormais (`one_engaged_assignment_per_courier`). Ces cas
/// vérifient l'autre moitié : que l'écran ne propose plus ce que le serveur
/// rejettera. La donnée était là — `AssignmentService` charge les courses
/// vivantes du périmètre — il suffisait de la lire par livreur.
Map<String, dynamic> _courseJson({
  required String id,
  required String commandeId,
  required String statut,
  String livreurId = 'livreur-1',
}) {
  return {
    'id': id,
    'order': commandeId,
    'order_reference': 'EC000001',
    'restaurant_name': 'El Corazón',
    'pickup_location': {'lat': 6.1725, 'lon': 1.2314},
    'delivery_address_line': 'Rue des Cocotiers',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.1319, 'lon': 1.2255},
    'recipient_name': 'Ama K.',
    'recipient_phone': '+22890000000',
    'courier': {
      'id': livreurId,
      'full_name': 'Kofi A.',
      'vehicle_type': 'motorcycle',
      'rating_average': '4.8',
      'rating_count': 9,
      'avatar': null,
    },
    'status': statut,
    'allowed_transitions': const <String>[],
    'courier_fee': null,
    'offered_at': '2026-09-07T10:00:00Z',
    'accepted_at': null,
    'picked_up_at': null,
    'delivered_at': null,
    'decline_reason': '',
    'created_at': '2026-09-07T10:00:00Z',
    'updated_at': '2026-09-07T10:00:00Z',
  };
}

eccore.Assignment _course({
  required String statut,
  String id = 'course-1',
  String commandeId = 'commande-1',
  String livreurId = 'livreur-1',
}) {
  return eccore.Assignment.fromJson(
    _courseJson(
      id: id,
      commandeId: commandeId,
      statut: statut,
      livreurId: livreurId,
    ),
  );
}

void main() {
  group('Une course engagée', () {
    test('l’acceptation engage le livreur', () {
      expect(_course(statut: eccore.DeliveryStatus.accepted).isEngaged, isTrue);
    });

    test('l’enlèvement et la route aussi', () {
      expect(_course(statut: eccore.DeliveryStatus.pickedUp).isEngaged, isTrue);
      expect(_course(statut: eccore.DeliveryStatus.onTheWay).isEngaged, isTrue);
    });

    test('une proposition en attente n’engage personne', () {
      final proposee = _course(statut: eccore.DeliveryStatus.offered);

      // Vivante, mais pas engageante : le livreur peut en recevoir plusieurs et
      // choisir. Confondre les deux lui ferait bloquer sa propre file en ne
      // répondant pas.
      expect(proposee.isActive, isTrue);
      expect(proposee.isEngaged, isFalse);
    });

    test('une course finie n’engage plus', () {
      for (final statut in [
        eccore.DeliveryStatus.delivered,
        eccore.DeliveryStatus.declined,
        eccore.DeliveryStatus.cancelled,
      ]) {
        expect(_course(statut: statut).isEngaged, isFalse, reason: statut);
      }
    });
  });

  group('Le dossier livreur ne dit rien de ses courses', () {
    eccore.CourierProfile livreur(String id) => eccore.CourierProfile.fromJson({
          'id': id,
          'full_name': 'Kofi $id',
          'email': '$id@elcorazon.test',
          'phone': '+22890000000',
          'restaurant': 'el-corazon-lome',
          'verification_status': 'approved',
          'id_document': null,
          'licence_document': null,
          'vehicle_document': null,
          'verification_notes': '',
          'verified_at': null,
          'vehicle_type': 'motorcycle',
          'vehicle_plate': '',
          'is_online': true,
          'can_accept_orders': true,
          'last_location': null,
          'last_location_at': null,
          'deliveries_completed': 12,
          'deliveries_cancelled': 0,
          'rating_average': '4.8',
          'rating_count': 9,
          'total_earnings': null,
          'created_at': '2026-09-01T10:00:00Z',
          'updated_at': '2026-09-07T10:00:00Z',
        });

    test('un livreur engagé reste « Disponible » à ses propres yeux', () {
      // Le dossier ne sait rien des affectations, et ce n'est pas un défaut :
      // c'est pourquoi l'éligibilité se demande au serveur, pour une commande
      // donnée (`GET /delivery/couriers/available/{id}/`). Épinglé pour que
      // personne ne « corrige » `StatutLivreur` en croyant le compléter — et
      // pour que personne ne refasse le filtre ici, comme le dialogue
      // d'affectation le faisait : il y oubliait la cuisine de la commande et
      // le périmètre de zone. Voir `assignation_livreur_test.dart`.
      expect(livreur('a').statut, StatutLivreur.disponible);
    });

    test('la distance à la cuisine n’est pas un champ du dossier', () {
      // Elle n'existe que sur la route des éligibles, calculée par PostGIS
      // depuis la position du restaurant. Nulle ailleurs : un zéro laisserait
      // croire que le livreur est sur le pas de la porte.
      expect(livreur('a').distanceM, isNull);
    });
  });
}
