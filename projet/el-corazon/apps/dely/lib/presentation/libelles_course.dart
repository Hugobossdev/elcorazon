import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage des courses — étapes et moyens de paiement.
///
/// Pourquoi ces énumérations restent dans l'application
/// ----------------------------------------------------
///
/// Le socle décrit les mêmes valeurs, mais en **chaînes brutes**
/// (`eccore.DeliveryStatus`), et c'est délibéré : elles voyagent telles quelles
/// dans le JSON, et un enum imposerait une correspondance à tenir à jour des
/// deux côtés — celle-là même qui finit par ne plus correspondre.
///
/// Ce que ce fichier ajoute par-dessus n'est pas du domaine mais de la
/// présentation : un libellé, une pastille. `04-migration-flutter.md` §2.2
/// réserve cette couche aux applications, et le back-office n'écrit d'ailleurs
/// pas les mêmes mots que le livreur pour la même étape.
///
/// Il vient de `models/order.dart`, retiré au lot 3 : ce fichier-là mêlait ces
/// libellés à une copie locale des entités `Order` et `Assignment` du socle.
/// Seuls les libellés méritaient de rester.

/// Étape d'une course, telle que l'écran du livreur la nomme.
///
/// C'est bien l'étape de la **course** qui est décrite, pas le statut de la
/// commande : côté livreur, ce sont ses propres gestes qui pilotent l'écran.
/// La projection inverse — déduire l'écran du statut de commande — avait
/// produit le constat C4 de l'audit.
enum EtapeCourse {
  proposee('Proposée'),
  acceptee('Acceptée'),
  recuperee('Récupérée'),
  enRoute('En route'),
  livree('Livrée'),
  annulee('Annulée');

  const EtapeCourse(this.libelle);

  /// Depuis la valeur rendue par le serveur (`eccore.DeliveryStatus`).
  ///
  /// Une valeur inconnue devient [annulee] plutôt que de faire échouer
  /// l'écran : mieux vaut une course affichée comme close qu'une liste vide.
  factory EtapeCourse.depuisServeur(String statut) {
    return switch (statut) {
      eccore.DeliveryStatus.offered => EtapeCourse.proposee,
      eccore.DeliveryStatus.accepted => EtapeCourse.acceptee,
      eccore.DeliveryStatus.pickedUp => EtapeCourse.recuperee,
      eccore.DeliveryStatus.onTheWay => EtapeCourse.enRoute,
      eccore.DeliveryStatus.delivered => EtapeCourse.livree,
      _ => EtapeCourse.annulee,
    };
  }

  final String libelle;

  /// L'illustration de l'étape, prise dans le pack partagé du socle.
  ///
  /// ## Ce qui a remplacé quoi
  ///
  /// Chaque étape portait un emoji Unicode — `'🛵'` pour la route, `'🎉'` pour
  /// la livraison. Ils venaient de la police du téléphone, pas de nous : sur
  /// les Android d'entrée de gamme que beaucoup de livreurs utilisent, un
  /// glyphe récent s'affiche en carré vide, et l'étape devenait illisible.
  ///
  /// Le pack vit dans `elcorazon_core` : le livreur et le client voient donc
  /// **la même illustration pour la même étape**, ce que deux jeux d'emojis
  /// tenus séparément ne garantissaient pas.
  eccore.AppEmojiToken get illustration => switch (this) {
        EtapeCourse.proposee => eccore.AppEmojis.newOrder,
        EtapeCourse.acceptee => eccore.AppEmojis.orderConfirmed,
        EtapeCourse.recuperee => eccore.AppEmojis.courier,
        EtapeCourse.enRoute => eccore.AppEmojis.delivery,
        EtapeCourse.livree => eccore.AppEmojis.delivered,
        EtapeCourse.annulee => eccore.AppEmojis.error,
      };

  /// La course occupe encore le livreur.
  bool get estEnCours => this != EtapeCourse.livree && this != EtapeCourse.annulee;

  /// Étape à demander au serveur pour atteindre celle-ci.
  ///
  /// L'énumération remplacée décrivait aussi la cuisine — « en préparation »,
  /// « prête » — et rejetait ces valeurs à l'exécution. Elles ne sont plus
  /// représentables : le livreur ne peut nommer que ses propres gestes.
  ///
  /// [proposee] reste une exception : une course se propose, elle ne se
  /// demande pas. Échouer ici plutôt que d'émettre une requête vouée au refus.
  String get versServeur => switch (this) {
    EtapeCourse.acceptee => eccore.DeliveryStatus.accepted,
    EtapeCourse.recuperee => eccore.DeliveryStatus.pickedUp,
    EtapeCourse.enRoute => eccore.DeliveryStatus.onTheWay,
    EtapeCourse.livree => eccore.DeliveryStatus.delivered,
    EtapeCourse.annulee => eccore.DeliveryStatus.cancelled,
    EtapeCourse.proposee => throw ArgumentError(
        'Une course se propose, elle ne se demande pas.',
      ),
  };
}

/// Moyen de paiement d'une commande, tel que l'écran d'encaissement le nomme.
enum MoyenPaiement {
  especes('Espèces', Icons.payments_rounded),
  mobileMoney('Mobile Money', Icons.smartphone_rounded),
  carte('Carte bancaire', Icons.credit_card_rounded),
  portefeuille('Portefeuille El Corazón', Icons.account_balance_wallet_rounded);

  const MoyenPaiement(this.libelle, this.icone);

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Un moyen inconnu retombe sur les espèces, et pas par facilité : le livreur
  /// doit se préparer à encaisser plutôt que l'inverse. Arriver sans monnaie
  /// devant une commande à régler coûte plus cher que l'attendre pour rien.
  factory MoyenPaiement.depuisServeur(String? methode) {
    return switch (methode) {
      'mobile_money' => MoyenPaiement.mobileMoney,
      'card' => MoyenPaiement.carte,
      'wallet' => MoyenPaiement.portefeuille,
      _ => MoyenPaiement.especes,
    };
  }

  final String libelle;

  /// L'icône du moyen de paiement.
  ///
  /// Une icône, et pas une illustration du pack : ce que le livreur lit ici
  /// est un **réglage de la course**, au milieu d'une fiche d'informations —
  /// numéro, statut, montant. Les mêmes icônes que l'écran de règlement du
  /// client, pour que les deux applications ne nomment pas différemment la
  /// même chose.
  final IconData icone;

  /// Le livreur doit encaisser à la remise.
  bool get aEncaisser => this == MoyenPaiement.especes;
}
