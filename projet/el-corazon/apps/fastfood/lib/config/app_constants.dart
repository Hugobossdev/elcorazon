class AppConstants {
  // Position de l'établissement (Lomé, Togo) — sert **uniquement** à centrer
  // une carte. Aucun prix n'en découle : les frais de livraison viennent du
  // serveur, qui mesure la distance depuis la position réelle du restaurant en
  // base et applique le barème de la zone d'arrivée.
  static const double restaurantLatitude = 6.1375;
  static const double restaurantLongitude = 1.2123;

  // Slug du restaurant côté backend Django (Phase 6) — un seul établissement
  // actif en base aujourd'hui (`restaurants_restaurant`), donc pas de
  // sélecteur à construire.
  static const String restaurantSlug = 'el-corazon-lome';

  // Slug de la ville côté backend Django (Phase 6) — une seule ville en base
  // aujourd'hui, cohérent avec `restaurantSlug`.
  static const String citySlug = 'lome';

  // Nom affiché de cette ville, et pays où la recherche de lieux est restreinte.
  //
  // Les écrans d'adresse pré-remplissaient « Abidjan » et bornaient
  // l'autocomplétion Google à `country:ci` : un client de Lomé ne recevait
  // aucune suggestion, et la ville enregistrée désignait un autre pays que
  // celui de la seule `City` que le serveur accepte (`citySlug`).
  static const String defaultCityName = 'Lomé';

  /// Code pays ISO 3166-1 alpha-2, en minuscules — attendu ainsi par le
  /// paramètre `components=country:xx` de Google Places.
  static const String countryCode = 'tg';

  /// Rayon, en mètres, dans lequel la recherche de lieux privilégie les
  /// résultats autour de l'établissement. Ne borne pas les résultats : les
  /// biaise seulement, pour qu'une rue homonyme de Lomé passe devant.
  static const int placesBiasRadiusMeters = 25000;

  // App Info
  static const String appName = 'Elcora Fast';
  static const String currency = 'FCFA';
}






