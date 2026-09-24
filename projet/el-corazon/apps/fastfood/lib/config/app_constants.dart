import 'dart:ui' show PlatformDispatcher;

import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Constantes de l'application cliente.
///
/// ## Ce qui n'y est plus
///
/// Six constantes décrivaient l'établissement : son slug, sa latitude, sa
/// longitude, le slug de sa ville, le nom de cette ville et le code de son
/// pays. Elles étaient lues à une trentaine d'endroits — catalogue, panier,
/// commande, recherche, adresses, cartes — et chacune était juste pour un seul
/// restaurant et fausse pour tous les autres : ouvrir un deuxième établissement
/// aurait demandé de modifier ce fichier, de recompiler et de republier
/// l'application sur deux magasins.
///
/// Elles ont été retirées, pas remplacées par d'autres valeurs : ce que le
/// serveur sait, le client le demande (`KitchenContextService`). Ce qui
/// reste ici ne décrit aucun établissement en particulier.
class AppConstants {
  /// Slug de l'article « gâteau sur mesure » au catalogue.
  ///
  /// L'atelier le cherchait par son **nom**, avec un `contains` sur
  /// « personnalisé » ou « custom » : n'importe quel article du catalogue
  /// portant l'un de ces mots — un « Menu personnalisé », un « Burger custom » —
  /// devenait le gâteau sur mesure. Le slug est stable, saisi une fois au
  /// back-office, et ne dépend d'aucun libellé d'affichage.
  static const String gateauSurMesureSlug = 'gateau-personnalise';

  /// Rayon, en mètres, dans lequel la recherche de lieux privilégie les
  /// résultats autour de l'établissement. Ne borne pas les résultats : les
  /// biaise seulement, pour qu'une rue homonyme de Lomé passe devant.
  static const int placesBiasRadiusMeters = 25000;

  /// Pays par défaut des champs téléphoniques, au format attendu par
  /// `IntlPhoneField` (ISO 3166-1 alpha-2, en **majuscules**).
  ///
  /// Celui de l'établissement courant, que le serveur rend ; à défaut, celui
  /// de l'appareil. Il retombait sur le Togo écrit en dur (`'tg'`), proposé
  /// aussi à un client d'Abidjan ou d'Accra. Rien de connu : `null`, et le
  /// champ laisse choisir.
  static String? get phoneCountryCode {
    final code = KitchenContextService().countryCode ??
        PlatformDispatcher.instance.locale.countryCode;
    return (code == null || code.isEmpty) ? null : code.toUpperCase();
  }

  /// Exemple montré en filigrane d'un champ téléphone **libre** (sans
  /// sélecteur de pays). Il commence par l'indicatif du pays de
  /// l'établissement — il était figé sur `+228`, quel que soit le marché.
  static String get phoneHint {
    final indicatif = KitchenContextService().phonePrefix;
    return (indicatif == null || indicatif.isEmpty)
        ? '+indicatif numéro'
        : '$indicatif …';
  }

  /// Numéro à appeler pour joindre le service : celui de l'établissement
  /// courant, tel que le serveur le rend (`Restaurant.phone`). Vide tant que
  /// l'établissement n'est pas connu — les écrans proposent alors le support
  /// écrit plutôt qu'un appel.
  ///
  /// C'était une constante vide « à renseigner avant mise en production » :
  /// le geste d'appel restait masqué pour tout le monde, alors que chaque
  /// établissement a un téléphone, saisi au back-office.
  static String get supportPhone => KitchenContextService().current?.phone ?? '';

  /// Adresse électronique du service client.
  ///
  /// **À renseigner avant mise en production.** Elle était écrite en dur dans
  /// l'écran de contact des visiteurs, sous le domaine `elcorazon.ci` — le
  /// suffixe de la Côte d'Ivoire, alors que l'établissement est à Lomé. Un
  /// message envoyé là partait vers un domaine que personne ici ne relève.
  ///
  /// Vide, la carte « Email » ne s'affiche pas, exactement comme le geste
  /// d'appel disparaît quand [supportPhone] est vide : mieux vaut un moyen de
  /// contact en moins qu'un moyen de contact qui n'aboutit pas. L'adresse de
  /// l'établissement existe côté serveur (`Restaurant.email`) mais la route
  /// publique ne la rend pas : il faudrait l'y ajouter pour la lire ici.
  static const String supportEmail = '';

  // App Info
  static const String appName = 'Elcora Fast';
}
