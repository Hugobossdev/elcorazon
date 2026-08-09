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
  mobileMoney('mobile_money', 'Mobile Money', '📱'),
  especes('cash', 'Cash on Delivery', '💵'),
  portefeuille('wallet', 'FastFoodGo Wallet', '👛'),
  carte('card', 'Credit Card', '💳');

  const MoyenPaiement(this.versServeur, this.libelle, this.pastille);

  /// La valeur que le serveur attend et rend.
  final String versServeur;

  final String libelle;
  final String pastille;

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
