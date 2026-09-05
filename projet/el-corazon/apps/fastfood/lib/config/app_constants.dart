import 'package:elcora_fast/services/restaurant_context_service.dart';

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
/// serveur sait, le client le demande (`RestaurantContextService`). Ce qui
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

  /// Code pays ISO 3166-1 alpha-2, en minuscules — attendu ainsi par le
  /// paramètre `components=country:xx` de Google Places.
  ///
  /// **Repli seulement.** Le pays réel vient de l'établissement courant
  /// (`RestaurantContextService.countryCode`), qui le tient du serveur. Cette
  /// valeur ne sert plus qu'au premier affichage d'un champ téléphonique, avant
  /// que l'annuaire ait répondu : un sélecteur d'indicatif doit bien s'ouvrir
  /// sur quelque chose, et le marché historique est le moins mauvais des
  /// choix — il n'engage rien, l'utilisateur pouvant en changer.
  ///
  /// Aucune requête ne la lit : le catalogue, le panier, la commande, les
  /// adresses et l'autocomplétion passent tous par le contexte.
  static const String countryCode = 'tg';

  /// Rayon, en mètres, dans lequel la recherche de lieux privilégie les
  /// résultats autour de l'établissement. Ne borne pas les résultats : les
  /// biaise seulement, pour qu'une rue homonyme de Lomé passe devant.
  static const int placesBiasRadiusMeters = 25000;

  /// Indicatif téléphonique par défaut des champs de saisie, au format
  /// attendu par `IntlPhoneField` (ISO 3166-1 alpha-2, en **majuscules**).
  ///
  /// Dérivé du pays plutôt qu'écrit à côté : l'inscription proposait le Togo,
  /// la modification du profil la Côte d'Ivoire, et un même client enregistrait
  /// donc deux numéros de pays différents selon l'écran par lequel il passait.
  ///
  /// Le pays de l'établissement courant l'emporte quand il est connu ; à
  /// défaut, [countryCode]. Le repli est ici acceptable là où il ne le serait
  /// pas ailleurs : un indicatif proposé n'est qu'une suggestion, que le client
  /// corrige d'un geste, alors qu'un slug de restaurant deviné envoie une
  /// commande au mauvais endroit sans que personne ne le voie.
  static String get phoneCountryCode =>
      (RestaurantContextService().countryCode ?? countryCode).toUpperCase();

  /// Exemple montré en filigrane d'un champ téléphone. Suit le pays ci-dessus.
  static const String phoneHint = '+228 90 00 00 00';

  /// Numéro du service client.
  ///
  /// **À renseigner avant mise en production.** Il était jusqu'ici écrit en
  /// dur à deux endroits, avec deux valeurs différentes et toutes deux
  /// ivoiriennes (`+22507070707`, `+2250700000000`) alors que l'établissement
  /// est à Lomé — c'est-à-dire deux numéros inventés, dont l'un au moins
  /// aboutissait chez un inconnu. Vide, les écrans proposent le support écrit
  /// plutôt qu'un appel qui ne mènerait nulle part.
  static const String supportPhone = '';

  /// Adresse électronique du service client.
  ///
  /// **À renseigner avant mise en production.** Elle était écrite en dur dans
  /// l'écran de contact des visiteurs, sous le domaine `elcorazon.ci` — le
  /// suffixe de la Côte d'Ivoire, alors que l'établissement est à Lomé. Un
  /// message envoyé là partait vers un domaine que personne ici ne relève.
  ///
  /// Vide, la carte « Email » ne s'affiche pas, exactement comme le geste
  /// d'appel disparaît quand [supportPhone] est vide : mieux vaut un moyen de
  /// contact en moins qu'un moyen de contact qui n'aboutit pas.
  static const String supportEmail = '';

  // App Info
  static const String appName = 'Elcora Fast';

  /// Symbole de repli pour un montant dont on ne connaît pas encore la devise.
  ///
  /// La devise réelle est portée par chaque montant (`Money`, ADR-007) et par
  /// l'établissement courant (`RestaurantContextService.currency`) : elle est
  /// héritée du pays et diffère d'un marché à l'autre. Cette constante n'est
  /// qu'un libellé de secours, jamais une unité de calcul.
  static const String currency = 'FCFA';
}
