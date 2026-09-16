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
    this.debutLocal = '',
    this.finLocal = '',
    this.fuseau = '',
  });

  factory KitchenClosure.fromJson(Map<String, dynamic> json) => KitchenClosure(
    id: json['id'] as String,
    restaurantId: json['restaurant'].toString(),
    restaurantName: json['restaurant_name'] as String? ?? '',
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    reason: json['reason'] as String? ?? '',
    isCurrent: json['is_current'] as bool? ?? false,
    debutLocal: json['starts_at_local'] as String? ?? '',
    finLocal: json['ends_at_local'] as String? ?? '',
    fuseau: json['timezone_name'] as String? ?? '',
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

  /// Le début et la fin **en heure de la cuisine**, tels que le serveur les
  /// compose — ISO 8601 avec le décalage du pays.
  ///
  /// ## Pourquoi ce n'est pas calculé ici
  ///
  /// Convertir vers le fuseau d'une cuisine demande la base de fuseaux
  /// horaires, que l'application n'embarque pas. Le back-office affichait donc
  /// l'heure **du poste** : un siège à Lomé lisait « 01 h 00 » sur une
  /// fermeture de Douala saisie à minuit. Le serveur, lui, connaît le fuseau —
  /// c'est le même qui sert à juger des horaires d'ouverture.
  ///
  /// Vides quand le serveur est antérieur à ce contrat : l'écran retombe alors
  /// sur l'instant absolu, en le disant.
  final String debutLocal;
  final String finLocal;

  /// Le fuseau de la cuisine (« Africa/Douala »), pour le dire à l'écran.
  final String fuseau;

  /// Terminée à [maintenant] — elle ne ferme plus rien.
  bool isPastAt(DateTime maintenant) => !endsAt.isAfter(maintenant);
}

/// « 2026-12-25T00:00:00 » — la date et l'heure telles qu'elles ont été
/// saisies, **sans fuseau** : c'est le serveur qui les situe, dans celui de la
/// cuisine concernée.
///
/// Un « Z » ou un décalage en ferait un instant absolu, ce que le serveur
/// refuse sur ce champ — et ce qui reproduirait le défaut d'origine, où
/// l'horloge du **poste** décidait de l'heure d'une cuisine d'un autre pays :
/// fermer Douala « le 25 à minuit » depuis Lomé fermait à une heure du matin.
String heureMurale(DateTime quand) {
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${quand.year}-${deux(quand.month)}-${deux(quand.day)}'
      'T${deux(quand.hour)}:${deux(quand.minute)}:00';
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

  /// Ferme la cuisine de [debut] à [fin], **en heure de la cuisine**.
  ///
  /// ## Ce que cette signature change
  ///
  /// Elle prenait deux instants absolus, que l'écran fabriquait à partir de
  /// l'horloge du poste : fermer Douala « le 25 à minuit » depuis Lomé fermait
  /// à une heure du matin, heure de Douala. Les horaires d'ouverture, eux, se
  /// saisissent depuis toujours en heure de la cuisine — deux conventions pour
  /// deux champs voisins du même écran.
  ///
  /// Les deux instants partent donc **sans décalage** (`2026-12-25T00:00:00`)
  /// et le serveur les situe dans le fuseau de l'établissement, qu'il est seul
  /// à connaître de façon sûre.
  Future<KitchenClosure> create({
    required String restaurantId,
    required DateTime debut,
    required DateTime fin,
    String reason = '',
  }) async {
    final response = await apiClient.post(
      '/restaurants/manage/closures/',
      data: {
        'restaurant': restaurantId,
        'starts_at_local': _heureMurale(debut),
        'ends_at_local': _heureMurale(fin),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return KitchenClosure.fromJson(response.data as Map<String, dynamic>);
  }

  static String _heureMurale(DateTime quand) => heureMurale(quand);

  /// Annule une fermeture — la suppression est réelle.
  Future<void> delete(String closureId) async {
    await apiClient.delete('/restaurants/manage/closures/$closureId/');
  }
}
