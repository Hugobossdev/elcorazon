import 'package:elcorazon_core/src/models/money.dart';

/// Décomposition d'un total avant de s'engager — miroir de
/// `OrderQuoteSerializer` (`POST /orders/preview/`).
///
/// **C'est le seul chiffrage d'une commande.** Le devis emprunte le même
/// chemin de calcul que la création : mêmes prix relus du catalogue, même
/// barème de zone, même évaluation du code promotionnel. Un second calcul côté
/// application donnerait deux totaux dont l'un serait faux — c'est exactement
/// ce qui se produisait avec les frais de livraison calculés sur le téléphone,
/// depuis une position de restaurant en dur et un tarif au kilomètre que le
/// serveur ignorait.
///
/// Rien n'est réservé par un devis : le quota d'un code ne se décompte qu'à la
/// commande.
class OrderQuote {
  const OrderQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.isOrderable,
    this.promotionCode = '',
    this.promotionDescription = '',
  });

  factory OrderQuote.fromJson(Map<String, dynamic> json) {
    final promotion = json['promotion'] as Map<String, dynamic>?;
    return OrderQuote(
      subtotal: Money.fromJson(json['subtotal'] as Map<String, dynamic>),
      deliveryFee: Money.fromJson(json['delivery_fee'] as Map<String, dynamic>),
      discount: Money.fromJson(json['discount'] as Map<String, dynamic>),
      total: Money.fromJson(json['total'] as Map<String, dynamic>),
      isOrderable: json['is_orderable'] as bool? ?? false,
      promotionCode: promotion?['code'] as String? ?? '',
      promotionDescription: promotion?['description'] as String? ?? '',
    );
  }

  final Money subtotal;

  /// Ce que le client paie pour la course. Vaut zéro quand le franco de la
  /// zone s'applique ; ce que la course vaut réellement (`delivery_fee_gross`)
  /// ne regarde pas le client et n'est pas rendu ici.
  final Money deliveryFee;
  final Money discount;
  final Money total;

  /// Faux quand le panier contient un article devenu indisponible ou dont le
  /// prix a changé. L'écran de commande le dit avant le bouton, pas après.
  final bool isOrderable;

  /// Code effectivement retenu — vide quand aucun n'a été fourni **ou** quand
  /// celui fourni a été refusé. Le distinguer d'une remise nulle importe : un
  /// code périmé doit se voir, pas se taire.
  final String promotionCode;
  final String promotionDescription;

  bool get hasPromotion => promotionCode.isNotEmpty;

  /// Livraison offerte par le barème de la zone (franco), une fois les frais
  /// tombés à zéro.
  bool get isDeliveryFree => deliveryFee.amountMinor == 0;
}
