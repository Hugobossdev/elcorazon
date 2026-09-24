import 'package:admin/presentation/tableau_commandes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// La vue Kanban des commandes — une colonne par étape du service.
void main() {
  final maintenant = DateTime(2026, 9, 21, 13);

  test('chaque étape du service a sa colonne, récupérée et en route partagent la leur', () {
    final colonnes = repartirSurLeTableau(
      [
        commandeDeTest(id: 'a', statut: 'pending'),
        commandeDeTest(id: 'b', statut: 'confirmed'),
        // `preparing` est le statut par défaut de `commandeDeTest`.
        commandeDeTest(id: 'c'),
        commandeDeTest(id: 'd', statut: 'ready'),
        commandeDeTest(id: 'e', statut: 'picked_up'),
        commandeDeTest(id: 'f', statut: 'on_the_way'),
      ],
      maintenant: maintenant,
    );

    List<String> ids(ColonneTableau colonne) => colonnes[colonne]!.map((c) => c.id).toList();
    expect(ids(ColonneTableau.enAttente), ['a']);
    expect(ids(ColonneTableau.confirmees), ['b']);
    expect(ids(ColonneTableau.enPreparation), ['c']);
    expect(ids(ColonneTableau.pretes), ['d']);
    expect(ids(ColonneTableau.enLivraison), unorderedEquals(['e', 'f']));
  });

  test('les annulées ne sont sur aucune colonne', () {
    final colonnes = repartirSurLeTableau(
      [commandeDeTest(id: 'x', statut: 'cancelled')],
      maintenant: maintenant,
    );

    expect(colonnes.values.expand((c) => c), isEmpty);
  });

  test('les livrées ne sont que celles du jour', () {
    // La fenêtre de supervision couvre un an : sans cette borne, la dernière
    // colonne contiendrait un an de livraisons.
    final colonnes = repartirSurLeTableau(
      [
        commandeDeTest(id: 'hier', statut: 'delivered', livreeLe: DateTime(2026, 9, 20, 22)),
        commandeDeTest(id: 'midi', statut: 'delivered', livreeLe: DateTime(2026, 9, 21, 12)),
        commandeDeTest(id: 'matin', statut: 'delivered', livreeLe: DateTime(2026, 9, 21, 9)),
      ],
      maintenant: maintenant,
    );

    // Les plus récentes d'abord : c'est ce qu'on cherche du regard.
    expect(colonnes[ColonneTableau.livreesDuJour]!.map((c) => c.id), ['midi', 'matin']);
  });

  test('une étape en cours se lit de la plus ancienne à la plus récente', () {
    // L'ordre dans lequel on les traite : une commande qui attend depuis
    // quarante minutes ne doit pas se trouver sous celles qui arrivent.
    final colonnes = repartirSurLeTableau(
      [
        commandeDeTest(id: 'recente', statut: 'pending', passeeLe: DateTime(2026, 9, 21, 12, 50)),
        commandeDeTest(id: 'ancienne', statut: 'pending', passeeLe: DateTime(2026, 9, 21, 12, 10)),
      ],
      maintenant: maintenant,
    );

    expect(colonnes[ColonneTableau.enAttente]!.map((c) => c.id), ['ancienne', 'recente']);
  });

  test('toutes les colonnes existent, même vides', () {
    // Une colonne absente se lirait comme une étape qui n'existe pas.
    final colonnes = repartirSurLeTableau(const [], maintenant: maintenant);

    expect(colonnes.keys, ColonneTableau.values);
    expect(colonnes.values.every((c) => c.isEmpty), isTrue);
  });
}
