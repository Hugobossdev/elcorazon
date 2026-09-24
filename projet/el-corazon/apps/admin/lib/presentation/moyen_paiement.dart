import 'package:flutter/material.dart';

/// Vocabulaire d'affichage des moyens de paiement, côté back-office.
///
/// Même raison d'être que [StatutCommande] : le socle garde la chaîne brute du
/// serveur, l'application pose le libellé par-dessus.
///
/// Il vient de `models/order.dart`, qui déclarait **cinq** moyens là où le
/// serveur n'en connaît que quatre. `debitCard` n'avait aucune contrepartie —
/// `DjangoOrderMapper` ne pouvait pas le produire.
///
/// Les libellés sont ceux du serveur (`apps.orders.models.PaymentMethod`). Ils
/// étaient en anglais — « Credit Card », « Cash on Delivery » — et le
/// portefeuille portait le nom d'une autre marque, « FastFoodGo Wallet », hérité
/// d'un gabarit : ce que l'opérateur lisait ici ne correspondait ni au produit
/// ni à ce que le client voit.
enum MoyenPaiement {
  mobileMoney('mobile_money', 'Mobile Money', Icons.smartphone_rounded),
  especes('cash', 'Espèces à la livraison', Icons.payments_rounded),
  portefeuille('wallet', 'Portefeuille', Icons.account_balance_wallet_rounded),
  carte('card', 'Carte bancaire', Icons.credit_card_rounded);

  const MoyenPaiement(this.versServeur, this.libelle, this.icone);

  /// La valeur que le serveur attend et rend.
  final String versServeur;

  final String libelle;

  /// L'icône du moyen de paiement.
  ///
  /// Une icône, pas une illustration du pack : un moyen de règlement est une
  /// donnée de dossier que l'opérateur lit dans un tableau, pas une image.
  /// Les mêmes que les deux autres applications, pour que le siège et le
  /// client ne nomment pas différemment la même chose.
  final IconData icone;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue retombe sur [mobileMoney] : c'est ce que faisait déjà
  /// `DjangoOrderMapper`, et c'est le moyen le plus courant à Lomé.
  static MoyenPaiement depuisServeur(String valeur) {
    for (final moyen in values) {
      if (moyen.versServeur == valeur) return moyen;
    }
    return mobileMoney;
  }

  // `estPrepaye` a été retiré d'ici. Il valait `this != especes` — « tout ce
  // qui n'est pas des espèces est déjà passé par le prestataire » —, ce qui
  // suppose que toute demande de paiement aboutit. Le back-office s'en servait
  // pour dire à l'opérateur ce qu'une annulation implique, et lui annonçait
  // donc un remboursement à faire sur une commande dont le règlement avait
  // échoué.
  //
  // L'état du règlement se lit sur `Order.amountPaid`, écrit par le serveur.
  // Le moyen de paiement reste une intention, et un libellé.
}
