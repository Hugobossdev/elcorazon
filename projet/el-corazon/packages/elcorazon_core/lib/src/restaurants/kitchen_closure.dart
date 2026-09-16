import 'package:elcorazon_core/src/network/api_client.dart';

/// Fermeture exceptionnelle d'une cuisine — miroir de
/// `ManagedKitchenClosureSerializer` (`backend/apps/restaurants/serializers.py`).
///
/// Un jour férié, des travaux, une coupure de gaz. Datée, elle **se lève
/// d'elle-même** : la cuisine rouvre à l'heure dite sans qu'on y pense — ce
/// qu'aucun interrupteur ne fait, et ce que retirer une plage d'horaires
/// (donc tous les mardis) ne faisait pas.
class KitchenClosure {
  const KitchenClosure({
    required this.id,
    required this.restaurantId,
    required this.startsAt,
    required this.endsAt,
    this.restaurantName = '',
    this.reason = '',
    this.isCurrent = false,
  });

  factory KitchenClosure.fromJson(Map<String, dynamic> json) => KitchenClosure(
    id: json['id'] as String,
    restaurantId: json['restaurant'].toString(),
    restaurantName: json['restaurant_name'] as String? ?? '',
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    reason: json['reason'] as String? ?? '',
    isCurrent: json['is_current'] as bool? ?? false,
  );

  final String id;
  final String restaurantId;
  final String restaurantName;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Montré au client : « fermée exceptionnellement (jour férié) ».
  final String reason;

  /// En cours au moment de la lecture, selon l'horloge **du serveur**.
  final bool isCurrent;

  /// Terminée à [maintenant] — elle ne ferme plus rien.
  bool isPastAt(DateTime maintenant) => !endsAt.isAfter(maintenant);
}

/// Fermetures exceptionnelles — `/api/v1/restaurants/manage/closures/`.
///
/// Même permission et même cloisonnement que les horaires, dont c'est
/// l'exception datée : `restaurants.write` pour écrire.
class ManagedKitchenClosureRepository {
  ManagedKitchenClosureRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Fermetures d'une cuisine, **à venir et en cours** par défaut.
  Future<List<KitchenClosure>> list({required String restaurantId, bool upcomingOnly = true}) async {
    final fermetures = <KitchenClosure>[];
    String? path = '/restaurants/manage/closures/';
    Map<String, dynamic>? queryParameters = {
      'restaurant': restaurantId,
      if (upcomingOnly) 'upcoming': 'true',
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      fermetures.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => KitchenClosure.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }
    return fermetures;
  }

  /// Ferme la cuisine de [startsAt] à [endsAt].
  ///
  /// Les instants partent en ISO 8601 **avec leur décalage** (UTC) : sans
  /// fuseau, le serveur les lirait dans le sien.
  Future<KitchenClosure> create({
    required String restaurantId,
    required DateTime startsAt,
    required DateTime endsAt,
    String reason = '',
  }) async {
    final response = await apiClient.post(
      '/restaurants/manage/closures/',
      data: {
        'restaurant': restaurantId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return KitchenClosure.fromJson(response.data as Map<String, dynamic>);
  }

  /// Annule une fermeture — la suppression est réelle.
  Future<void> delete(String closureId) async {
    await apiClient.delete('/restaurants/manage/closures/$closureId/');
  }
}
