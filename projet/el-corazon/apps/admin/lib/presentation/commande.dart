import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/moyen_paiement.dart';
import 'package:admin/presentation/statut_commande.dart';

/// Ce que le back-office lit d'une commande du socle.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Il remplace `DjangoOrderMapper`, qui recopiait `eccore.Order` dans un modèle
/// local. Une traduction a besoin d'exister quand les deux formes divergent ;
/// ici elles ne divergeaient pas — la copie ne faisait que perdre des champs en
/// route (`reference`, `deliveredAt`, `cancelledAt`, `allowedTransitions`, les
/// options choisies, l'historique des transitions).
///
/// Ce qui restait vraiment utile de la traduction, ce sont ces quelques valeurs
/// dérivées : elles sont ici, calculées à la lecture plutôt que figées dans une
/// copie.
extension CommandeAffichee on eccore.Order {
  /// Le statut, dans le vocabulaire du back-office.
  StatutCommande get statut => StatutCommande.depuisServeur(status);

  /// Le moyen de paiement, dans le vocabulaire du back-office.
  MoyenPaiement get moyenPaiement => MoyenPaiement.depuisServeur(paymentMethod);

  /// L'adresse telle qu'on la lit à voix haute au téléphone.
  ///
  /// Le repère n'est pas une ligne de plus mais une précision entre
  /// parenthèses — « Rue du Commerce (face à la pharmacie) ».
  String get adresseComplete => deliveryLandmark.isEmpty
      ? deliveryAddressLine
      : '$deliveryAddressLine ($deliveryLandmark)';

  /// Les consignes du client, ou `null` s'il n'en a pas laissé.
  ///
  /// Le `null` compte : une chaîne vide affichée sous un intitulé « Note »
  /// laisse croire qu'une note existe et qu'elle est vide.
  String? get consignes => deliveryInstructions.isEmpty ? null : deliveryInstructions;

  /// Les montants en unité majeure, pour l'affichage **seulement**.
  ///
  /// Jamais pour recalculer un total : le serveur est seul à l'établir
  /// (ADR-007).
  double get sousTotalAffiche => subtotal.toMajorUnits();
  double get fraisLivraisonAffiches => deliveryFee.toMajorUnits();
  double get remiseAffichee => discount.toMajorUnits();
  double get totalAffiche => total.toMajorUnits();

  /// Le moment que l'opérateur appelle « la commande » — celui où elle a été
  /// passée, pas celui où la ligne a été écrite en base.
  DateTime get passeeLe => placedAt;
}

/// Les libellés des groupes d'options, du serveur vers l'écran.
///
/// Le serveur rend le nom du groupe tel qu'il est saisi au catalogue ; cette
/// table ne sert qu'aux identifiants techniques hérités, que l'ancien modèle
/// local traduisait déjà. Un groupe absent de la table s'affiche tel quel —
/// c'est le cas courant, et c'est voulu.
const _libellesDeGroupe = <String, String>{
  'size': 'Taille',
  'ingredient': 'Ingrédient',
  'ingredients': 'Ingrédients',
  'sauce': 'Sauce',
  'sauces': 'Sauces',
  'extra': 'Supplément',
  'extras': 'Suppléments',
  'cooking': 'Cuisson',
  'shape': 'Forme',
  'flavor': 'Saveur',
  'filling': 'Garniture',
  'decoration': 'Décoration',
  'tiers': 'Étages',
  'icing': 'Glaçage',
  'dietary': 'Régime',
};

extension LigneAffichee on eccore.OrderLine {
  /// Les montants en unité majeure, pour l'affichage seulement.
  double get prixUnitaireAffiche => unitPrice.toMajorUnits();
  double get prixTotalAffiche => lineTotal.toMajorUnits();

  /// Ce que le client a demandé, une ligne par choix : « Cuisson: À point ».
  ///
  /// C'est ce que la cuisine doit lire. Le bloc existait déjà à l'écran mais
  /// ne s'affichait jamais : le modèle local attendait des personnalisations
  /// que rien ne remplissait, faute pour le socle de lire `options`.
  List<String> get personnalisations => [
        for (final choix in options)
          if (choix.optionName.isNotEmpty)
            '${_libellesDeGroupe[choix.groupName.toLowerCase()] ?? choix.groupName}'
                ': ${choix.optionName}',
      ];

  /// La note libre laissée sur cet article, ou `null`.
  String? get note => notes.isEmpty ? null : notes;
}
