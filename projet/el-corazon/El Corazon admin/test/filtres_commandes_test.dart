import 'package:admin/models/order.dart';
import 'package:admin/presentation/filtres_commandes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les trois filtres de `order_management_screen.dart` : recherche, zone,
/// fenêtre de temps.
///
/// Ces cas décrivent ce que l'écran fait **aujourd'hui**, y compris là où ce
/// qu'il fait n'a pas de sens (voir le groupe sur les zones). Ils sont écrits
/// avant toute correction, pour que la correction — si elle est décidée — se
/// voie.
Order _commande({
  String id = 'commande-1',
  String destinataire = 'Awa',
  String adresse = 'Rue du Commerce',
  DateTime? passeeLe,
}) {
  final quand = passeeLe ?? DateTime(2026, 8, 8, 12);

  return Order(
    id: id,
    userId: '',
    items: const [],
    subtotal: 4500,
    total: 4500,
    status: OrderStatus.preparing,
    deliveryAddress: adresse,
    recipientName: destinataire,
    paymentMethod: PaymentMethod.cash,
    orderTime: quand,
    createdAt: quand,
  );
}

void main() {
  final maintenant = DateTime(2026, 8, 8, 14, 30);

  List<Order> filtre(
    List<Order> commandes, {
    String recherche = '',
    ZoneCommandes zone = ZoneCommandes.toutes,
    FenetreCommandes fenetre = FenetreCommandes.toutes,
  }) =>
      commandesFiltrees(
        commandes,
        recherche: recherche,
        zone: zone,
        fenetre: fenetre,
        maintenant: maintenant,
      );

  group('Recherche', () {
    final commandes = [
      _commande(id: 'aaa-111', destinataire: 'Awa Koffi'),
      _commande(id: 'bbb-222', destinataire: 'Kodjo Mensah', adresse: 'Rue Kpota'),
    ];

    test('porte sur la référence, le destinataire et l’adresse', () {
      expect(filtre(commandes, recherche: 'bbb').single.id, 'bbb-222');
      expect(filtre(commandes, recherche: 'kodjo').single.id, 'bbb-222');
      expect(filtre(commandes, recherche: 'kpota').single.id, 'bbb-222');
    });

    test('la casse est ignorée', () {
      expect(filtre(commandes, recherche: 'AWA').single.id, 'aaa-111');
    });

    test('un destinataire vide ne fait pas correspondre n’importe quoi', () {
      final anonyme = [_commande(id: 'zzz', destinataire: '', adresse: 'Rue X')];
      expect(filtre(anonyme, recherche: 'awa'), isEmpty);
    });

    test('les espaces ne sont **pas** rognés ici', () {
      // Contrairement à l'écran de gestion avancée, qui fait un `trim()`.
      // Deux écrans, deux comportements — c'est l'existant, pas un choix.
      expect(filtre(commandes, recherche: ' awa '), isEmpty);
    });
  });

  group('Fenêtre de temps', () {
    final aujourdHui = _commande(id: 'ce-jour', passeeLe: DateTime(2026, 8, 8, 9));
    final hier = _commande(id: 'hier', passeeLe: DateTime(2026, 8, 7, 23));
    final ilYaDixJours = _commande(id: 'dix-jours', passeeLe: DateTime(2026, 7, 29));
    final ilYaUnAn = _commande(id: 'un-an', passeeLe: DateTime(2025, 8, 8));
    final toutes = [aujourdHui, hier, ilYaDixJours, ilYaUnAn];

    List<String> gardees(FenetreCommandes fenetre) =>
        filtre(toutes, fenetre: fenetre).map((c) => c.id).toList();

    test('« aujourd’hui » compare le jour, pas les 24 dernières heures', () {
      // Une commande d'hier 23 h a moins de 24 h ; elle est pourtant écartée.
      expect(gardees(FenetreCommandes.aujourdHui), ['ce-jour']);
    });

    test('« cette semaine » retient sept jours glissants', () {
      expect(gardees(FenetreCommandes.cetteSemaine), ['ce-jour', 'hier']);
    });

    test('« ce mois » retient trente jours glissants', () {
      expect(gardees(FenetreCommandes.ceMois),
          ['ce-jour', 'hier', 'dix-jours'],);
    });

    test('« toutes » ne retient rien de moins', () {
      expect(gardees(FenetreCommandes.toutes), hasLength(4));
    });
  });

  group('Zones — l’écran cherche des quartiers de Dakar', () {
    test('les mots-clés reconnus sont sénégalais', () {
      expect(zoneDeLAdresse('Cité Mermoz'), ZoneCommandes.nord);
      expect(zoneDeLAdresse('Marché de Pikine'), ZoneCommandes.sud);
      expect(zoneDeLAdresse('Yoff Virage'), ZoneCommandes.nord);
    });

    test('une adresse de Lomé tombe dans « Centre », quelle qu’elle soit', () {
      // Le restaurant est à Lomé. Aucun de ces quartiers n'est reconnu : soit
      // un mot générique les attrape, soit le repli le fait.
      for (final adresse in [
        'Bè-Kpota',
        'Tokoin Hôpital',
        'Adidogomé',
        'Agoè-Nyivé',
        'Baguida',
      ]) {
        expect(
          zoneDeLAdresse(adresse),
          ZoneCommandes.centre,
          reason: '« $adresse » devrait pouvoir être ailleurs qu’au centre',
        );
      }
    });

    test('« Zone 2 » et « Zone 3 » ne rendent donc jamais rien à Lomé', () {
      final lome = [
        _commande(id: 'a', adresse: 'Bè-Kpota'),
        _commande(id: 'b', adresse: 'Agoè-Nyivé'),
      ];

      expect(filtre(lome, zone: ZoneCommandes.nord), isEmpty);
      expect(filtre(lome, zone: ZoneCommandes.sud), isEmpty);
      expect(filtre(lome, zone: ZoneCommandes.centre), hasLength(2));
    });

    test('l’ordre de recherche fait gagner le centre sur le nord', () {
      // « avenue » est un mot du centre ; il est testé avant ceux du nord.
      expect(zoneDeLAdresse('Avenue de Yoff'), ZoneCommandes.centre);
    });

    test('« toutes les zones » ne consulte pas l’adresse', () {
      expect(filtre([_commande(adresse: 'Pikine')]), hasLength(1));
    });
  });

  group('L’ordre et la liste d’origine', () {
    test('les plus récentes d’abord', () {
      final commandes = [
        _commande(id: 'milieu', passeeLe: DateTime(2026, 8, 5)),
        _commande(id: 'vieille', passeeLe: DateTime(2026, 8)),
        _commande(id: 'fraiche', passeeLe: DateTime(2026, 8, 8)),
      ];

      expect(filtre(commandes).map((c) => c.id).toList(),
          ['fraiche', 'milieu', 'vieille'],);
    });

    test('trier ne réordonne pas ce que le service détient', () {
      final commandes = [
        _commande(id: 'un', passeeLe: DateTime(2026, 8)),
        _commande(id: 'deux', passeeLe: DateTime(2026, 8, 8)),
      ];

      filtre(commandes);

      expect(commandes.map((c) => c.id).toList(), ['un', 'deux']);
    });
  });
}
