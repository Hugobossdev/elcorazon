import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/main.dart' show apiClient;

/// Lecture de l'annuaire des cuisines. Séparée du service pour que les tests
/// n'aient pas à monter une pile HTTP là où ils vérifient une décision.
typedef LectureDesCuisines =
    Future<List<eccore.Restaurant>> Function({double? latitude, double? longitude});

/// « Cette adresse est-elle livrée, et par quelle cuisine ? » —
/// `POST /restaurants/delivery-check/`. Même séparation, même raison.
typedef VerificationDeLivraison =
    Future<eccore.DeliveryAvailability> Function({
      required double latitude,
      required double longitude,
      String? restaurantSlug,
    });

/// Un point de livraison : l'adresse retenue par le client.
typedef PointDeLivraison = ({double latitude, double longitude});

/// Où en est la résolution de l'annuaire.
enum EtatDuContexte {
  /// Rien n'a encore été demandé.
  initial,
  chargement,

  /// L'annuaire a répondu, avec au moins une cuisine.
  pret,

  /// L'annuaire a **répondu**, vide : aucune cuisine n'est en service.
  aucuneCuisine,

  /// L'annuaire n'a pas pu être lu — la nature est dans `KitchenContextService.echec`.
  echec,

  /// La position transmise pour trier a été refusée par le serveur.
  localisationInvalide,
}

/// Ce que la géographie répond pour l'adresse de livraison du client.
enum DesserteAdresse {
  /// Aucune adresse connue, ou pas encore vérifiée.
  inconnue,

  /// La cuisine courante livre cette adresse.
  desservie,

  /// Une cuisine existe, mais l'adresse sort de sa desserte.
  nonDesservie,

  /// Aucune cuisine en service ne dessert cette adresse — **réponse** du
  /// serveur, jamais une panne.
  aucuneCuisine,

  /// La vérification n'a pas abouti. Ce n'est pas « non desservie ».
  verificationImpossible,
}

/// **La situation de la cuisine, telle qu'un écran doit la dire.**
///
/// Une seule valeur, composée ici une fois, pour que le catalogue, l'accueil,
/// le sélecteur et le paiement disent la même chose — et surtout pour que
/// jamais une panne ne se lise comme une absence de cuisine.
enum SituationCuisine {
  chargement,
  commandable,
  fermee,
  enPause,
  suspendue,
  indisponible,
  aucuneCuisine,
  adresseNonDesservie,
  erreurReseau,
  erreurAuthentification,
  erreurAutorisation,
  erreurServeur,
  erreurApi,
  reponseInvalide,
  localisationInvalide;

  /// La situation qui correspond à un échec, **selon sa nature**.
  ///
  /// C'est le seul pont entre une panne et une situation, et il ne mène jamais à
  /// [aucuneCuisine] : seul un annuaire qui a répondu vide y conduit.
  static SituationCuisine depuisEchec(eccore.ApiFailure nature) => switch (nature) {
    eccore.ApiFailure.network => SituationCuisine.erreurReseau,
    eccore.ApiFailure.authentication => SituationCuisine.erreurAuthentification,
    eccore.ApiFailure.authorization => SituationCuisine.erreurAutorisation,
    eccore.ApiFailure.server => SituationCuisine.erreurServeur,
    eccore.ApiFailure.invalidResponse => SituationCuisine.reponseInvalide,
    eccore.ApiFailure.notFound ||
    eccore.ApiFailure.throttled ||
    eccore.ApiFailure.rejected ||
    eccore.ApiFailure.unknown => SituationCuisine.erreurApi,
  };

  /// La situation d'une cuisine connue, d'après le motif du serveur.
  static SituationCuisine depuisMotif(String code) => switch (code) {
    '' => SituationCuisine.commandable,
    eccore.MotifIndisponibilite.cuisineFermee ||
    eccore.MotifIndisponibilite.cuisineFermeeExceptionnellement => SituationCuisine.fermee,
    eccore.MotifIndisponibilite.cuisineEnPause => SituationCuisine.enPause,
    eccore.MotifIndisponibilite.cuisineSuspendue => SituationCuisine.suspendue,
    _ => SituationCuisine.indisponible,
  };

  /// Une panne : réessayer peut suffire.
  bool get estUnePanne => switch (this) {
    SituationCuisine.erreurReseau ||
    SituationCuisine.erreurServeur ||
    SituationCuisine.reponseInvalide ||
    SituationCuisine.erreurApi => true,
    _ => false,
  };

  /// Code stable pour les journaux — le vocabulaire demandé aux deux rives.
  String get code => switch (this) {
    SituationCuisine.chargement => 'LOADING',
    SituationCuisine.commandable => 'KITCHEN_AVAILABLE',
    SituationCuisine.fermee => 'KITCHEN_CLOSED',
    SituationCuisine.enPause => 'KITCHEN_PAUSED',
    SituationCuisine.suspendue => 'KITCHEN_SUSPENDED',
    SituationCuisine.indisponible => 'KITCHEN_UNAVAILABLE',
    SituationCuisine.aucuneCuisine => 'NO_KITCHEN_AVAILABLE',
    SituationCuisine.adresseNonDesservie => 'ADDRESS_NOT_SERVED',
    SituationCuisine.erreurReseau => 'NETWORK_ERROR',
    SituationCuisine.erreurAuthentification => 'AUTHENTICATION_ERROR',
    SituationCuisine.erreurAutorisation => 'AUTHORIZATION_ERROR',
    SituationCuisine.erreurServeur => 'SERVER_ERROR',
    SituationCuisine.erreurApi => 'API_ERROR',
    SituationCuisine.reponseInvalide => 'INVALID_RESPONSE',
    SituationCuisine.localisationInvalide => 'INVALID_LOCATION',
  };
}

/// **Quelle cuisine livre ce client.**
///
/// ## Ce que ce service remplace
///
/// L'application portait six constantes dans `AppConstants` — le slug de
/// l'établissement, sa latitude, sa longitude, le slug de sa ville, le nom de
/// cette ville et le code de son pays — recopiées à travers une trentaine
/// d'appels. Chacune était juste pour une seule cuisine et fausse pour toutes
/// les autres. Il s'est ensuite appelé `RestaurantContextService`, du temps où
/// le produit se pensait comme un restaurant ; El Corazón est une plateforme
/// de cuisines de livraison, et c'est la cuisine qui décide de la carte, des
/// prix, des frais et du panier.
///
/// ## Les trois défauts corrigés en le renommant
///
/// * **Une course au démarrage.** `resolve()` rendait la main *sans attendre*
///   quand une résolution était déjà en cours. Le catalogue, lancé en parallèle
///   de la résolution de démarrage, recevait un slug nul — et l'exception disait
///   « Aucun restaurant n'est en service », alors que l'annuaire n'avait pas
///   encore répondu. La résolution est désormais **à vol unique** : tous les
///   appelants attendent la même lecture.
/// * **Une panne lue comme une absence.** Seules les `ApiException` étaient
///   rattrapées, et leur nature perdue. Un 500 de l'annuaire (le 2026-09-13,
///   une migration non appliquée), une réponse illisible, un serveur éteint
///   finissaient tous en « aucun restaurant ». [etat] et [echec] les distinguent,
///   et seul un annuaire qui a **répondu vide** donne [EtatDuContexte.aucuneCuisine].
/// * **Une cuisine sans rapport avec l'adresse.** Sans choix explicite, la
///   première de l'annuaire — l'ordre alphabétique — était retenue, qu'elle
///   livre le client ou non. Quand l'adresse de livraison est connue
///   ([suivreLAdresse]), la cuisine est celle que la géographie désigne : la
///   plus proche qui dessert l'adresse **et peut commander**, choisie par le
///   serveur.
///
/// ## Ce qu'il n'est pas
///
/// Une couche de sécurité. Le serveur rejuge tout à la création de commande
/// (`AvailabilityService.can_accept_order`) : ce service dit **quoi demander**,
/// et ce qu'il affiche, jamais ce qui est permis.
///
/// ## Pourquoi il notifie
///
/// Changer de cuisine change le catalogue, les prix, les frais et le panier.
/// Les caches qui s'y abonnent ([ecouterLeChangement]) doivent se vider :
/// afficher les plats de Lomé sous le nom d'Abidjan serait pire qu'une liste
/// vide, parce que rien ne le signalerait.
class KitchenContextService extends ChangeNotifier {
  static final KitchenContextService _instance = KitchenContextService._();

  factory KitchenContextService() => _instance;

  KitchenContextService._();

  /// Instance isolée, alimentée par des lectures données. Réservée aux tests.
  @visibleForTesting
  KitchenContextService.avecLecture(
    LectureDesCuisines lecture, {
    VerificationDeLivraison? verification,
    SharedPreferences? preferences,
  }) : _lecture = lecture,
       _verification = verification,
       _prefs = preferences;

  LectureDesCuisines? _lecture;
  VerificationDeLivraison? _verification;
  SharedPreferences? _prefs;

  LectureDesCuisines get _lireLAnnuaire =>
      _lecture ?? eccore.RestaurantDirectoryRepository(apiClient: apiClient).list;

  VerificationDeLivraison get _verifierLaLivraison =>
      _verification ?? eccore.DeliveryCheckRepository(apiClient: apiClient).check;

  /// Clé du choix explicite, conservée d'une session à l'autre.
  ///
  /// Son nom date de l'ancien service et **ne change pas** : les appareils
  /// installés y ont mémorisé la cuisine de leur client, et la renommer lui
  /// ferait perdre son choix — et, en apparence, son panier.
  static const String _cleDuChoix = 'restaurant_context_slug';

  List<eccore.Restaurant> _cuisines = const [];

  /// Choisie par le client, et mémorisée. Prime sur tout le reste.
  String? _slugChoisi;

  /// Désignée par la géographie pour l'adresse de livraison. Non mémorisée :
  /// elle se recalcule quand l'adresse change.
  String? _slugDeLAdresse;

  EtatDuContexte _etat = EtatDuContexte.initial;
  eccore.ApiFailure? _echec;
  String? _detailEchec;
  bool _resolu = false;

  PointDeLivraison? _point;
  DesserteAdresse _desserte = DesserteAdresse.inconnue;
  String? _motifDesserte;

  // ------------------------------------------------ ce que les écrans lisent

  /// Cuisines en service, dans l'ordre rendu par le serveur.
  List<eccore.Restaurant> get cuisines => List.unmodifiable(_cuisines);

  /// Cuisine courante : celle qu'on a choisie, sinon celle qui livre l'adresse,
  /// sinon la première de l'annuaire.
  ///
  /// Rendre la première plutôt que rien reste un raccourci assumé tant que
  /// l'adresse est inconnue : l'enseigne n'a souvent qu'une cuisine par ville,
  /// et obliger à choisir pour n'avoir qu'une option serait une étape vide.
  eccore.Restaurant? get current {
    if (_cuisines.isEmpty) return null;
    return _trouver(_slugChoisi) ?? _trouver(_slugDeLAdresse) ?? _cuisines.first;
  }

  /// La cuisine de l'annuaire qui porte ce slug, ou `null`.
  eccore.Restaurant? cuisineParSlug(String? slug) => _trouver(slug);

  eccore.Restaurant? _trouver(String? slug) {
    if (slug == null) return null;
    for (final cuisine in _cuisines) {
      if (cuisine.slug == slug) return cuisine;
    }
    return null;
  }

  /// Plusieurs cuisines : condition d'affichage d'un sélecteur.
  bool get hasChoice => _cuisines.length > 1;

  EtatDuContexte get etat => _etat;
  bool get isLoading => _etat == EtatDuContexte.chargement;
  bool get isResolved => _resolu;

  /// Nature du dernier échec de lecture, nulle s'il n'y en a pas eu.
  eccore.ApiFailure? get echec => _echec;

  /// Ce que l'échec a dit, pour le journal et l'écran. Nul sans échec.
  String? get error => _detailEchec;

  DesserteAdresse get desserte => _desserte;

  /// La phrase du serveur quand l'adresse n'est pas desservie.
  String? get motifDesserte => _motifDesserte;

  /// **La** situation, composée une fois pour tous les écrans.
  ///
  /// L'ordre est celui de ce que le client peut faire : une panne sans cuisine
  /// connue d'abord (rien ne s'affiche), puis l'absence de cuisine, puis
  /// l'adresse, puis l'état de la cuisine elle-même.
  SituationCuisine get situation {
    final cuisine = current;

    if (cuisine == null) {
      return switch (_etat) {
        EtatDuContexte.initial || EtatDuContexte.chargement => SituationCuisine.chargement,
        EtatDuContexte.aucuneCuisine || EtatDuContexte.pret => SituationCuisine.aucuneCuisine,
        EtatDuContexte.localisationInvalide => SituationCuisine.localisationInvalide,
        EtatDuContexte.echec => SituationCuisine.depuisEchec(
          _echec ?? eccore.ApiFailure.unknown,
        ),
      };
    }

    if (_desserte == DesserteAdresse.aucuneCuisine) return SituationCuisine.aucuneCuisine;
    if (_desserte == DesserteAdresse.nonDesservie) return SituationCuisine.adresseNonDesservie;
    return SituationCuisine.depuisMotif(cuisine.canOrderNow ? '' : cuisine.unavailableCode);
  }

  /// Slug de la cuisine courante, ou `null` tant que rien n'est résolu.
  ///
  /// **Nul plutôt qu'une valeur de repli** : un appelant qui écrit ne doit pas
  /// deviner à la place du serveur.
  String? get slug => current?.slug;

  double? get latitude => current?.latitude;
  double? get longitude => current?.longitude;
  String? get cityName => current?.cityName;
  String? get citySlug => current?.citySlug;

  /// Code pays ISO en **minuscules**, tel que l'attend `components=country:xx`
  /// de Google Places.
  String? get countryCode {
    final code = current?.countryIsoCode;
    return (code == null || code.isEmpty) ? null : code.toLowerCase();
  }

  String? get phonePrefix => current?.phonePrefix;
  String? get currency => current?.currency;
  String? get name => current?.name;

  // ----------------------------------------------------------- résolution

  Future<void>? _resolutionEnCours;

  /// Charge l'annuaire. Un second appel ne refait rien, sauf [force].
  ///
  /// **À vol unique** : pendant une résolution, tout appel attend la même —
  /// c'était la course qui faisait conclure « aucun restaurant » au catalogue
  /// lancé en même temps. Un appel forcé pendant qu'une lecture est en vol
  /// s'enchaîne après elle au lieu d'être perdu : un tri par proximité demandé
  /// pendant le démarrage doit bien avoir lieu.
  Future<void> resolve({bool force = false, double? latitude, double? longitude}) {
    final enCours = _resolutionEnCours;
    if (enCours != null) {
      if (!force) return enCours;
      return _lancer(() async {
        await enCours;
        await _resoudre(latitude: latitude, longitude: longitude);
      });
    }
    if (_resolu && !force) return Future<void>.value();
    return _lancer(() => _resoudre(latitude: latitude, longitude: longitude));
  }

  Future<void> _lancer(Future<void> Function() travail) {
    late final Future<void> vol;
    vol = travail().whenComplete(() {
      if (identical(_resolutionEnCours, vol)) _resolutionEnCours = null;
    });
    _resolutionEnCours = vol;
    return vol;
  }

  Future<void> _resoudre({double? latitude, double? longitude}) async {
    _etat = EtatDuContexte.chargement;
    notifyListeners();

    final ancien = slug;
    try {
      _cuisines = await _lireLAnnuaire(latitude: latitude, longitude: longitude);
      _resolu = true;
      _echec = null;
      _detailEchec = null;
      _etat = _cuisines.isEmpty ? EtatDuContexte.aucuneCuisine : EtatDuContexte.pret;
      await _restaurerLeChoix();

      eccore.Journal.trace(
        'KitchenContext : GET /restaurants/ → ${_cuisines.length} cuisine(s) '
        '[${_cuisines.map((c) => c.slug).join(', ')}], courante = ${slug ?? 'aucune'}',
      );

      final point = _point;
      if (point != null && _cuisines.isNotEmpty) await _ajusterALAdresse(point);
    } on Exception catch (e) {
      _surEchec(e, avecPosition: latitude != null);
    } on TypeError catch (e) {
      // Un champ absent ou d'un autre type dans la réponse : `Restaurant.fromJson`
      // lève une `TypeError`. Le serveur a répondu autre chose que le contrat.
      _surEchec(e, avecPosition: latitude != null);
    } finally {
      notifyListeners();
    }

    // La cuisine courante a pu changer sans qu'on l'ait choisie : celle qu'on
    // parcourait a été suspendue, ou l'adresse désigne désormais une autre.
    if (ancien != null && ancien != slug) _signalerLeChangement(ancien);
  }

  /// Consigne un échec **sans jamais le traduire en absence de cuisine**.
  ///
  /// L'annuaire connu, s'il y en avait un, est conservé : une actualisation qui
  /// échoue ne fait pas disparaître la cuisine qu'on parcourait. [_resolu] ne
  /// passe pas à vrai sur un premier échec, si bien que la prochaine demande
  /// de slug relit l'annuaire — c'est ce qui rend « Réessayer » opérant.
  void _surEchec(Object erreur, {required bool avecPosition}) {
    final nature = eccore.ApiFailure.of(erreur);
    final statut = erreur is eccore.ApiException ? erreur.status : null;

    _echec = nature;
    _detailEchec = erreur is eccore.ApiException
        ? erreur.detail
        : eccore.messageErreurApi(erreur);
    _etat = avecPosition && statut == 400
        ? EtatDuContexte.localisationInvalide
        : EtatDuContexte.echec;

    eccore.Journal.trace(
      'KitchenContext : annuaire illisible — ${nature.code} '
      '(GET /restaurants/, HTTP ${statut ?? '—'}) : $_detailEchec. '
      '${_cuisines.isEmpty ? 'Aucune cuisine connue.' : 'Cuisine connue conservée : $slug.'}',
    );
  }

  /// Villes desservies, dans l'ordre d'apparition de l'annuaire.
  ///
  /// Dérivées de l'annuaire plutôt que lues sur `/geography/cities/` — cette
  /// route rend les villes *où l'enseigne pourrait ouvrir*, pas celles où une
  /// cuisine livre réellement, et proposer une ville sans cuisine serait une
  /// impasse.
  List<String> get villesDesservies {
    final vues = <String>{};
    final ordonnees = <String>[];
    for (final cuisine in _cuisines) {
      if (cuisine.cityName.isNotEmpty && vues.add(cuisine.cityName)) {
        ordonnees.add(cuisine.cityName);
      }
    }
    return List.unmodifiable(ordonnees);
  }

  /// Cuisines d'une ville donnée.
  List<eccore.Restaurant> cuisinesDe(String cityName) =>
      List.unmodifiable(_cuisines.where((cuisine) => cuisine.cityName == cityName));

  /// Recharge l'annuaire en le faisant trier par proximité côté serveur.
  ///
  /// **Ne change pas le choix explicite du client** : le tri est une aide à la
  /// découverte, pas une décision prise à sa place.
  Future<void> trierParProximite({
    required double latitude,
    required double longitude,
  }) => resolve(force: true, latitude: latitude, longitude: longitude);

  /// Slug à écrire, en résolvant l'annuaire si ce n'est pas déjà fait.
  Future<String?> requireSlug() async {
    if (!_resolu) await resolve();
    return slug;
  }

  /// Slug de la cuisine courante, ou une exception qui dit **la vraie cause**.
  ///
  /// C'est la forme qu'appellent le catalogue, le panier, la commande et les
  /// frais. L'exception porte la [situation] : « aucune cuisine » seulement si
  /// l'annuaire a répondu vide, la nature de la panne sinon.
  Future<String> exigerSlug() async {
    final courant = await requireSlug();
    if (courant != null) return courant;
    throw CuisineIndisponible(situation, detail: _detailEchec);
  }

  /// Quelle cuisine desservirait ce point — **sans rien changer**.
  ///
  /// Une question, pas un geste : ni le choix courant, ni la desserte
  /// mémorisée, ni le panier n'en sont affectés. C'est ce qui permet à la
  /// caisse de demander « votre panier ne suivra pas, on y va ? » **avant**
  /// d'appliquer un changement d'adresse, au lieu de l'annoncer après coup.
  ///
  /// Rend `null` quand aucune cuisine ne dessert le point, quand la
  /// vérification échoue, ou quand la cuisine désignée n'est pas dans
  /// l'annuaire — dans les trois cas, il n'y a rien à confirmer.
  Future<String?> cuisineQuiDesservirait({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final reponse = await _verifierLaLivraison(
        latitude: latitude,
        longitude: longitude,
      );
      final designee = reponse.restaurant?.slug;
      return designee != null && _trouver(designee) != null ? designee : null;
    } on Exception catch (e) {
      eccore.Journal.trace('KitchenContext : desserte non vérifiée — $e');
      return null;
    }
  }

  /// Choisit la cuisine courante — un choix **explicite**, mémorisé.
  ///
  /// Un slug absent de l'annuaire est ignoré : le sélecteur n'est pas une porte
  /// d'entrée vers une cuisine que le serveur ne sert pas.
  Future<void> select(String slug) async {
    if (_trouver(slug) == null) return;
    final ancien = this.slug;
    if (_slugChoisi == slug) return;

    _slugChoisi = slug;
    await _memoriserLeChoix(slug);

    final point = _point;
    if (point != null) await _ajusterALAdresse(point);

    if (ancien != null && ancien != slug) _signalerLeChangement(ancien);
    notifyListeners();
  }

  // ------------------------------------------------------------- l'adresse

  /// Suit l'adresse de livraison du client.
  ///
  /// Sans choix explicite, la cuisine devient celle que la géographie désigne
  /// pour ce point. Avec un choix explicite, il est **gardé**, et [desserte] dit
  /// si cette cuisine-là livre l'adresse — la décision appartient au client.
  Future<void> suivreLAdresse({required double latitude, required double longitude}) async {
    final point = (latitude: latitude, longitude: longitude);
    if (_point == point && _desserte != DesserteAdresse.verificationImpossible) return;
    _point = point;

    if (!_resolu) {
      // L'annuaire n'a pas encore répondu : la résolution en cours ajustera.
      await resolve();
      return;
    }
    if (_cuisines.isEmpty) return;

    final ancien = slug;
    await _ajusterALAdresse(point);
    if (ancien != null && ancien != slug) _signalerLeChangement(ancien);
    notifyListeners();
  }

  /// Écoute un carnet d'adresses, et suit celle qu'il retient.
  ///
  /// Générique — un `Listenable` et une lecture — pour ne pas lier ce service
  /// au carnet : les tests le montent sans lui. Rend la fonction de désabonnement.
  VoidCallback suivreLeCarnet(Listenable carnet, PointDeLivraison? Function() adresseRetenue) {
    void surChangement() {
      final point = adresseRetenue();
      if (point != null) {
        unawaited(suivreLAdresse(latitude: point.latitude, longitude: point.longitude));
      }
    }

    carnet.addListener(surChangement);
    surChangement();
    return () => carnet.removeListener(surChangement);
  }

  Future<void> _ajusterALAdresse(PointDeLivraison point) async {
    try {
      if (_slugChoisi != null) {
        final reponse = await _verifierLaLivraison(
          latitude: point.latitude,
          longitude: point.longitude,
          restaurantSlug: _slugChoisi,
        );
        _noterLaDesserte(reponse, cuisineVisee: _slugChoisi);
        return;
      }

      // Sans cuisine imposée, le serveur choisit : la plus proche qui dessert
      // l'adresse et peut commander, à défaut la plus proche qui la dessert.
      final reponse = await _verifierLaLivraison(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      final designee = reponse.restaurant?.slug;
      _slugDeLAdresse = (designee != null && _trouver(designee) != null) ? designee : null;
      _noterLaDesserte(reponse, cuisineVisee: designee);
    } on Exception catch (e) {
      _noterUnEchecDeDesserte(e);
    } on TypeError catch (e) {
      _noterUnEchecDeDesserte(e);
    }
  }

  void _noterLaDesserte(eccore.DeliveryAvailability reponse, {String? cuisineVisee}) {
    if (reponse.isAvailable) {
      _desserte = DesserteAdresse.desservie;
      _motifDesserte = null;
    } else if (reponse.unavailableCode == eccore.MotifIndisponibilite.aucuneCuisine ||
        reponse.restaurant == null) {
      _desserte = DesserteAdresse.aucuneCuisine;
      _motifDesserte = reponse.reason;
    } else if (reponse.unavailableCode == eccore.MotifIndisponibilite.adresseNonDesservie ||
        reponse.unavailableCode == null) {
      _desserte = DesserteAdresse.nonDesservie;
      _motifDesserte = reponse.reason;
    } else {
      // Un refus de panier (minimum de commande) : l'adresse est desservie, la
      // commande se corrige au panier.
      _desserte = DesserteAdresse.desservie;
      _motifDesserte = null;
    }

    eccore.Journal.trace(
      'KitchenContext : POST /restaurants/delivery-check/ → ${_desserte.name} '
      '(cuisine ${cuisineVisee ?? 'aucune'}, motif ${reponse.unavailableCode ?? '—'}), '
      'courante = ${slug ?? 'aucune'}',
    );
  }

  void _noterUnEchecDeDesserte(Object erreur) {
    // Une vérification qui échoue ne dit **rien** de l'adresse : ni desservie,
    // ni hors zone. La cuisine courante reste celle qu'on avait.
    final nature = eccore.ApiFailure.of(erreur);
    _desserte = DesserteAdresse.verificationImpossible;
    _motifDesserte = null;
    eccore.Journal.trace(
      'KitchenContext : desserte non vérifiée — ${nature.code} '
      '(POST /restaurants/delivery-check/, HTTP '
      '${erreur is eccore.ApiException ? erreur.status : '—'})',
    );
  }

  // ---------------------------------------------- réaction au changement

  final List<void Function(String ancien, String nouveau)> _abonnes = [];

  /// S'abonne au changement de cuisine.
  ///
  /// Distinct de [addListener], qui se déclenche aussi pour un simple
  /// chargement : ce rappel ne part que lorsque **la cuisine change vraiment**,
  /// et c'est la seule occasion où un cache doit se vider.
  ///
  /// Rend la fonction de désabonnement.
  VoidCallback ecouterLeChangement(void Function(String ancien, String nouveau) rappel) {
    _abonnes.add(rappel);
    return () => _abonnes.remove(rappel);
  }

  void _signalerLeChangement(String ancien) {
    final nouveau = slug;
    if (nouveau == null || nouveau == ancien) return;
    eccore.Journal.trace('KitchenContext : cuisine $ancien → $nouveau');
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
    if (_slugChoisi != null) {
      // Le choix a pu disparaître de l'annuaire (cuisine suspendue) : on ne le
      // garde que s'il est encore servi.
      if (_trouver(_slugChoisi) == null) _slugChoisi = null;
      return;
    }
    try {
      final memorise = (await _preferences).getString(_cleDuChoix);
      if (memorise == null) return;
      if (_trouver(memorise) != null) _slugChoisi = memorise;
    } on Exception catch (e) {
      eccore.Journal.trace('KitchenContext : choix non restauré — $e');
    }
  }

  Future<void> _memoriserLeChoix(String slug) async {
    try {
      await (await _preferences).setString(_cleDuChoix, slug);
    } on Exception catch (e) {
      eccore.Journal.trace('KitchenContext : choix non mémorisé — $e');
    }
  }

  /// Oublie tout — à la déconnexion, et dans les tests.
  ///
  /// Appelé par `AppService` quand la session se ferme (`_oublierLeCompte`).
  /// L'annotation `@visibleForTesting` qui se trouvait ici disait le contraire
  /// de la première ligne de cette documentation : la méthode décrivait un
  /// geste de production que personne ne faisait.
  void reset() {
    _cuisines = const [];
    _slugChoisi = null;
    _slugDeLAdresse = null;
    _resolu = false;
    _etat = EtatDuContexte.initial;
    _echec = null;
    _detailEchec = null;
    _point = null;
    _desserte = DesserteAdresse.inconnue;
    _motifDesserte = null;
    notifyListeners();
  }
}

/// Aucune cuisine ne peut servir la demande — **et pourquoi**.
///
/// Remplace `AucunEtablissement`, qui ne connaissait que deux phrases :
/// « aucun restaurant n'est en service », ou « la liste n'a pas pu être
/// chargée ». La première sortait aussi quand l'annuaire était encore en vol,
/// ou avait échoué sans `ApiException`. [situation] porte la cause exacte.
///
/// Levée plutôt que de retomber sur une valeur par défaut : un slug inventé
/// produit une requête qui aboutit — sur la mauvaise cuisine — au lieu
/// d'échouer franchement.
class CuisineIndisponible implements Exception {
  const CuisineIndisponible(this.situation, {this.detail});

  final SituationCuisine situation;

  /// Ce que le serveur ou le transport a dit, quand il a dit quelque chose.
  final String? detail;

  @override
  String toString() => 'CuisineIndisponible(${situation.code}${detail == null ? '' : ' — $detail'})';
}
