import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/commande.dart';

/// Mise en CSV d'une liste de commandes.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Deux écrans de supervision exportent les commandes, et un seul savait le
/// faire. `order_management_screen` construisait un vrai CSV et le posait dans
/// le presse-papier ; `advanced_order_management_screen` — celui qu'ouvre la
/// navigation, donc celui que l'exploitation utilise — affichait « Export des
/// commandes en cours… » puis ne faisait rien. Le bandeau annonçait un travail
/// qui n'était pas engagé.
///
/// La mise en forme est ici pour qu'il n'y en ait qu'une : deux exports du même
/// objet qui ne rendent pas les mêmes colonnes obligent à demander, devant un
/// tableur, « lequel des deux tu as pris ? ».
///
/// La sortie est **le texte**, pas un fichier : c'est à l'écran de décider ce
/// qu'il en fait — presse-papier sur les six plateformes, sans paquet
/// supplémentaire ni permission d'écriture.
String commandesEnCsv(List<eccore.Order> commandes) {
  final tampon = StringBuffer()
    ..writeln(
      [
        'Référence',
        'Établissement',
        'Date',
        'Destinataire',
        'Téléphone',
        'Adresse',
        'Statut',
        'Paiement',
        'Total',
        'Devise',
        'Articles',
        'Livrée le',
      ].map(champCsv).join(','),
    );

  for (final commande in commandes) {
    tampon.writeln(
      [
        // La référence plutôt que l'UUID : c'est elle que le client donne au
        // téléphone, et celle qui figure sur le ticket.
        commande.reference,
        commande.restaurantName,
        commande.passeeLe.toIso8601String(),
        commande.recipientName.isEmpty ? 'Inconnu' : commande.recipientName,
        commande.recipientPhone,
        commande.adresseComplete,
        commande.statut.libelle,
        commande.moyenPaiement.libelle,
        // Le montant et sa devise en deux colonnes : un export du siège mêle
        // Lomé (XOF) et Douala (XAF), et un total sans devise s'additionnerait
        // dans le tableur comme une seule monnaie.
        montantCsv(commande.total),
        commande.total.currency,
        // `items_count` et non `lines.length` : la forme de liste ne porte pas
        // les lignes, et la colonne valait zéro sur toutes les commandes.
        commande.itemsCount,
        commande.deliveredAt?.toIso8601String() ?? '',
      ].map(champCsv).join(','),
    );
  }

  return tampon.toString();
}

/// Échappe un champ CSV.
///
/// Guillemets et virgules d'origine sont **conservés**, et c'est le champ qui
/// est entouré. Les retirer changerait la donnée exportée — une adresse
/// « Rue "des" Cocotiers, lot 4 » n'est plus celle du client — et surtout cela
/// ne traiterait pas le vrai casseur de fichier : un **retour à la ligne** dans
/// une adresse, qui coupe la commande en deux lignes et décale tout le reste du
/// tableau.
String champCsv(Object? valeur) {
  final texte = valeur?.toString() ?? '';
  if (!texte.contains(RegExp('[",\n\r]'))) return texte;
  return '"${texte.replaceAll('"', '""')}"';
}

/// Un montant **nombre**, en unité majeure, avec un point décimal quand la
/// devise en a — ce qu'un tableur lit comme un nombre.
///
/// La version précédente passait par le formateur d'affichage et retirait les
/// espaces : elle écrivait « 12500CFA », qu'aucun tableur ne lit comme un
/// nombre. La devise a désormais sa propre colonne.
String montantCsv(eccore.Money montant) {
  final majeur = montant.toMajorUnits();
  return majeur == majeur.roundToDouble() ? majeur.toStringAsFixed(0) : majeur.toStringAsFixed(2);
}
