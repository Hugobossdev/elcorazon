import 'package:admin/models/order.dart';
import 'package:admin/presentation/evolution_commandes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le comptage derrière le graphe « Évolution des commandes (7 derniers
/// jours) » du back-office.
Order _commande(DateTime passeeLe) => Order(
      id: 'commande-${passeeLe.microsecondsSinceEpoch}',
      userId: '',
      items: const [],
      subtotal: 1000,
      total: 1000,
      status: OrderStatus.delivered,
      deliveryAddress: 'Rue du Commerce',
      recipientName: 'Awa',
      paymentMethod: PaymentMethod.cash,
      orderTime: passeeLe,
      createdAt: passeeLe,
    );

void main() {
  final maintenant = DateTime(2026, 8, 8, 14, 30);

  Map<String, int> compte(List<Order> commandes) =>
      commandesParJour(commandes, maintenant: maintenant);

  group('La fenêtre', () {
    test('couvre sept jours, aujourd’hui compris', () {
      final parJour = compte(const []);

      expect(parJour, hasLength(7));
      expect(parJour.keys.first, '2026-08-02');
      expect(parJour.keys.last, '2026-08-08');
    });

    test('les jours sans commande valent zéro, ils ne manquent pas', () {
      // Le graphe doit dessiner une colonne vide, pas sauter le jour.
      expect(compte(const []).values, everyElement(0));
    });

    test('l’ordre alphabétique des clés est l’ordre chronologique', () {
      final clefs = compte(const []).keys.toList();
      expect(clefs, orderedEquals(List<String>.of(clefs)..sort()));
    });

    test('la largeur se règle', () {
      expect(commandesParJour(const [], jours: 3, maintenant: maintenant),
          hasLength(3),);
    });
  });

  group('Le comptage', () {
    test('range chaque commande dans son jour', () {
      final parJour = compte([
        _commande(DateTime(2026, 8, 8, 9)),
        _commande(DateTime(2026, 8, 8, 20)),
        _commande(DateTime(2026, 8, 6, 12)),
      ]);

      expect(parJour['2026-08-08'], 2);
      expect(parJour['2026-08-06'], 1);
      expect(parJour['2026-08-07'], 0);
    });

    test('une commande du même jour mais plus tard compte quand même', () {
      // `maintenant` est 14 h 30 ; une commande de 20 h reste d'aujourd'hui.
      expect(compte([_commande(DateTime(2026, 8, 8, 20))])['2026-08-08'], 1);
    });

    test('une commande plus ancienne que la fenêtre n’ouvre pas de colonne', () {
      final parJour = compte([_commande(DateTime(2026, 7, 30))]);

      expect(parJour, hasLength(7));
      expect(parJour.containsKey('2026-07-30'), isFalse);
      expect(parJour.values.fold<int>(0, (a, b) => a + b), 0);
    });

    test('le total de la fenêtre n’est pas le nombre de commandes reçues', () {
      // C'est ce que la légende du graphe affichait : « Total: N commandes sur
      // 7 jours », avec N le nombre de commandes *toutes dates confondues*.
      final parJour = compte([
        _commande(DateTime(2026, 8, 7)),
        _commande(DateTime(2025)),
        _commande(DateTime(2024, 6, 15)),
      ]);

      expect(parJour.values.fold<int>(0, (a, b) => a + b), 1);
    });
  });

  group('Le passage d’un mois et d’une année', () {
    test('les clés restent complétées par des zéros', () {
      final parJour =
          commandesParJour(const [], maintenant: DateTime(2026, 1, 3));

      expect(parJour.keys.first, '2025-12-28');
      expect(parJour.keys.last, '2026-01-03');
    });
  });
}
