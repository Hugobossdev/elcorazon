import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/opening_hours.dart';

/// Horaires d'ouverture — `/api/v1/restaurants/manage/hours/`
/// (`backend/apps/restaurants/backoffice.py`).
///
/// Le back-office avait un onglet « Horaires » qui n'écrivait **nulle part** :
/// une heure d'ouverture, une heure de fermeture et sept interrupteurs, rangés
/// dans les préférences locales du poste, relus par personne — pas même par
/// l'écran qui les avait écrits. Le bandeau annonçait « Paramètres sauvegardés
/// avec succès », et les applications clientes n'en voyaient rien.
///
/// Trois gestes unitaires plutôt qu'un enregistrement de la semaine entière :
/// ajouter une plage, en corriger une, en retirer une. Un `PUT` global
/// réécrirait ce qu'un collègue vient de saisir depuis un autre poste.
///
/// C'est la seule ressource de back-office dont la **suppression est réelle** :
/// une plage horaire n'est référencée par rien, et une plage « désactivée » qui
/// resterait dans un tableau hebdomadaire serait plus déroutante qu'utile.
class ManagedOpeningHoursRepository {
  ManagedOpeningHoursRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Plages du périmètre, du lundi au dimanche puis par heure d'ouverture —
  /// l'ordre du serveur, qui est déjà celui d'un tableau hebdomadaire.
  Future<List<OpeningHours>> list({String? restaurantId}) async {
    final plages = <OpeningHours>[];
    String? path = '/restaurants/manage/hours/';
    Map<String, dynamic>? queryParameters = {
      if (restaurantId != null) 'restaurant': restaurantId,
    };

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: queryParameters);
      final body = response.data as Map<String, dynamic>;
      plages.addAll(
        (body['results'] as List<dynamic>).map(
          (json) => OpeningHours.fromJson(json as Map<String, dynamic>),
        ),
      );
      path = body['next'] as String?;
      queryParameters = null;
    }

    return plages;
  }

  /// Ajoute une plage.
  ///
  /// [restaurantId] est l'**identifiant** de l'établissement et non son slug :
  /// c'est ce qu'attend `PrimaryKeyRelatedField` sur cette route, à la
  /// différence du catalogue qui s'adresse par slug.
  Future<OpeningHours> create({
    required String restaurantId,
    required int weekday,
    required int opensAtMinutes,
    required int closesAtMinutes,
  }) async {
    final response = await apiClient.post(
      '/restaurants/manage/hours/',
      data: {
        'restaurant': restaurantId,
        'weekday': weekday,
        'opens_at': OpeningHours.formatTime(opensAtMinutes),
        'closes_at': OpeningHours.formatTime(closesAtMinutes),
      },
    );
    return OpeningHours.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OpeningHours> update({
    required String hoursId,
    int? weekday,
    int? opensAtMinutes,
    int? closesAtMinutes,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/manage/hours/$hoursId/',
      data: {
        if (weekday != null) 'weekday': weekday,
        if (opensAtMinutes != null) 'opens_at': OpeningHours.formatTime(opensAtMinutes),
        if (closesAtMinutes != null) 'closes_at': OpeningHours.formatTime(closesAtMinutes),
      },
    );
    return OpeningHours.fromJson(response.data as Map<String, dynamic>);
  }

  /// Retire une plage. Fermer un jour, c'est n'y laisser aucune plage.
  Future<void> delete(String hoursId) async {
    await apiClient.delete('/restaurants/manage/hours/$hoursId/');
  }
}
