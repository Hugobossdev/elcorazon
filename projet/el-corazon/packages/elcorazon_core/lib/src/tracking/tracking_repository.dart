import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/tracking/location_ping.dart';

/// Accès à `/api/v1/tracking/*` — voir `backend/apps/tracking/views.py`.
///
/// L'émission de position passe par **HTTP, pas par le WebSocket**. C'est le
/// contraire de ce que faisait l'app Supabase et de ce que le plan de migration
/// avait d'abord décrit : `ws/couriers/me/` est une file de propositions en
/// lecture seule (`CourierFeedConsumer`), rien n'y remonte. Un relevé perdu
/// n'a de toute façon aucune valeur — c'est le suivant qui compte — alors
/// qu'une file de courses ne doit rien rater, d'où le partage des rôles.
class TrackingRepository {
  TrackingRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Dépose un relevé sur une course du livreur qui appelle.
  ///
  /// Ni la course ni le livreur ne voyagent dans le corps : la première vient
  /// de l'URL, le second du jeton (invariant L3). Un relevé dont l'émetteur
  /// serait un champ du corps laisserait n'importe qui écrire le suivi de
  /// n'importe qui.
  ///
  /// Rend le relevé persisté, ou **`null` quand l'échantillonnage l'a écarté**
  /// (202) — ce qui n'est pas un échec : la position a bien été reçue et le
  /// dossier rafraîchi, elle n'a simplement pas mérité une ligne
  /// supplémentaire. L'appelant ne doit donc ni réessayer, ni signaler une
  /// erreur dans ce cas.
  ///
  /// Le serveur limite la cadence (`TrackingPingThrottle`) : émettre plus vite
  /// que le pas d'échantillonnage ne produit rien de plus qu'un `429`.
  Future<LocationPing?> sendPing({
    required String assignmentId,
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
    double? accuracyMeters,
    double? speedMetersPerSecond,
    double? headingDegrees,
  }) async {
    final response = await apiClient.post(
      '/tracking/assignments/$assignmentId/pings/',
      data: {
        'point': {'lat': latitude, 'lon': longitude},
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'accuracy_m': accuracyMeters,
        'speed_mps': speedMetersPerSecond,
        'heading_deg': headingDegrees,
      },
    );

    if (response.statusCode == 202) return null;
    return LocationPing.fromJson(response.data as Map<String, dynamic>);
  }

  /// Suivi d'une commande, réservé à son client (app `fastfood`).
  Future<OrderTracking> forOrder(String orderId) async {
    final response = await apiClient.get('/tracking/orders/$orderId/');
    return OrderTracking.fromJson(response.data as Map<String, dynamic>);
  }
}
