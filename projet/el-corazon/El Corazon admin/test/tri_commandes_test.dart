import 'package:admin/models/order.dart';
import 'package:admin/presentation/tri_commandes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recherche et tri de la liste des commandes du back-office.
///
/// Ce que ces tests valident, c'est le lot 4 lui-même : ces règles vivaient au
/// milieu de 3 067 lignes de widgets et n'étaient atteignables qu'en montant
/// l'arbre. C'est ce critère, et non un nombre de lignes, qui dit si un écran
/// est découpé.
Order _commande({
  String id = 'commande-1',
  String destinataire = 'Awa',
  String adresse = 'Rue du Commerce',
  double total = 4500,
  OrderStatus statut = OrderStatus.preparing,
  DateTime? passeeLe,
}) {
  return Order(
    id: id,
    userId: '',
    items: const [],
    subtotal: total,
    total: total,
    status: statut,
    deliveryAddress: adresse,
    recipientName: destinataire,
    paymentMethod: PaymentMethod.cash,
    orderTime: passeeLe ?? DateTime(2026, 8, 8, 12),
    createdAt: passeeLe ?? DateTime(2026, 8, 8, 12),
  );
}

void main() {
  group('Recherche', () {
    final commandes = [
      _commande(id: 'aaa-111', destinataire: 'Awa Koffi'),
      _commande(id: 'bbb-222', destinataire: 'Kodjo Mensah', adresse: 'Avenue de la Paix'),
      _commande(id: 'ccc-333', destinataire: 'Ama Doe', adresse: 'Boulevard du Mono'),
    ];

    test('sans terme, rien n’est écarté', () {
      expect(commandesAffichees(commandes), hasLength(3));
    });

    test('par référence', () {
      final trouvees = commandesAffichees(commandes, recherche: 'bbb');
      expect(trouvees.single.id, 'bbb-222');
    });

    test('par nom du destinataire', () {
      final trouvees = commandesAffichees(commandes, recherche: 'kodjo');
      expect(trouvees.single.recipientName, 'Kodjo Mensah');
    });

    test('par adresse', () {
      final trouvees = commandesAffichees(commandes, recherche: 'mono');
      expect(trouvees.single.deliveryAddress, 'Boulevard du Mono');
    });

    test('la casse et les espaces de bordure sont ignorés', () {
      // On cherche « Awa » après l'avoir collé depuis un message.
      for (final terme in ['awa', 'AWA', '  Awa  ']) {
        expect(
          commandesAffichees(commandes, recherche: terme).single.id,
          'aaa-111',
          reason: 'le terme « $terme » doit trouver la même commande',
        );
      }
    });

    test('un terme qui ne correspond à rien rend une liste vide', () {
      expect(commandesAffichees(commandes, recherche: 'zzz'), isEmpty);
    });

    test('« a » trouve tout ce qui contient un a', () {
      // La recherche est une inclusion, pas un préfixe : un opérateur au
      // téléphone n'a pas le début de la référence, il en a un morceau.
      expect(commandesAffichees(commandes, recherche: 'a'), hasLength(3));
    });
  });

  group('Tri', () {
    final tot = _commande(id: 'tot', total: 1000, passeeLe: DateTime(2026, 8));
    final milieu = _commande(id: 'milieu', total: 5000, passeeLe: DateTime(2026, 8, 5));
    final tard = _commande(id: 'tard', total: 3000, passeeLe: DateTime(2026, 8, 9));
    final commandes = [milieu, tard, tot];

    List<String> ordre(TriCommandes tri) =>
        commandesAffichees(commandes, tri: tri).map((c) => c.id).toList();

    test('par date, du plus récent au plus ancien par défaut', () {
      expect(commandesAffichees(commandes).map((c) => c.id).toList(),
          ['tard', 'milieu', 'tot'],);
    });

    test('par date croissante', () {
      expect(ordre(TriCommandes.dateCroissante), ['tot', 'milieu', 'tard']);
    });

    test('par total', () {
      expect(ordre(TriCommandes.totalCroissant), ['tot', 'tard', 'milieu']);
      expect(ordre(TriCommandes.totalDecroissant), ['milieu', 'tard', 'tot']);
    });

    test('par statut, dans l’ordre du cycle de vie', () {
      final parStatut = commandesAffichees(
        [
          _commande(id: 'livree', statut: OrderStatus.delivered),
          _commande(id: 'attente', statut: OrderStatus.pending),
          _commande(id: 'prete', statut: OrderStatus.ready),
        ],
        tri: TriCommandes.statut,
      );

      expect(parStatut.map((c) => c.id).toList(), ['attente', 'prete', 'livree']);
    });
  });

  group('La liste d’origine n’est pas touchée', () {
    test('trier ne réordonne pas ce que le service détient', () {
      // Un tri en place changerait l'ordre lu par les autres écrans.
      final commandes = [
        _commande(id: 'un', passeeLe: DateTime(2026, 8)),
        _commande(id: 'deux', passeeLe: DateTime(2026, 8, 9)),
      ];

      commandesAffichees(commandes, tri: TriCommandes.dateCroissante);

      expect(commandes.map((c) => c.id).toList(), ['un', 'deux']);
    });
  });
}
