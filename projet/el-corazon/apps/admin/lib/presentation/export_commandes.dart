import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/commande.dart';
import 'package:admin/utils/price_formatter.dart';

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
        'Date',
        'Destinataire',
        'Téléphone',
        'Adresse',
        'Statut',
        'Paiement',
        'Total',
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
        commande.passeeLe.toIso8601String(),
        commande.recipientName.isEmpty ? 'Inconnu' : commande.recipientName,
        commande.recipientPhone,
        commande.adresseComplete,
        commande.statut.libelle,
        commande.moyenPaiement.libelle,
        montantCsv(commande.totalAffiche),
        commande.lines.length,
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

/// Un montant sans son séparateur de milliers, pour qu'un tableur y voie un
/// nombre.
///
/// `\s` et non l'espace ordinaire : le socle sépare les milliers par une espace
/// insécable étroite (U+202F), qu'un `replaceAll(' ')` laisserait filer jusque
/// dans la cellule.
String montantCsv(double montant) =>
    PriceFormatter.format(montant).replaceAll(RegExp(r'\s'), '');
