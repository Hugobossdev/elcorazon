import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage des commandes, côté client.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le socle garde le statut et le moyen de paiement en **chaînes brutes** :
/// elles voyagent telles quelles dans le JSON, et un enum imposerait une
/// correspondance à tenir des deux côtés. Ce fichier pose par-dessus ce que
/// l'écran en montre.
///
/// Il vient de `models/order.dart`, retiré au lot 3.

/// Statut d'une commande, tel que le client le lit.
///
/// `models/order.dart` en déclarait **dix**. `refunded` et `failed` n'existent
/// pas côté serveur : le remboursement est un mouvement de paiement, et ce qui
/// n'aboutit pas est annulé, avec un motif. L'adaptateur ne pouvait pas les
/// produire.
enum StatutCommande {
  enAttente('pending', 'En attente', '⏳'),
  confirmee('confirmed', 'Confirmée', '✅'),
  enPreparation('preparing', 'En préparation', '👨‍🍳'),
  prete('ready', 'Prête', '📦'),
  recuperee('picked_up', 'Récupérée', '🏃'),
  enRoute('on_the_way', 'En route', '🛵'),
  livree('delivered', 'Livrée', '🎉'),
  annulee('cancelled', 'Annulée', '❌');

  const StatutCommande(this.versServeur, this.libelle, this.pastille);

  final String versServeur;
  final String libelle;
  final String pastille;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue retombe sur [enAttente] : c'est ce que faisait déjà
  /// l'adaptateur, et le seul repli qui ne fasse pas disparaître une commande
  /// de l'historique du client.
  static StatutCommande depuisServeur(String valeur) {
    for (final statut in values) {
      if (statut.versServeur == valeur) return statut;
    }
    return enAttente;
  }

  /// La commande est-elle encore en cours ?
  bool get estEnCours => this != livree && this != annulee;

  /// Le rang dans le cycle de vie, ou `null` pour une annulation.
  ///
  /// Une annulation n'est pas une étape de plus mais une sortie. La classer
  /// après [livree], comme le faisait l'ordre de déclaration de l'ancienne
  /// énumération, fait passer une commande annulée pour une commande partie.
  int? get rang => this == annulee ? null : index;
}

/// Moyen de paiement, tel que le client le lit.
///
/// `models/order.dart` en déclarait **cinq** ; le serveur en connaît quatre.
/// `debitCard` n'avait aucune contrepartie.
///
/// Les libellés sont repris tels quels, en anglais — « Credit Card », « Cash on
/// Delivery », « FastFoodGo Wallet » dans une application française. Les
/// traduire se voit, et cela ne se décide pas dans un refactoring.
enum MoyenPaiement {
  mobileMoney('mobile_money', 'Mobile Money', '📱',
      'Orange Money, MTN Money, Moov Money'),
  especes('cash', 'Cash on Delivery', '💵', 'Paiement à la livraison'),
  portefeuille('wallet', 'FastFoodGo Wallet', '👛', 'Portefeuille FastFoodGo'),
  carte('card', 'Credit Card', '💳', 'Visa, Mastercard, American Express');

  const MoyenPaiement(
    this.versServeur,
    this.libelle,
    this.pastille,
    this.description,
  );

  final String versServeur;
  final String libelle;
  final String pastille;
  final String description;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue retombe sur [mobileMoney] : c'est ce que faisait déjà
  /// l'adaptateur, et le moyen le plus courant à Lomé.
  static MoyenPaiement depuisServeur(String valeur) {
    for (final moyen in values) {
      if (moyen.versServeur == valeur) return moyen;
    }
    return mobileMoney;
  }

  /// Le règlement passe-t-il par le prestataire avant la livraison ?
  bool get estEnLigne => this != especes;
}

extension CommandeAffichee on eccore.Order {
  StatutCommande get statut => StatutCommande.depuisServeur(status);
  MoyenPaiement get moyenPaiement => MoyenPaiement.depuisServeur(paymentMethod);

  /// L'adresse en une ligne, repère compris.
  ///
  /// À Lomé, « face à la pharmacie » situe mieux qu'un numéro de rue.
  String get adresseComplete => deliveryLandmark.isEmpty
      ? deliveryAddressLine
      : '$deliveryAddressLine ($deliveryLandmark)';

  /// Les consignes du client, ou `null` s'il n'en a pas laissé.
  String? get consignes =>
      deliveryInstructions.isEmpty ? null : deliveryInstructions;

  double get sousTotalAffiche => subtotal.toMajorUnits();
  double get fraisLivraisonAffiches => deliveryFee.toMajorUnits();
  double get remiseAffichee => discount.toMajorUnits();
  double get totalAffiche => total.toMajorUnits();

  /// Le nombre d'articles, en comptant les quantités.
  int get nombreArticles =>
      lines.fold(0, (somme, ligne) => somme + ligne.quantity);
}

extension LigneAffichee on eccore.OrderLine {
  double get prixUnitaireAffiche => unitPrice.toMajorUnits();
  double get totalAffiche => lineTotal.toMajorUnits();

  /// L'image de l'article, ou une chaîne vide — les écrans testent `isNotEmpty`
  /// plutôt que `null`.
  String get image => itemImage ?? '';
}
