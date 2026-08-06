/// Ville vue de l'exploitation — miroir de `ManagedCitySerializer`
/// (`backend/apps/geography/serializers.py`).
///
/// Elle se distingue de [City], que rend la route publique, sur deux points qui
/// comptent pour le back-office :
///
/// * **`isActive` existe.** La liste publique ne rend que les villes
///   desservies ; celle du siège les rend toutes, sans quoi fermer une ville la
///   ferait disparaître de l'écran qui sert à la rouvrir ;
/// * **le pays est un code ISO**, pas un objet imbriqué. La route publique
///   imbrique le pays entier parce qu'un client a besoin de la devise pour
///   afficher un prix ; le siège, lui, ne fait que regrouper.
class ManagedCity {
  const ManagedCity({
    required this.id,
    required this.name,
    required this.slug,
    required this.countryIsoCode,
    required this.isActive,
  });

  factory ManagedCity.fromJson(Map<String, dynamic> json) {
    return ManagedCity(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      countryIsoCode: json['country'].toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String slug;

  /// Code ISO du pays (`SlugRelatedField(slug_field="iso_code")`), et non sa
  /// clé primaire : c'est ce que le serveur attend en écriture comme en
  /// lecture.
  final String countryIsoCode;

  final bool isActive;
}
