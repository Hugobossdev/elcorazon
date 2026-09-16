import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trois contrats ajoutés pour rendre la chaîne livraison cohérente.
///
/// * le **statut de la commande** sur la course, sans lequel l'application du
///   livreur proposait de récupérer un repas encore en cuisine ;
/// * le **livreur** sur le suivi, sans lequel le client ne pouvait ni le
///   joindre ni le noter ;
/// * la **file de production**, sans laquelle le poste de cuisine affichait
///   « 3 article(s) » au lieu des plats.
void main() {
  group('Le statut de la commande, porté par la course', () {
    Assignment course({String? statutCommande}) => Assignment.fromJson({
      'id': 'course-1',
      'order': 'commande-1',
      'order_reference': 'CMD-0001',
      'restaurant_name': 'El Corazón Lomé',
      'pickup_location': {'lat': 6.13, 'lon': 1.22},
      'delivery_address_line': 'Rue du Commerce',
      'delivery_location': {'lat': 6.14, 'lon': 1.23},
      'recipient_name': 'Awa',
      'recipient_phone': '+22890000000',
      'courier': {
        'id': 'livreur-7',
        'full_name': 'Kodjo',
        'vehicle_type': 'motorcycle',
        'rating_average': '4.8',
        'rating_count': 12,
      },
      'status': DeliveryStatus.accepted,
      'allowed_transitions': const ['picked_up'],
      'offered_at': '2026-09-16T10:00:00Z',
      'created_at': '2026-09-16T10:00:00Z',
      'updated_at': '2026-09-16T10:00:00Z',
      if (statutCommande != null) 'order_status': statutCommande,
    });

    test('une commande en préparation n’est pas prête à être retirée', () {
      // C'est l'état où le bouton « J'ai récupéré la commande » s'affichait, et
      // où le serveur l'acceptait : la course allait jusqu'à « livrée » pendant
      // que la commande restait en cuisine.
      expect(course(statutCommande: 'preparing').repasPretARetirer, isFalse);
      expect(course(statutCommande: 'confirmed').repasPretARetirer, isFalse);
    });

    test('une commande prête, ou plus avancée, l’est', () {
      for (final statut in ['ready', 'picked_up', 'on_the_way', 'delivered']) {
        expect(
          course(statutCommande: statut).repasPretARetirer,
          isTrue,
          reason: 'le repas est sorti de cuisine depuis $statut',
        );
      }
    });

    test('un serveur qui ne dit rien ne bloque pas le livreur', () {
      // Le champ est neuf : devant un serveur antérieur, masquer le geste
      // immobiliserait un livreur que le serveur, lui, laisserait passer. Le
      // refus métier reste le filet.
      expect(course().orderStatus, isEmpty);
      expect(course().repasPretARetirer, isTrue);
    });
  });

  group('Le livreur, tel que le client le voit', () {
    OrderTracking suivi(Map<String, dynamic>? livreur, {String etape = 'accepted'}) =>
        OrderTracking.fromJson({
          'order': 'commande-1',
          'assignment_status': etape,
          'courier': livreur,
          'last_position': null,
          'estimated_delivery_at': null,
        });

    test('aucun livreur : rien à joindre, rien à noter', () {
      expect(suivi(null, etape: '').hasCourier, isFalse);
      expect(suivi(null, etape: '').courier, isNull);
    });

    test('une course proposée ne nomme personne', () {
      // Le serveur ne rend pas le livreur tant qu'il n'a pas accepté : il peut
      // encore refuser, et annoncer son nom au client serait une promesse.
      expect(suivi(null, etape: 'offered').hasCourier, isFalse);
    });

    test('une course engagée porte de quoi appeler', () {
      final livreur = suivi({
        'id': 'livreur-7',
        'full_name': 'Kodjo Mensah',
        'avatar': null,
        'vehicle_type': 'motorcycle',
        'rating_average': '4.8',
        'rating_count': 12,
        'phone': '+22890000001',
      }).courier!;

      expect(livreur.fullName, 'Kodjo Mensah');
      expect(livreur.telephone, '+22890000001');
      expect(livreur.joignable, isTrue);
      expect(livreur.ratingCount, 12);
    });

    test('une fois livrée, le numéro n’est plus rendu', () {
      final livreur = suivi(
        {
          'id': 'livreur-7',
          'full_name': 'Kodjo Mensah',
          'rating_average': '4.8',
          'rating_count': 12,
          'phone': '',
        },
        etape: 'delivered',
      ).courier!;

      // L'identité reste — il faut savoir qui noter — mais il n'y a plus
      // personne à joindre pour cette course.
      expect(livreur.fullName, 'Kodjo Mensah');
      expect(livreur.joignable, isFalse);
    });

    test('un livreur sans nom reste affichable', () {
      expect(suivi({'id': 'x', 'full_name': ''}).courier!.nomAffiche, 'Livreur');
    });

    test('une map vide vaut « aucun livreur »', () {
      // C'est ce que rendait le serveur avant que le champ ne devienne nul :
      // un client à jour doit rester lisible devant l'un comme devant l'autre.
      expect(suivi(const {}).hasCourier, isFalse);
    });
  });

  group('La file de production', () {
    test('une commande porte ses plats, leurs options et les remarques', () {
      final commande = KitchenOrder.fromJson({
        'id': 'commande-1',
        'reference': 'EC000123',
        'status': 'preparing',
        'allowed_transitions': const ['ready', 'cancelled'],
        'placed_at': '2026-09-16T12:00:00Z',
        'estimated_delivery_at': null,
        'items_count': 3,
        'delivery_instructions': 'Sans couverts',
        'lines': [
          {
            'id': 'ligne-1',
            'item_name': 'Burger Corazón',
            'quantity': 2,
            'options': [
              {'group': 'Cuisson', 'option': 'À point'},
            ],
            'notes': 'Sans oignons',
          },
        ],
      });

      expect(commande.reference, 'EC000123');
      expect(commande.itemsCount, 3);
      expect(commande.deliveryInstructions, 'Sans couverts');
      final ligne = commande.lines.single;
      // Seul le choix est gardé : « Cuisson » n'apprend rien à qui lit
      // « À point ».
      expect(ligne.options, ['À point']);
      expect(ligne.notes, 'Sans oignons');
      expect(ligne.libelle, '2 × Burger Corazón (À point)');
    });

    test('une ligne sans option ni remarque reste lisible', () {
      final commande = KitchenOrder.fromJson({
        'id': 'commande-2',
        'reference': 'EC000124',
        'status': 'confirmed',
        'allowed_transitions': const <String>[],
        'placed_at': '2026-09-16T12:00:00Z',
        'lines': [
          {'id': 'l', 'item_name': 'Jus de bissap', 'quantity': 1},
        ],
      });

      expect(commande.lines.single.libelle, '1 × Jus de bissap');
      expect(commande.lines.single.options, isEmpty);
    });
  });
}
