import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;

/// Lecture de l'annuaire. Séparée du service pour que les tests n'aient pas à
/// monter une pile HTTP là où ils vérifient une décision.
typedef LectureDesEtablissements =
    Future<List<eccore.Restaurant>> Function({double? latitude, double? longitude});

/// **Sur quel restaurant porte l'application.**
///
/// ## Ce que ce service remplace
///
/// L'application portait six constantes dans [AppConstants] — le slug de
/// l'établissement, sa latitude, sa longitude, le slug de sa ville, le nom de
/// cette ville et le code de son pays — recopiées à travers une trentaine
/// d'appels : le catalogue, le panier, la commande, la recherche, le panier
/// collaboratif, la synchronisation hors-ligne, les frais de livraison, la
/// carte d'adresse et l'écran de suivi.
///
/// Chacune était juste pour un seul établissement et fausse pour tous les
/// autres. Ouvrir un second restaurant aurait donc demandé de modifier le code
/// de l'application, de la recompiler et de la republier sur deux magasins —
/// alors que le serveur, lui, sait répondre depuis l'origine.
///
/// ## Ce qu'il n'est pas
///
/// Ce n'est pas une couche de sécurité ni de validation. Le serveur cloisonne
/// déjà : un panier appartient à un établissement, une commande aussi, et une
/// demande portant un slug inconnu sort en 404. Ce service dit **quoi
/// demander**, pas ce qui est permis.
///
/// ## Pourquoi il notifie
///
/// Changer d'établissement change le catalogue, les prix, les frais et le
/// panier. Les écrans et les caches qui s'y abonnent doivent se vider :
/// afficher les plats de Lomé sous le nom d'Abidjan serait pire qu'une liste
/// vide, parce que rien ne le signalerait. C'est ce que garde
/// [ecouterLeChangement].
class RestaurantContextService extends ChangeNotifier {
  static final RestaurantContextService _instance = RestaurantContextService._();

  factory RestaurantContextService() => _instance;

  RestaurantContextService._();

  /// Instance isolée, alimentée par une lecture donnée. Réservée aux tests.
  @visibleForTesting
  RestaurantContextService.avecLecture(
    LectureDesEtablissements lecture, {
    SharedPreferences? preferences,
  }) : _lecture = lecture,
       _prefs = preferences;

  LectureDesEtablissements? _lecture;
  SharedPreferences? _prefs;

  LectureDesEtablissements get _lireLAnnuaire =>
      _lecture ??
      eccore.RestaurantDirectoryRepository(apiClient: apiClient).list;

  /// Clé du choix, conservé d'une session à l'autre.
  ///
  /// Rouvrir l'application sur un autre restaurant que celui qu'on parcourait
  /// la veille serait déroutant, et le panier serveur — qui est **par
  /// établissement** — semblerait avoir disparu.
  static const String _cleDuChoix = 'restaurant_context_slug';

  List<eccore.Restaurant> _etablissements = const [];
  String? _slugChoisi;
  bool _isLoading = false;
  bool _resolu = false;
  String? _error;

  /// Établissements en service, dans l'ordre rendu par le serveur.
  List<eccore.Restaurant> get restaurants => List.unmodifiable(_etablissements);

  /// Établissement courant : celui qu'on a choisi, ou le premier de la liste.
  ///
  /// Rendre le premier plutôt que rien est un raccourci assumé : l'enseigne
  /// n'en a qu'un dans l'immense majorité des cas, et obliger à choisir pour
  /// n'avoir qu'une option serait une étape vide. Le même raisonnement que
  /// `RestaurantScopeService` côté back-office.
  eccore.Restaurant? get current {
    if (_etablissements.isEmpty) return null;
    final choisi = _slugChoisi;
    if (choisi == null) return _etablissements.first;
    for (final etablissement in _etablissements) {
      if (etablissement.slug == choisi) return etablissement;
    }
    return _etablissements.first;
  }

  /// Y a-t-il plusieurs établissements ? Condition d'affichage d'un sélecteur ;
  /// en dessous, il n'y a rien à choisir.
  bool get hasChoice => _etablissements.length > 1;

  bool get isLoading => _isLoading;
  bool get isResolved => _resolu;
  String? get error => _error;

  // ------------------------------------------------ ce que les écrans lisent

  /// Slug de l'établissement courant, ou `null` tant que rien n'est résolu.
  ///
  /// **Nul plutôt qu'une valeur de repli** : un appelant qui écrit ne doit pas
  /// deviner à la place du serveur. C'est précisément ce que faisait la
  /// constante, et c'est pourquoi elle était fausse dès le deuxième
  /// établissement.
  String? get slug => current?.slug;

  /// Position de l'établissement — centre des cartes, origine des distances
  /// d'affichage. `null` tant que rien n'est résolu.
  ///
  /// Aucun calcul de prix n'en découle : les frais viennent du serveur, qui
  /// mesure depuis la position en base et applique le barème de la zone
  /// d'arrivée.
  double? get latitude => current?.latitude;
  double? get longitude => current?.longitude;

  /// Ville de l'établissement — son nom pour l'affichage, son slug pour
  /// rattacher une adresse.
  String? get cityName => current?.cityName;
  String? get citySlug => current?.citySlug;

  /// Code pays ISO en **minuscules**, tel que l'attend le paramètre
  /// `components=country:xx` de Google Places.
  String? get countryCode {
    final code = current?.countryIsoCode;
    return (code == null || code.isEmpty) ? null : code.toLowerCase();
  }

  /// Indicatif téléphonique du pays (`+228`), pour les champs de saisie.
  String? get phonePrefix => current?.phonePrefix;

  /// Devise de l'établissement, héritée de son pays.
  String? get currency => current?.currency;

  /// Nom affiché de l'établissement.
  String? get name => current?.name;

  // ----------------------------------------------------------- résolution

  /// Charge l'annuaire une fois. Un second appel ne refait rien, sauf [force].
  ///
  /// [latitude] et [longitude] font trier par proximité côté serveur : à
  /// l'ouverture de l'application, le restaurant le plus proche du client passe
  /// donc en tête, et c'est celui qui sera choisi par défaut.
  Future<void> resolve({
    bool force = false,
    double? latitude,
    double? longitude,
  }) async {
    if (_isLoading) return;
    if (_resolu && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ancien = slug;
      _etablissements = await _lireLAnnuaire(latitude: latitude, longitude: longitude);
      _resolu = true;

      await _restaurerLeChoix();

      eccore.Journal.trace(
        'RestaurantContext : ${_etablissements.length} établissement(s), '
        'courant = ${slug ?? "aucun"}',
      );

      // L'établissement courant a pu changer sans qu'on l'ait choisi : celui
      // qu'on parcourait a été suspendu, et il ne figure plus dans l'annuaire.
      // Les caches doivent alors se vider comme pour un changement explicite.
      if (ancien != null && ancien != slug) _signalerLeChangement(ancien);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('RestaurantContext : annuaire illisible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Villes desservies, dans l'ordre d'apparition de l'annuaire.
  ///
  /// Sert au sélecteur : quand l'enseigne couvre deux villes, « choisir une
  /// cuisine » commence par « choisir une ville ». Dérivée de l'annuaire plutôt
  /// que lue sur `/geography/cities/` — cette route-là rend les villes *où
  /// l'enseigne pourrait ouvrir*, pas celles où elle sert réellement, et
  /// proposer une ville sans restaurant serait une impasse.
  List<String> get villesDesservies {
    final vues = <String>{};
    final ordonnees = <String>[];
    for (final etablissement in _etablissements) {
      if (etablissement.cityName.isNotEmpty && vues.add(etablissement.cityName)) {
        ordonnees.add(etablissement.cityName);
      }
    }
    return List.unmodifiable(ordonnees);
  }

  /// Établissements d'une ville donnée.
  List<eccore.Restaurant> etablissementsDe(String cityName) => List.unmodifiable(
    _etablissements.where((etablissement) => etablissement.cityName == cityName),
  );

  /// Recharge l'annuaire en le faisant trier par proximité côté serveur.
  ///
  /// **Ne change pas le choix explicite du client.** `resolve` restaure le slug
  /// mémorisé, si bien que trier ne fait que réordonner l'affichage : quelqu'un
  /// qui a choisi un restaurant précis le garde même en changeant de quartier.
  /// C'est voulu — le tri est une aide à la découverte, pas une décision prise
  /// à la place du client.
  ///
  /// Le tri est fait par PostGIS sur un index géographique, pas ici : la
  /// variante locale — tout charger, calculer, trier — donnerait le même
  /// résultat sur dix restaurants et deviendrait impraticable à mille.
  Future<void> trierParProximite({
    required double latitude,
    required double longitude,
  }) => resolve(force: true, latitude: latitude, longitude: longitude);

  /// Slug à écrire, en résolvant l'annuaire si ce n'est pas déjà fait.
  ///
  /// Rend `null` quand rien n'est disponible : l'appelant doit alors refuser sa
  /// requête plutôt que de la tenter sur un établissement inventé. Le serveur
  /// la refuserait, mais bien plus tard et sans dire pourquoi.
  Future<String?> requireSlug() async {
    if (!_resolu) await resolve();
    return slug;
  }

  /// Slug de l'établissement courant, ou une exception qui dit pourquoi.
  ///
  /// C'est la forme qu'appellent le catalogue, le panier, la commande et les
  /// frais : aucun n'a de conduite sensible sans établissement, et aucun ne
  /// doit en inventer un. L'exception est **explicite** plutôt qu'un `null`
  /// silencieux ou une constante de repli — c'est précisément la constante de
  /// repli qui faisait envoyer les commandes du deuxième restaurant au premier.
  Future<String> exigerSlug() async {
    final courant = await requireSlug();
    if (courant == null) throw AucunEtablissement(_error);
    return courant;
  }

  /// Choisit l'établissement courant.
  ///
  /// Un slug absent de l'annuaire est ignoré : le sélecteur n'est pas une porte
  /// d'entrée vers un établissement que le serveur ne sert pas.
  Future<void> select(String slug) async {
    if (!_etablissements.any((etablissement) => etablissement.slug == slug)) return;
    final ancien = _slugChoisi ?? this.slug;
    if (ancien == slug) return;

    _slugChoisi = slug;
    await _memoriserLeChoix(slug);

    if (ancien != null) _signalerLeChangement(ancien);
    notifyListeners();
  }

  // ---------------------------------------------- réaction au changement

  final List<void Function(String ancien, String nouveau)> _abonnes = [];

  /// S'abonne au changement d'établissement.
  ///
  /// Distinct de [addListener], qui se déclenche aussi pour un simple
  /// chargement : ce rappel ne part que lorsque **l'établissement change
  /// vraiment**, et c'est la seule occasion où un cache doit se vider. Un
  /// vidage sur chaque notification effacerait le panier à chaque
  /// rafraîchissement de l'annuaire.
  ///
  /// Rend la fonction de désabonnement.
  VoidCallback ecouterLeChangement(void Function(String ancien, String nouveau) rappel) {
    _abonnes.add(rappel);
    return () => _abonnes.remove(rappel);
  }

  void _signalerLeChangement(String ancien) {
    final nouveau = slug;
    if (nouveau == null || nouveau == ancien) return;
    // Copie de la liste : un abonné qui se désabonne depuis son propre rappel
    // modifierait la collection en cours d'itération.
    for (final rappel in List.of(_abonnes)) {
      rappel(ancien, nouveau);
    }
  }

  // ------------------------------------------------------------ persistance

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _restaurerLeChoix() async {
    if (_slugChoisi != null) return;
    try {
      final memorise = (await _preferences).getString(_cleDuChoix);
      if (memorise == null) return;
      // Le choix mémorisé peut désigner un établissement suspendu depuis :
      // on ne le retient que s'il est encore servi.
      if (_etablissements.any((etablissement) => etablissement.slug == memorise)) {
        _slugChoisi = memorise;
      }
    } on Exception catch (e) {
      eccore.Journal.trace('RestaurantContext : choix non restauré — $e');
    }
  }

  Future<void> _memoriserLeChoix(String slug) async {
    try {
      await (await _preferences).setString(_cleDuChoix, slug);
    } on Exception catch (e) {
      eccore.Journal.trace('RestaurantContext : choix non mémorisé — $e');
    }
  }

  /// Oublie tout — à la déconnexion, et dans les tests.
  @visibleForTesting
  void reset() {
    _etablissements = const [];
    _slugChoisi = null;
    _resolu = false;
    _error = null;
    notifyListeners();
  }
}

/// Aucun établissement disponible pour servir la demande.
///
/// Levée plutôt que de retomber sur une valeur par défaut : un slug inventé
/// produit une requête qui aboutit — sur le mauvais restaurant — au lieu
/// d'échouer franchement. C'est le défaut exact que le contexte remplace.
class AucunEtablissement implements Exception {
  const AucunEtablissement([this.cause]);

  /// Ce que le serveur a répondu, quand il a répondu. Nul quand l'annuaire est
  /// simplement vide : aucun établissement n'est en service.
  final String? cause;

  String get message => cause == null
      ? "Aucun restaurant n'est en service pour le moment."
      : "La liste des restaurants n'a pas pu être chargée : $cause";

  @override
  String toString() => 'AucunEtablissement($message)';
}
