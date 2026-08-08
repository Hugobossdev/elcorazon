import 'package:admin/models/order.dart';

/// La fenêtre de temps sur laquelle porte la liste des commandes.
enum FenetreCommandes {
  aujourdHui('today', 'Aujourd’hui'),
  cetteSemaine('week', 'Cette semaine'),
  ceMois('month', 'Ce mois'),
  toutes('all', 'Toutes');

  const FenetreCommandes(this.cle, this.libelle);

  /// La valeur portée par la liste déroulante de l'écran.
  final String cle;
  final String libelle;
}

/// La zone de livraison telle que **cet écran** la devine.
///
/// Voir [zoneDeLAdresse] : ce n'est pas la zone que le serveur connaît.
enum ZoneCommandes {
  toutes('all', 'Toutes les zones'),
  centre('zone1', 'Zone 1 - Centre'),
  nord('zone2', 'Zone 2 - Nord'),
  sud('zone3', 'Zone 3 - Sud');

  const ZoneCommandes(this.cle, this.libelle);

  final String cle;
  final String libelle;
}

/// Les mots par lesquels une adresse est rangée dans une zone.
///
/// **Ces quartiers sont ceux de Dakar** — Yoff, Pikine, Guédiawaye, Almadies,
/// Mermoz, Rufisque, Parcelles Assainies, Médina, Thiaroye, Bargny,
/// Diamniadio, Grand-Yoff, Cambérène, Nord-Foire. Le restaurant est à Lomé.
///
/// Conséquence, épinglée par les tests : aucune adresse de Lomé ne contient
/// ces mots, donc « Zone 2 - Nord » et « Zone 3 - Sud » ne rendent jamais
/// rien, et « Zone 1 - Centre » rend tout — soit par un mot générique
/// (« avenue », « boulevard », « ville », « place »), soit par le repli.
/// Deux des trois choix du filtre sont morts et le troisième ne filtre pas.
///
/// Cette liste est **conservée telle quelle** : le back-office possède déjà un
/// `DeliveryZoneService` qui tient les vraies zones du serveur, et rebrancher
/// le filtre dessus est une décision de produit, pas de refactoring.
const _motsParZone = <ZoneCommandes, List<String>>{
  ZoneCommandes.centre: [
    'centre', 'center', 'downtown', 'centre-ville', 'ville',
    'plateau', 'indépendance', 'place', 'avenue', 'boulevard',
  ],
  ZoneCommandes.nord: [
    'nord', 'north', 'nord-foire', 'foire', 'parcelles', 'assainies',
    'yoff', 'cambérène', 'mermoz', 'sacré-coeur', 'almadies',
  ],
  ZoneCommandes.sud: [
    'sud', 'south', 'medina', 'grand-yoff', 'pikine', 'guediawaye',
    'thiaroye', 'rufisque', 'bargny', 'diamniadio',
  ],
};

/// La zone déduite d'une adresse, ou [ZoneCommandes.centre] à défaut.
///
/// Le repli sur « centre » est délibéré côté écran : il vaut mieux montrer une
/// commande dans la mauvaise zone que la faire disparaître de toutes.
ZoneCommandes zoneDeLAdresse(String adresse) {
  final minuscules = adresse.toLowerCase();

  for (final zone in [
    ZoneCommandes.centre,
    ZoneCommandes.nord,
    ZoneCommandes.sud,
  ]) {
    for (final mot in _motsParZone[zone]!) {
      if (minuscules.contains(mot)) return zone;
    }
  }

  return ZoneCommandes.centre;
}

/// Les commandes retenues par les trois filtres de l'écran, les plus récentes
/// d'abord.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ces règles étaient trois méthodes privées de
/// `order_management_screen.dart`, et deux d'entre elles lisaient l'horloge :
/// rien ne pouvait les interroger. [maintenant] est là pour cela.
///
/// La liste d'entrée n'est jamais modifiée : elle appartient au service.
List<Order> commandesFiltrees(
  List<Order> commandes, {
  String recherche = '',
  ZoneCommandes zone = ZoneCommandes.toutes,
  FenetreCommandes fenetre = FenetreCommandes.aujourdHui,
  DateTime? maintenant,
}) {
  final terme = recherche.toLowerCase();
  final reference = maintenant ?? DateTime.now();

  final retenues = commandes.where((commande) {
    if (terme.isNotEmpty && !_correspond(commande, terme)) return false;

    if (zone != ZoneCommandes.toutes &&
        zoneDeLAdresse(commande.deliveryAddress) != zone) {
      return false;
    }

    return _dansLaFenetre(commande.orderTime, fenetre, reference);
  }).toList();

  retenues.sort((a, b) => b.orderTime.compareTo(a.orderTime));

  return retenues;
}

/// La recherche porte sur la référence, l'adresse et le nom du destinataire.
bool _correspond(Order commande, String terme) {
  if (commande.id.toLowerCase().contains(terme)) return true;
  if (commande.deliveryAddress.toLowerCase().contains(terme)) return true;

  return commande.recipientName.isNotEmpty &&
      commande.recipientName.toLowerCase().contains(terme);
}

bool _dansLaFenetre(
  DateTime passeeLe,
  FenetreCommandes fenetre,
  DateTime maintenant,
) {
  switch (fenetre) {
    case FenetreCommandes.aujourdHui:
      return passeeLe.year == maintenant.year &&
          passeeLe.month == maintenant.month &&
          passeeLe.day == maintenant.day;
    case FenetreCommandes.cetteSemaine:
      return maintenant.difference(passeeLe).inDays <= 7;
    case FenetreCommandes.ceMois:
      return maintenant.difference(passeeLe).inDays <= 30;
    case FenetreCommandes.toutes:
      return true;
  }
}
