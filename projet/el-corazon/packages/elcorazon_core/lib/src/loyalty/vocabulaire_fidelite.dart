/// Nature d'une récompense — `apps.loyalty.models.RewardKind`.
///
/// Deux natures, et pas davantage : l'écran en proposait autrefois une
/// troisième (« des points contre des points »), qui ne faisait que déplacer un
/// solde, et un « article offert » sans champ pour désigner l'article.
///
/// Comparé aux `TextChoices` du serveur par `tools/contrat_vocabulaire.py`.
abstract final class RewardKind {
  /// Remise d'un **montant** — jamais un pourcentage — sur une commande.
  static const discount = 'discount';
  static const freeDelivery = 'free_delivery';

  static const values = [discount, freeDelivery];

  static String libelle(String valeur) => switch (valeur) {
        discount => 'Remise sur une commande',
        freeDelivery => 'Livraison offerte',
        _ => valeur,
      };
}
