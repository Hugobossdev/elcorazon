import 'package:elcorazon_core/src/network/api_client.dart';

/// Ce que le serveur sait d'une position — miroir de `ReverseGeocodeSerializer`.
///
/// ## Pourquoi ces champs plutôt qu'une chaîne
///
/// L'implémentation précédente rendait `formatted_address` et rien d'autre :
/// l'écran devinait ensuite la ville en cherchant son nom **dans le texte**.
/// « Rue de Lomé, Cotonou » y trouvait Lomé.
///
/// Ces membres viennent des composants **classés par Google**, extraits une
/// seule fois côté serveur. Trois applications ne peuvent donc plus en inventer
/// trois extractions différentes.
///
/// Tout est facultatif sauf les coordonnées : au large, Google ne rend ni pays
/// ni ville, et inventer une valeur serait pire que de n'en rendre aucune.
/// L'écran affiche alors les champs vides, que l'administrateur remplit.
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
    this.placeId,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.district,
    this.postalCode,
    this.street,
    this.streetNumber,
  });

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeResult(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      formattedAddress: json['formatted_address'] as String?,
      placeId: json['place_id'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
      region: json['region'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      postalCode: json['postal_code'] as String?,
      street: json['street'] as String?,
      streetNumber: json['street_number'] as String?,
    );
  }

  final double latitude;
  final double longitude;

  final String? formattedAddress;
  final String? placeId;

  final String? country;

  /// Code ISO 3166-1 alpha-2, en majuscules — `TG`, `CI`, `BJ`, `CM`.
  final String? countryCode;

  final String? region;
  final String? city;

  /// Quartier ou localité fine, quand le lieu en porte un.
  final String? district;

  final String? postalCode;
  final String? street;
  final String? streetNumber;

  /// Adresse de rue reconstituée — « 12 Rue de Lomé » — ou `null`.
  ///
  /// Séparée de [formattedAddress], qui porte aussi la ville et le pays : un
  /// champ « adresse » de formulaire ne doit pas les répéter, puisqu'ils ont
  /// leurs propres champs juste en dessous.
  String? get streetLine {
    final rue = street;
    if (rue == null || rue.isEmpty) return null;
    final numero = streetNumber;
    return (numero == null || numero.isEmpty) ? rue : '$numero $rue';
  }

  /// La position a-t-elle été reconnue par le service d'adressage ?
  ///
  /// Faux au large ou en plein désert. **Ce n'est pas une erreur** : la position
  /// reste valide, et un point de retrait peut se trouver là où aucun service
  /// ne nomme d'adresse.
  bool get isNamed => (formattedAddress ?? '').isNotEmpty;
}

/// Interroge `POST /geography/geocode/reverse/`.
///
/// ## Pourquoi passer par le serveur
///
/// Une clé Google embarquée dans un binaire est publique : on l'extrait d'un
/// APK en quelques minutes, et elle est en clair dans le paquet JavaScript d'un
/// build web. Ici elle reste dans l'environnement du serveur, restreinte par
/// adresse IP — et les réponses s'y mettent en cache, alors qu'un appel direct
/// facture chaque déplacement de marqueur.
///
/// Route **fermée** (`restaurants.write`), contrairement au reste de la
/// géographie : elle consomme un quota facturé chez un tiers, et l'ouvrir en
/// ferait un proxy Google gratuit pour n'importe qui.
class ReverseGeocodeRepository {
  ReverseGeocodeRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Composants d'adresse d'une position.
  ///
  /// Lève une [ApiException] de statut 503 quand le géocodage n'est pas
  /// configuré sur le serveur : c'est une panne d'exploitation, à distinguer
  /// d'une position que Google ne nomme pas — laquelle rend un résultat aux
  /// membres nuls, sans erreur.
  Future<ReverseGeocodeResult> lookup({
    required double latitude,
    required double longitude,
    String language = 'fr',
  }) async {
    final response = await apiClient.post(
      '/geography/geocode/reverse/',
      data: {'lat': latitude, 'lon': longitude, 'language': language},
    );
    return ReverseGeocodeResult.fromJson(response.data as Map<String, dynamic>);
  }
}
