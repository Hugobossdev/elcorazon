import 'package:admin/presentation/anciennete_commande.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Le compteur d'articles d'une carte de commande.
///
/// **Le défaut le plus visible du back-office venait d'ici.** La carte
/// affichait « 0 article » puis un bandeau « Aucun article trouvé dans cette
/// commande », sur des commandes qui en contenaient trois. Elle lisait
/// `order.lines.length` — or `OrderSerializer`, la forme que rend
/// `GET /orders/manage/`, ne porte pas `lines` : seul le détail les a.
///
/// Ce n'était donc ni un défaut d'écran ni une erreur de parsing, mais une
/// lecture d'un champ absent qui rendait une liste vide au lieu d'échouer. Un
/// test qui monterait le widget avec une commande complète serait passé sans
/// rien voir : c'est la **forme liste** qu'il faut éprouver.
void main() {
  group('Ce que porte la forme liste', () {
    test('les compteurs viennent du serveur, pas de la longueur de lines', () {
      // La charge que rend réellement `GET /orders/manage/` : des compteurs,
      // aucune ligne.
      final commande = eccore.Order.fromJson(
        commandeJson()
          ..remove('lines')
          ..addAll({'lines_count': 3, 'items_count': 6}),
      );

      expect(commande.lines, isEmpty, reason: 'la forme liste ne porte pas les lignes');
      expect(commande.itemsCount, 6);
      expect(commande.linesCount, 3);
    });

    test('les articles sont la somme des quantités, pas le nombre de lignes', () {
      // Deux burgers, une pizza, trois donuts : six articles, trois lignes.
      final commande = eccore.Order.fromJson(
        commandeJson()..addAll({'lines_count': 3, 'items_count': 6}),
      );

      expect(commande.itemsCount, isNot(commande.linesCount));
      expect(commande.itemsCount, 6);
    });

    test('une commande réellement vide rend zéro', () {
      final commande = eccore.Order.fromJson(
        commandeJson()..addAll({'lines_count': 0, 'items_count': 0}),
      );

      expect(commande.itemsCount, 0);
    });

    test('un serveur qui n’envoie pas les compteurs ne fait pas planter', () {
      // Compatibilité : un backend plus ancien ne les porte pas. Zéro est
      // alors la seule valeur honnête — mieux vaut un compteur muet qu'une
      // exception qui vide l'écran.
      final commande = eccore.Order.fromJson(commandeJson());

      expect(commande.itemsCount, 0);
      expect(commande.linesCount, 0);
    });
  });

  group('La forme détail reste cohérente avec la liste', () {
    test('les deux disent le même nombre', () {
      // Le détail porte `lines` **et** les compteurs. S'ils divergeaient, la
      // carte et la fiche afficheraient deux nombres pour la même commande.
      final detail = eccore.Order.fromJson(
        commandeJson(
          lignes: [
            ligneJson(),
            ligneJson(nom: 'Pizza', quantite: 1),
          ],
        )..addAll({'lines_count': 2, 'items_count': 3}),
      );

      expect(detail.linesCount, detail.lines.length);
      expect(
        detail.itemsCount,
        detail.lines.fold<int>(0, (somme, ligne) => somme + ligne.quantity),
      );
    });
  });

  group('L’heure affichée sur la carte', () {
    test('est celle du passage de commande, en heure locale', () {
      // La carte montrait « 18/8 » — une date — là où un service en cours
      // demande une heure.
      final quand = DateTime(2026, 8, 18, 18, 45);

      expect(heureCommande(quand), '18:45');
    });

    test('complète l’ancienneté au lieu de la remplacer', () {
      // « 3h » dit depuis combien de temps la commande attend ; « 18:45 » dit
      // à quel moment du service elle est tombée. Les deux se lisent ensemble.
      final passeeLe = DateTime(2026, 8, 18, 18, 45);
      final maintenant = passeeLe.add(const Duration(hours: 3));

      expect(heureCommande(passeeLe), '18:45');
      expect(ancienneteCommande(passeeLe, maintenant: maintenant), '3h');
    });

    test('les heures et minutes sont sur deux chiffres', () {
      expect(heureCommande(DateTime(2026, 8, 18, 9, 5)), '09:05');
    });
  });
}
