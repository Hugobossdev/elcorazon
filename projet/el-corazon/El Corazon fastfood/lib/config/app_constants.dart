class AppConstants {
  // Restaurant Location (Lomé, Togo)
  static const double restaurantLatitude = 6.1375;
  static const double restaurantLongitude = 1.2123;

  // Slug du restaurant côté backend Django (Phase 6) — un seul établissement
  // actif en base aujourd'hui (`restaurants_restaurant`), donc pas de
  // sélecteur à construire.
  static const String restaurantSlug = 'el-corazon-lome';

  // Slug de la ville côté backend Django (Phase 6) — une seule ville en base
  // aujourd'hui, cohérent avec `restaurantSlug`.
  static const String citySlug = 'lome';

  // App Info
  static const String appName = 'Elcora Fast';
  static const String currency = 'FCFA';
}






