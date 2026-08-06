import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce que le **serveur** dit de la livraison à une adresse donnée.
///
/// Rien ici n'est calculé sur le téléphone. La version précédente l'était
/// entièrement : distance à vol d'oiseau depuis une position de restaurant en
/// dur, forfait de 500 F, 200 F par kilomètre, franco à 10 000 F, plafond à
/// 5 000 F. Aucune de ces valeurs n'existait côté serveur, qui facture depuis
/// le barème de la zone qui couvre le point d'arrivée (`DeliveryZone`) —
/// l'écran annonçait donc un prix, la commande en retenait un autre.
///
/// Deux sources, deux questions :
///
/// * `GET /geography/zones/resolve/` — ce point est-il desservi, et à quel
///   barème ? C'est ce qu'interroge la carte, avant qu'un panier existe ;
/// * `POST /orders/preview/` — combien coûte **cette** commande ? C'est le
///   même chemin de calcul que la création, franco et minimum compris.
///
/// La décomposition « base + distance » a disparu avec le calcul local : le
/// serveur rend un montant de course, pas ses termes, et les réinventer pour
/// remplir un tableau reviendrait à afficher deux lignes fausses dont la somme
/// serait juste.
class DeliveryFeeBreakdown {
  const DeliveryFeeBreakdown({
    required this.totalFee,
    this.isInServiceableZone = true,
    this.isFreeDelivery = false,
    this.freeDeliveryReason,
    this.zoneName,
    this.estimatedDeliveryTime,
    this.minOrderAmount,
    this.freeDeliveryThreshold,
  });

  /// Devis d'une commande — la réponse qui fait foi, celle qui sera facturée.
  factory DeliveryFeeBreakdown.fromQuote(
    eccore.OrderQuote quote, {
    eccore.DeliveryZone? zone,
  }) {
    return DeliveryFeeBreakdown(
      totalFee: quote.deliveryFee.toMajorUnits(),
      isFreeDelivery: quote.isDeliveryFree,
      freeDeliveryReason: quote.isDeliveryFree ? 'Livraison offerte sur cette commande' : null,
      zoneName: zone?.name,
      estimatedDeliveryTime: zone?.estimatedDeliveryMinutes,
      minOrderAmount: zone?.minOrderAmount?.toMajorUnits(),
      freeDeliveryThreshold: zone?.freeDeliveryThreshold?.toMajorUnits(),
    );
  }

  /// Barème d'une zone, sans commande — ce qu'affiche la carte pendant qu'on
  /// déplace le repère. Le montant montré est le **forfait de base** de la
  /// zone : le prix définitif dépend de la distance et du panier, que seul le
  /// devis connaît.
  factory DeliveryFeeBreakdown.fromZone(eccore.DeliveryZone zone) {
    return DeliveryFeeBreakdown(
      totalFee: zone.baseFee.toMajorUnits(),
      zoneName: zone.name,
      estimatedDeliveryTime: zone.estimatedDeliveryMinutes,
      minOrderAmount: zone.minOrderAmount?.toMajorUnits(),
      freeDeliveryThreshold: zone.freeDeliveryThreshold?.toMajorUnits(),
    );
  }

  /// Le point n'est couvert par aucune zone. Ce n'est pas une erreur : c'est
  /// la réponse du serveur à « livrez-vous ici ? ».
  factory DeliveryFeeBreakdown.notServiceable() =>
      const DeliveryFeeBreakdown(totalFee: 0, isInServiceableZone: false);

  /// Frais facturés au client, en unité majeure (F CFA à Lomé).
  final double totalFee;
  final bool isInServiceableZone;
  final bool isFreeDelivery;
  final String? freeDeliveryReason;
  final String? zoneName;

  /// Délai annoncé par la zone. C'est une propriété du secteur, pas une
  /// division de la distance par une vitesse moyenne inventée ici.
  final int? estimatedDeliveryTime;

  /// Montant minimum de commande dans cette zone, quand elle en pose un. Le
  /// dire avant permet au client de voir venir le refus plutôt que de le
  /// découvrir au moment de commander.
  final double? minOrderAmount;

  /// Seuil au-delà duquel la zone offre la livraison.
  final double? freeDeliveryThreshold;

  @override
  String toString() {
    if (!isInServiceableZone) return 'DeliveryFeeBreakdown(hors zone)';
    if (isFreeDelivery) return 'DeliveryFeeBreakdown(offerte — $freeDeliveryReason)';
    return 'DeliveryFeeBreakdown(${totalFee.toStringAsFixed(0)}, zone ${zoneName ?? "?"})';
  }
}
