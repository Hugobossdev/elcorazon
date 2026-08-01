import '../models/money.dart';
import '../network/api_client.dart';
import 'promotion.dart';

/// Codes promotionnels du back-office — `/api/v1/promotions/`
/// (`backend/apps/promotions/backoffice.py`).
///
/// Il n'y a **aucune route publique** de promotion, et c'est délibéré : un
/// client saisit un code, il n'en liste pas. Ce qu'il voit d'une remise lui
/// arrive par le devis de sa commande ou par sa récompense de fidélité.
///
/// Pas de suppression non plus : `isActive` suspend, et les utilisations déjà
/// consommées renvoient au code — l'effacer rendrait illisible la remise portée
/// par une commande passée.
class PromotionRepository {
  PromotionRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Promotion>> list({
    String? kind,
    bool? isActive,
    String? restaurantSlug,
    String? search,
  }) async {
    final promotions = <Promotion>[];
    String? path = '/promotions/';
    Map<String, dynamic>? queryParameters = {
      if (kind != null) 'kind': kind,
      if (isActive != null) 'is_active': isActive.toString(),
      if (restaurantSlug != null) 'restaurant__slug': restaurantSlug,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      promotions.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => Promotion.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return promotions;
  }

  Future<Promotion> getById(String promotionId) async {
    final response = await apiClient.get('/promotions/$promotionId/');
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  }

  /// Crée un code (permission `promotions.write`).
  ///
  /// [restaurantSlug] vide crée un code **national** : le serveur le refuse à
  /// un compte cloisonné sur un établissement, puisqu'il remiserait aussi les
  /// autres.
  ///
  /// Ni `used_count` ni `owner` ne se transmettent — voir [Promotion].
  Future<Promotion> create({
    required String code,
    required String kind,
    required DateTime startsAt,
    required DateTime endsAt,
    String description = '',
    double? percentage,
    Money? amount,
    Money? minOrderAmount,
    Money? maxDiscount,
    int? usageLimit,
    int? usageLimitPerUser,
    String? restaurantSlug,
  }) async {
    final response = await apiClient.post(
      '/promotions/',
      data: {
        'code': code,
        'description': description,
        'kind': kind,
        if (percentage != null) 'percentage': percentage.toString(),
        if (amount != null) 'amount': amount.toJson(),
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount.toJson(),
        if (maxDiscount != null) 'max_discount': maxDiscount.toJson(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        if (usageLimit != null) 'usage_limit': usageLimit,
        if (usageLimitPerUser != null) 'usage_limit_per_user': usageLimitPerUser,
        'restaurant': restaurantSlug,
      },
    );
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Promotion> update({
    required String promotionId,
    String? description,
    double? percentage,
    Money? amount,
    Money? minOrderAmount,
    Money? maxDiscount,
    DateTime? startsAt,
    DateTime? endsAt,
    int? usageLimit,
    int? usageLimitPerUser,
    bool? isActive,
  }) async {
    final response = await apiClient.patch(
      '/promotions/$promotionId/',
      data: {
        if (description != null) 'description': description,
        if (percentage != null) 'percentage': percentage.toString(),
        if (amount != null) 'amount': amount.toJson(),
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount.toJson(),
        if (maxDiscount != null) 'max_discount': maxDiscount.toJson(),
        if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (usageLimit != null) 'usage_limit': usageLimit,
        if (usageLimitPerUser != null) 'usage_limit_per_user': usageLimitPerUser,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return Promotion.fromJson(response.data as Map<String, dynamic>);
  }

  /// Suspend ou réactive un code — la seule façon de le retirer de la
  /// circulation.
  Future<Promotion> setActive({
    required String promotionId,
    required bool isActive,
  }) {
    return update(promotionId: promotionId, isActive: isActive);
  }
}
