import 'package:elcorazon_core/src/models/money.dart';

/// Nature de la remise — valeurs de `DiscountKind` côté serveur.
///
/// Chaînes brutes plutôt qu'un enum Dart : elles voyagent telles quelles dans
/// le JSON, et un enum imposerait une correspondance à tenir à jour des deux
/// côtés — celle-là même qui finit par ne plus correspondre.
abstract final class DiscountKind {
  static const percentage = 'percentage';
  static const fixed = 'fixed';
  static const freeDelivery = 'free_delivery';
}

/// Code promotionnel vu de l'exploitation — miroir de
/// `ManagedPromotionSerializer`.
///
/// Deux champs sont en **lecture seule**, et ce n'est pas un oubli :
///
/// * [usedCount] est tenu par le serveur, sous verrou, à la création de chaque
///   commande. L'écrire depuis un écran rouvrirait un quota épuisé sans que
///   rien n'en garde trace ;
/// * [ownerEmail] désigne le bénéficiaire d'un code **nominatif**, qui naît
///   d'un échange de points de fidélité — donc d'un débit. En frapper un ici
///   distribuerait des récompenses gratuites.
class Promotion {
  const Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.usedCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.percentage,
    this.amount,
    this.minOrderAmount,
    this.maxDiscount,
    this.usageLimit,
    this.usageLimitPerUser,
    this.restaurantSlug,
    this.ownerEmail,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      code: json['code'] as String,
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String,
      percentage: _decimal(json['percentage']),
      amount: _money(json['amount']),
      minOrderAmount: _money(json['min_order_amount']),
      maxDiscount: _money(json['max_discount']),
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      usageLimit: json['usage_limit'] as int?,
      usageLimitPerUser: json['usage_limit_per_user'] as int?,
      usedCount: json['used_count'] as int? ?? 0,
      restaurantSlug: json['restaurant'] as String?,
      ownerEmail: json['owner_email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String code;
  final String description;
  final String kind;

  /// Renseigné pour [DiscountKind.percentage] seulement.
  final double? percentage;

  /// Renseigné pour [DiscountKind.fixed] seulement.
  final Money? amount;
  final Money? minOrderAmount;
  final Money? maxDiscount;
  final DateTime startsAt;
  final DateTime endsAt;
  final int? usageLimit;
  final int? usageLimitPerUser;
  final int usedCount;

  /// Vide = code **national**, valable partout. Le serveur ne laisse un compte
  /// cloisonné ni le voir ni l'écrire : remiser tous les établissements n'est
  /// pas un pouvoir d'établissement.
  final String? restaurantSlug;

  /// Bénéficiaire d'un code nominatif, issu d'un échange de points.
  final String? ownerEmail;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isNational => restaurantSlug == null;
  bool get isPersonal => ownerEmail != null;

  /// Quota épuisé — le serveur refusera le code, l'écran peut le dire avant.
  bool get isExhausted => usageLimit != null && usedCount >= usageLimit!;

  /// Utilisable aujourd'hui, d'après ce que porte l'objet.
  ///
  /// Indicatif : c'est le serveur qui tranche à l'application du code, avec sa
  /// propre horloge. Un écran qui déciderait seul afficherait « valable » sur
  /// un poste dont la date est fausse.
  bool isCurrent(DateTime now) =>
      isActive && !isExhausted && now.isAfter(startsAt) && now.isBefore(endsAt);

  static Money? _money(Object? value) => value == null
      ? null
      : Money.fromJson(value as Map<String, dynamic>);

  /// Les décimaux voyagent en chaîne (ADR-007) pour ne pas passer par un
  /// `double` au moment du transport.
  static double? _decimal(Object? value) =>
      value == null ? null : double.parse(value.toString());
}
