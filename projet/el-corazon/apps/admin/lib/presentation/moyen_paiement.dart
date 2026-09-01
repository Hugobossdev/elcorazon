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
/// Les libellés sont repris tels quels, en anglais : « Credit Card », « Cash on
/// Delivery », « FastFoodGo Wallet » dans un back-office français. Les traduire
/// changerait ce que lit l'opérateur, et cela ne se décide pas ici.
enum MoyenPaiement {
  mobileMoney('mobile_money', 'Mobile Money', Icons.smartphone_rounded),
  especes('cash', 'Cash on Delivery', Icons.payments_rounded),
  portefeuille(
    'wallet',
    'FastFoodGo Wallet',
    Icons.account_balance_wallet_rounded,
  ),
  carte('card', 'Credit Card', Icons.credit_card_rounded);

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

  /// Le paiement a-t-il été encaissé avant la livraison ?
  ///
  /// Les espèces sont remises au livreur ; tout le reste est déjà passé par le
  /// prestataire au moment où la commande arrive au back-office.
  bool get estPrepaye => this != especes;
}
