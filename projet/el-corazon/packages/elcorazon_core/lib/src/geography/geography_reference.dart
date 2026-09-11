import 'package:elcorazon_core/src/network/api_client.dart';

/// Une devise et son exposant — miroir de `CurrencySerializer`.
///
/// L'exposant décide de la **saisie** : un montant en XOF (exposant 0) se tape
/// en francs entiers, un montant en EUR (exposant 2) en euros et centimes. Le
/// transporter avec le code évite de redéployer côté client la table que le
/// serveur fait respecter — c'est-à-dire de la dupliquer, puis de la laisser
/// diverger.
class SupportedCurrency {
  const SupportedCurrency({required this.code, required this.exponent});

  factory SupportedCurrency.fromJson(Map<String, dynamic> json) {
    return SupportedCurrency(
      code: json['code'] as String,
      exponent: json['exponent'] as int,
    );
  }

  final String code;

  /// Nombre de décimales. Zéro pour le franc CFA, deux pour l'euro.
  final int exponent;

  /// Le montant se saisit-il avec des décimales ?
  bool get hasSubunit => exponent > 0;

  @override
  String toString() => code;
}

/// Les valeurs qu'un pays peut prendre — `GET /api/v1/geography/reference/`.
///
/// ## Ce que cette classe remplace
///
/// Le formulaire d'ouverture de marché du back-office portait **dix fuseaux
/// horaires écrits en dur** — Abidjan, Lomé, Accra, Porto-Novo, Ouagadougou,
/// Bamako, Dakar, Niamey, Lagos, Douala — et une liste de devises à côté.
/// Ouvrir un marché hors de ces dix demandait de modifier le code Flutter, de
/// recompiler et de republier l'application sur deux magasins : exactement
/// l'opération de développement que le multi-pays existe pour supprimer.
///
/// Pire, les deux listes pouvaient diverger de ce que le serveur accepte. Une
/// devise proposée à l'écran mais absente de la table des exposants produisait
/// un 400 après la saisie de tout le formulaire, sans dire lequel des champs
/// était en cause.
///
/// Les deux listes viennent maintenant de la source qui les fait respecter.
class GeographyReference {
  const GeographyReference({required this.currencies, required this.timezones});

  factory GeographyReference.fromJson(Map<String, dynamic> json) {
    return GeographyReference(
      currencies: (json['currencies'] as List<dynamic>)
          .map((entry) => SupportedCurrency.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      timezones: (json['timezones'] as List<dynamic>)
          .map((entry) => entry as String)
          .toList(growable: false),
    );
  }

  /// Vide — l'état d'avant la première réponse.
  ///
  /// Un écran qui l'affiche montre une liste vide plutôt qu'une sélection
  /// inventée : proposer une devise que le serveur pourrait refuser est
  /// précisément le défaut qu'on corrige.
  static const GeographyReference vide = GeographyReference(
    currencies: [],
    timezones: [],
  );

  final List<SupportedCurrency> currencies;

  /// Identifiants IANA (`Africa/Lome`, `Europe/Paris`), triés.
  ///
  /// Six cents entrées environ. Elles ne sont pas filtrées sur l'Afrique : ce
  /// serait recréer le même plafond un cran plus loin, la liste des dix étant
  /// déjà « ceux dont on avait besoin ». Le tri revient à l'écran, qui a un
  /// champ de recherche.
  final List<String> timezones;

  bool get isEmpty => currencies.isEmpty && timezones.isEmpty;

  /// Fuseaux dont l'identifiant contient [fragment], sans tenir compte de la
  /// casse ni des tirets bas — « porto novo » trouve `Africa/Porto-Novo`.
  List<String> chercherFuseau(String fragment) {
    final requete = _normaliser(fragment);
    if (requete.isEmpty) return timezones;
    return timezones.where((zone) => _normaliser(zone).contains(requete)).toList(growable: false);
  }

  static String _normaliser(String valeur) =>
      valeur.toLowerCase().replaceAll(RegExp('[_ -]'), '');
}

/// Lecture de la référence géographique.
///
/// Route **publique** : ce sont des constantes, pas l'état du réseau. Elles ne
/// disent ni où l'enseigne opère, ni combien d'établissements existent.
class GeographyReferenceRepository {
  GeographyReferenceRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<GeographyReference> fetch() async {
    final response = await apiClient.get('/geography/reference/');
    return GeographyReference.fromJson(response.data as Map<String, dynamic>);
  }
}
