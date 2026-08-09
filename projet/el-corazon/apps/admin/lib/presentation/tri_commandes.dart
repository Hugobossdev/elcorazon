import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';

/// Recherche et tri de la liste des commandes.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ces deux règles vivaient dans `advanced_order_management_screen.dart`, au
/// milieu de 3 067 lignes de widgets. Le critère du lot 4 n'est pas un nombre
/// de lignes mais celui-ci : **le comportement métier de l'écran est-il
/// atteignable par un test sans monter l'arbre de widgets ?** Il ne l'était
/// pas ; il l'est.
///
/// Recherche et tri restent **des réglages d'écran**, pas d'état de service :
/// deux écrans ouverts sur les mêmes commandes n'ont aucune raison de partager
/// le tri de l'un ni la recherche de l'autre.
enum TriCommandes {
  dateCroissante('Date (Ancien)'),
  dateDecroissante('Date (Récent)'),
  totalCroissant('Total (Croissant)'),
  totalDecroissant('Total (Décroissant)'),
  statut('Statut');

  const TriCommandes(this.libelle);

  final String libelle;
}

/// Les commandes retenues par [recherche], dans l'ordre demandé par [tri].
///
/// La recherche porte sur ce qu'un opérateur a sous les yeux quand on l'appelle
/// au téléphone : la référence, le nom du destinataire, l'adresse. Elle ignore
/// la casse et les espaces de bordure — on cherche « awa » après avoir collé
/// « Awa » depuis un message.
///
/// La liste d'entrée n'est jamais modifiée : elle appartient au service, et un
/// tri en place réordonnerait ce que les autres écrans lisent.
List<eccore.Order> commandesAffichees(
  List<eccore.Order> commandes, {
  String recherche = '',
  TriCommandes tri = TriCommandes.dateDecroissante,
}) {
  final terme = recherche.trim().toLowerCase();

  final retenues = terme.isEmpty
      ? List<eccore.Order>.of(commandes)
      : commandes
          .where(
            (commande) =>
                commande.id.toLowerCase().contains(terme) ||
                commande.recipientName.toLowerCase().contains(terme) ||
                commande.adresseComplete.toLowerCase().contains(terme),
          )
          .toList();

  switch (tri) {
    case TriCommandes.dateCroissante:
      retenues.sort((a, b) => a.passeeLe.compareTo(b.passeeLe));
    case TriCommandes.dateDecroissante:
      retenues.sort((a, b) => b.passeeLe.compareTo(a.passeeLe));
    case TriCommandes.totalCroissant:
      retenues.sort((a, b) => a.totalAffiche.compareTo(b.totalAffiche));
    case TriCommandes.totalDecroissant:
      retenues.sort((a, b) => b.totalAffiche.compareTo(a.totalAffiche));
    case TriCommandes.statut:
      retenues.sort((a, b) => a.statut.index.compareTo(b.statut.index));
  }

  return retenues;
}
