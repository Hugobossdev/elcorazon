import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/presentation/reglement_commande.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Deux mensonges de l'application cliente, et ce qui les empêche de revenir.
///
/// * Une ligne refusée par le serveur restait au panier, **absente** du panier
///   serveur dont la commande est faite : le client commandait sans le plat
///   qu'il voyait. Elle bloque désormais la commande, motif à l'appui.
/// * Le détail de commande disait « Réglé par … » sur toutes les commandes,
///   payées ou non. Il lit désormais ce que le serveur a encaissé.
void main() {
  group('Une ligne refusée par le serveur', () {
    late CartService panier;

    eccore.MenuItem article(String id, String nom) => eccore.MenuItem(
          id: id,
          restaurantSlug: 'el-corazon',
          categorySlug: 'burgers',
          categoryName: 'Burgers',
          name: nom,
          slug: id,
          description: '',
          image: null,
          price: const eccore.Money(amountMinor: 4000, currency: 'XOF'),
          preparationMinutes: 10,
          allergens: const [],
          dietaryTags: const [],
          isAvailable: true,
          isPopular: false,
          vipExclusive: false,
          ratingAverage: 0,
          ratingCount: 0,
          sortOrder: 0,
        );

    setUp(() {
      panier = CartService();
      panier.clear();
      panier.enregistrerLesRefus(const {});
      panier
        ..addItem(article('burger', 'Burger Poulet'))
        ..addItem(article('frites', 'Frites'));
    });

    test('bloque la commande et nomme le plat', () {
      final frites = panier.items.firstWhere((l) => l.menuItemId == 'frites');
      panier.enregistrerLesRefus({frites.id: 'Cet article n’est plus disponible.'});

      expect(panier.motifDeRefus(frites.id), 'Cet article n’est plus disponible.');
      expect(panier.motifBloquant, contains('« Frites »'));
      expect(panier.motifBloquant, isNot(contains('Burger')));
    });

    test('retirer la ligne refusée lève le blocage, sans attendre le serveur', () {
      final index = panier.items.indexWhere((l) => l.menuItemId == 'frites');
      panier.enregistrerLesRefus({panier.items[index].id: 'Indisponible'});

      panier.removeItem(index);

      expect(panier.motifBloquant, isNull);
    });

    test('un plat retiré du menu se dit en clair, sans identifiant technique', () {
      // La réponse réelle du serveur local, le 2026-09-24 : 400 de validation,
      // sans `detail`, le motif enfoui dans `errors.menu_item`.
      const retire = eccore.ApiException(
        status: 400,
        code: 'invalid',
        detail: 'Clé primaire « 01a0d52a-6a60-7b89 » non valide - l’objet n’existe pas.',
        errors: {
          'menu_item': ['Clé primaire « 01a0d52a-6a60-7b89 » non valide - l’objet n’existe pas.'],
        },
      );
      const regle = eccore.ApiException(
        status: 409,
        code: 'business_rule_violation',
        detail: 'L’option « Bacon » n’est pas disponible.',
      );

      expect(CartService.motifDeLigneRefusee(retire), 'Ce plat n’est plus au menu.');
      // Un refus métier porte déjà sa phrase : on la garde.
      expect(CartService.motifDeLigneRefusee(regle), 'L’option « Bacon » n’est pas disponible.');
    });

    test('une synchronisation sans refus oublie les précédents', () {
      final frites = panier.items.firstWhere((l) => l.menuItemId == 'frites');
      panier.enregistrerLesRefus({frites.id: 'Indisponible'});

      panier.enregistrerLesRefus(const {});

      expect(panier.motifDeRefus(frites.id), isNull);
      expect(panier.motifBloquant, isNull);
    });
  });

  group('Le règlement affiché', () {
    Order commande({
      double? regle,
      PaymentMethod moyen = PaymentMethod.mobileMoney,
      OrderStatus statut = OrderStatus.pending,
    }) {
      final maintenant = DateTime(2026, 9, 24, 12);
      return Order(
        id: 'commande-1',
        userId: 'client-1',
        items: const [],
        subtotal: 6500,
        total: 7500,
        deliveryAddress: 'Bè, Lomé',
        paymentMethod: moyen,
        orderTime: maintenant,
        createdAt: maintenant,
        status: statut,
        montantRegle: regle,
      );
    }

    test('« réglé » seulement quand le serveur a encaissé le total', () {
      expect(situationDuReglement(commande(regle: 7500)), SituationDuReglement.reglee);
      expect(libelleDuReglement(commande(regle: 7500)), 'Réglé par Mobile Money');
    });

    test('un paiement en ligne non encaissé est en attente, pas réglé', () {
      expect(situationDuReglement(commande(regle: 0)), SituationDuReglement.enAttente);
      // Un règlement partiel ne solde pas la commande.
      expect(situationDuReglement(commande(regle: 5000)), SituationDuReglement.enAttente);
    });

    test('les espèces se règlent à la livraison', () {
      expect(
        situationDuReglement(commande(regle: 0, moyen: PaymentMethod.cash)),
        SituationDuReglement.aLaLivraison,
      );
      expect(
        libelleDuReglement(commande(regle: 0, moyen: PaymentMethod.cash)),
        'Espèces, à régler à la livraison',
      );
      // Livrée, le serveur a enregistré la remise (`apps/payments/cash.py`) :
      // c'est le montant encaissé qui le dit, pas le statut.
      expect(
        libelleDuReglement(
          commande(regle: 7500, moyen: PaymentMethod.cash, statut: OrderStatus.delivered),
        ),
        'Réglé par Espèces à la livraison',
      );
    });

    test('une commande annulée sans encaissement ne propose pas de payer', () {
      expect(
        situationDuReglement(commande(regle: 0, statut: OrderStatus.cancelled)),
        SituationDuReglement.sansEncaissement,
      );
    });

    test('sans montant connu, on ne prétend rien', () {
      expect(situationDuReglement(commande()), SituationDuReglement.inconnue);
      expect(libelleDuReglement(commande()), isNot(contains('Réglé')));
    });

    test('le montant encaissé survit au cache local', () {
      final relue = Order.fromMap(commande(regle: 7500).toMap());
      expect(relue.montantRegle, 7500);
    });
  });
}
