import 'package:elcorazon_core/src/geography/delivery_zone.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/restaurants/restaurant.dart';

/// **Le référentiel unique de livrabilité, pour les trois applications.**
///
/// ## Ce que ce contrat remplace
///
/// « Puis-je me faire livrer ici, par qui, à quel prix, en combien de temps ? »
/// Le client la pose avant d'enregistrer une adresse, le back-office pour
/// vérifier une configuration, Dely pour situer une course. Aucune ne pouvait
/// obtenir la réponse entière :
///
/// * `GET /geography/zones/resolve/` rendait **la zone seule** — ni
///   établissement, ni frais, ni distance, ni délai ;
/// * le devis complet n'existait qu'à l'intérieur du passage de commande, donc
///   seulement pour quelqu'un ayant déjà un panier ouvert.
///
/// Chaque écran recomposait le reste à sa façon, et l'écart le plus grave était
/// invisible : la zone retenue pour *afficher* un tarif n'était pas choisie par
/// la même règle que celle retenue pour le *facturer*.
///
/// ## Pourquoi le refus est aussi important que l'acceptation
///
/// [reason] dit **pourquoi** on ne livre pas. Sans elle, chaque application
/// inventerait son message, et elles en inventeraient trois différents — que le
/// refus soit « hors zone », « trop loin », « panier trop léger » ou « aucune
/// cuisine ouverte ». Ces quatre cas appellent quatre gestes distincts :
/// changer d'adresse, en changer encore, ajouter un article, revenir plus tard.
class DeliveryAvailability {
  const DeliveryAvailability({
    required this.isAvailable,
    this.reason,
    this.restaurant,
    this.zone,
    this.distanceMeters,
    this.estimatedMinutes,
    this.deliveryFee,
    this.grossDeliveryFee,
    this.isFreeDelivery,
  });

  factory DeliveryAvailability.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    final zone = json['zone'] as Map<String, dynamic>?;
    final frais = json['delivery_fee'] as Map<String, dynamic>?;
    final brut = json['gross_delivery_fee'] as Map<String, dynamic>?;

    return DeliveryAvailability(
      isAvailable: json['is_available'] as bool? ?? false,
      reason: json['reason'] as String?,
      restaurant: restaurant == null ? null : Restaurant.fromJson(restaurant),
      zone: zone == null ? null : DeliveryZone.fromJson(zone),
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      estimatedMinutes: json['estimated_minutes'] as int?,
      deliveryFee: frais == null ? null : Money.fromJson(frais),
      grossDeliveryFee: brut == null ? null : Money.fromJson(brut),
      isFreeDelivery: json['is_free_delivery'] as bool?,
    );
  }

  final bool isAvailable;

  /// Ce qui empêche la livraison, en clair. Nul quand elle est possible.
  final String? reason;

  /// L'établissement qui dessert — celui qu'on a demandé, ou le plus proche que
  /// le serveur a choisi. Nul quand aucun ne dessert le point.
  final Restaurant? restaurant;

  final DeliveryZone? zone;

  /// Distance à vol d'oiseau, mesurée par PostGIS sur l'ellipsoïde. **Jamais
  /// recalculée ici** : une seconde formule donnerait un second chiffre, et
  /// c'est le premier qui facture.
  final double? distanceMeters;

  /// Préparation en cuisine **plus** course — ce que le client attend
  /// réellement. La zone ne connaît que le trajet, et l'annoncer seul
  /// promettait un repas en trente minutes là où la cuisine en demande vingt
  /// de plus.
  final int? estimatedMinutes;

  /// Ce qu'on facture. Nul tant qu'aucun sous-total n'a été fourni : un montant
  /// minimum ne veut rien dire face à un panier vide.
  final Money? deliveryFee;

  /// Ce que la course vaut, avant franco. Les deux diffèrent quand la livraison
  /// est offerte — et il faut les deux, parce que l'offrir au client ne veut
  /// pas dire que le livreur roule gratuitement. C'est aussi ce qui permet
  /// d'afficher un prix barré.
  final Money? grossDeliveryFee;

  final bool? isFreeDelivery;

  /// Distance lisible : « 850 m » ou « 1,2 km ».
  ///
  /// Nul quand le serveur n'a pas mesuré. Afficher « 0 km » ferait croire à une
  /// proximité qu'on n'a pas établie.
  String? get distanceLabel {
    final metres = distanceMeters;
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}

/// Interroge `POST /restaurants/delivery-check/`.
///
/// Route **publique** : un visiteur doit pouvoir savoir si on le livre avant de
/// créer un compte. Exiger une inscription pour répondre « non, pas encore chez
/// vous » est le meilleur moyen de ne jamais revoir la personne.
class DeliveryCheckRepository {
  DeliveryCheckRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Livrabilité d'une position.
  ///
  /// [restaurantSlug] restreint la question à *cet* établissement — le cas du
  /// panier déjà ouvert, où en changer changerait le catalogue et les prix.
  /// Omis, le serveur choisit le plus proche qui dessert, ce qui évite au
  /// client de désigner une cuisine que la géographie détermine.
  ///
  /// [subtotal] déclenche la tarification. Sans lui, la réponse dit si l'adresse
  /// est desservie sans chiffrer.
  Future<DeliveryAvailability> check({
    required double latitude,
    required double longitude,
    String? restaurantSlug,
    Money? subtotal,
  }) async {
    final response = await apiClient.post(
      '/restaurants/delivery-check/',
      data: {
        'lat': latitude,
        'lon': longitude,
        if (restaurantSlug != null) 'restaurant': restaurantSlug,
        if (subtotal != null) 'subtotal': subtotal.toJson(),
      },
    );
    return DeliveryAvailability.fromJson(response.data as Map<String, dynamic>);
  }
}
