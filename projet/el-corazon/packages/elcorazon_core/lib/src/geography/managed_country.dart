/// Pays vu de l'exploitation — miroir de `ManagedCountrySerializer`
/// (`backend/apps/geography/serializers.py`).
///
/// Le pays est le sommet de la hiérarchie de l'ADR-006, et il porte ce qu'aucun
/// échelon inférieur n'a le droit de choisir : la **devise** et le **fuseau**.
/// Deux établissements d'un même marché ne peuvent donc pas facturer dans deux
/// unités, ni ouvrir à deux heures différentes du même instant.
///
/// Il n'y avait aucun modèle de pays côté Flutter : la route publique
/// `/geography/countries/` existait, la route d'administration aussi, et rien
/// ne les appelait. C'est ce trou qui rendait l'ouverture d'un marché
/// impossible depuis le back-office — il fallait passer par `django-admin`.
class ManagedCountry {
  const ManagedCountry({
    required this.id,
    required this.isoCode,
    required this.name,
    required this.currency,
    required this.phonePrefix,
    required this.timezone,
    required this.defaultLanguage,
    required this.isActive,
  });

  factory ManagedCountry.fromJson(Map<String, dynamic> json) {
    return ManagedCountry(
      id: json['id'] as String,
      isoCode: json['iso_code'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String,
      phonePrefix: json['phone_prefix'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'UTC',
      defaultLanguage: json['default_language'] as String? ?? 'fr',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;

  /// Code ISO 3166-1 alpha-2, en **majuscules** (`TG`, `CI`, `BJ`).
  ///
  /// C'est l'identifiant que le serveur attend partout — `lookup_field` de la
  /// route publique, `SlugRelatedField` de la ville — et non l'UUID. Une ville
  /// se rattache donc à `"CI"`, pas à une clé primaire que personne ne retient.
  final String isoCode;

  final String name;

  /// ISO 4217. **Figée sur chaque commande** au moment de sa création : la
  /// changer sur un marché en activité ne convertit rien rétroactivement et
  /// produirait un historique dans deux unités.
  final String currency;

  /// Par exemple `+228`. Sert d'indicatif par défaut aux champs de saisie du
  /// pays.
  final String phonePrefix;

  /// Fuseau IANA (`Africa/Lome`). C'est lui qui décide si un restaurant du pays
  /// est ouvert : un serveur en UTC fermerait sinon une heure trop tôt.
  final String timezone;

  final String defaultLanguage;

  /// Un pays fermé disparaît des applications clientes — ses villes, ses zones
  /// et ses établissements avec lui — sans que rien ne soit supprimé : les
  /// commandes déjà passées là-bas restent lisibles dans leur devise.
  final bool isActive;

  /// « Côte d'Ivoire (CI) » — l'intitulé des listes déroulantes.
  String get label => '$name ($isoCode)';
}
