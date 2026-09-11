import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Le réseau : pays, villes, établissements — et leur provisionnement.
///
/// ## Ce que ce service comble
///
/// L'architecture multi-pays existait **entière** côté serveur depuis
/// l'ADR-006 : `Country → City → DeliveryZone → Restaurant`, avec les routes
/// d'administration correspondantes (`/geography/manage/*`,
/// `/restaurants/manage/`). Le back-office n'en appelait qu'une : la lecture
/// des zones. Ouvrir un marché, une ville ou un établissement passait donc par
/// `django-admin`. Ce n'était pas un défaut d'architecture mais un défaut
/// d'interface — et c'est lui qui rendait fausse, en pratique, la promesse
/// d'ajouter un restaurant sans toucher au code.
///
/// ## Ce qu'il n'est pas
///
/// Ce n'est **pas** une couche de sécurité. Le serveur réserve déjà l'ouverture
/// d'un pays, d'une ville, d'une zone et d'un établissement aux comptes non
/// cloisonnés (`assert_unscoped`) : un gérant qui tenterait la requête reçoit
/// un 403, que ce service traduit en une phrase lisible au lieu de le masquer.
///
/// Ce n'est pas non plus un second modèle d'établissement. Le périmètre du
/// compte connecté reste tenu par [RestaurantScopeService] ; ce service-ci voit
/// la même liste sous l'angle du siège qui provisionne, et lui demande de se
/// rafraîchir dès qu'un établissement apparaît — sans quoi le nouveau
/// restaurant resterait absent du sélecteur, et les écrans de catalogue,
/// d'horaires et de livreurs continueraient d'écrire sur le précédent.
class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._();

  factory NetworkService() => _instance;

  NetworkService._()
      : _geographieInjectee = null,
        _etablissementsInjectes = null,
        _referenceInjectee = null,
        _perimetreInjecte = null;

  /// Instance isolée, alimentée par des dépôts donnés. Réservée aux tests :
  /// la version partagée lit le serveur et pousse le périmètre.
  @visibleForTesting
  NetworkService.avecDepots({
    required eccore.ManagedGeographyRepository geographie,
    required eccore.ManagedRestaurantRepository etablissements,
    eccore.GeographyReferenceRepository? reference,
    RestaurantScopeService? perimetre,
  }) : _geographieInjectee = geographie,
       _etablissementsInjectes = etablissements,
       _referenceInjectee = reference,
       _perimetreInjecte = perimetre;

  final eccore.ManagedGeographyRepository? _geographieInjectee;
  final eccore.ManagedRestaurantRepository? _etablissementsInjectes;
  final eccore.GeographyReferenceRepository? _referenceInjectee;
  final RestaurantScopeService? _perimetreInjecte;

  eccore.ManagedGeographyRepository get _geographie =>
      _geographieInjectee ??
      eccore.ManagedGeographyRepository(apiClient: AdminAuthService().apiClient);

  eccore.ManagedRestaurantRepository get _depotEtablissements =>
      _etablissementsInjectes ??
      eccore.ManagedRestaurantRepository(apiClient: AdminAuthService().apiClient);

  eccore.GeographyReferenceRepository get _depotReference =>
      _referenceInjectee ??
      eccore.GeographyReferenceRepository(apiClient: AdminAuthService().apiClient);

  /// Le périmètre à rafraîchir après une écriture. Nul en test isolé, où il n'y
  /// a pas de session à observer.
  RestaurantScopeService? get _perimetre =>
      _perimetreInjecte ??
      (_etablissementsInjectes == null ? RestaurantScopeService() : null);

  eccore.GeographyReference _reference = eccore.GeographyReference.vide;
  List<eccore.ManagedCountry> _pays = const [];
  List<eccore.ManagedCity> _villes = const [];
  List<eccore.ManagedRestaurant> _etablissements = const [];

  bool _isLoading = false;
  bool _resolu = false;
  String? _error;

  /// Pays, **fermés compris** : c'est de cet écran qu'on rouvre un marché, et
  /// masquer les fermés rendrait le geste impossible depuis l'écran même qui
  /// sert à le faire — le raisonnement que tiennent déjà les zones et les
  /// catégories.
  /// Devises et fuseaux que le serveur accepte.
  ///
  /// Le formulaire d'ouverture de marché portait **dix fuseaux écrits en dur**
  /// et une liste de devises à côté. Ouvrir un marché hors de ces dix demandait
  /// de republier l'application, et une devise proposée mais non acceptée
  /// produisait un 400 après la saisie de tout le formulaire.
  ///
  /// Vide tant que [chargerLaReference] n'a pas répondu : l'écran ne propose
  /// alors rien plutôt qu'une valeur inventée.
  eccore.GeographyReference get reference => _reference;

  List<eccore.ManagedCountry> get countries => List.unmodifiable(_pays);
  List<eccore.ManagedCity> get cities => List.unmodifiable(_villes);
  List<eccore.ManagedRestaurant> get restaurants => List.unmodifiable(_etablissements);

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isResolved => _resolu;

  /// Ce qu'affiche un écran ouvert par un compte cloisonné.
  static const String reserveAuSiege =
      'Le réseau relève du siège : ouvrir un pays, une ville ou un '
      'établissement demande un compte non rattaché à un périmètre. Le vôtre '
      "l'est, et ne voit donc que ses propres établissements.";

  /// Villes d'un pays, par son code ISO.
  List<eccore.ManagedCity> citiesOf(String isoCode) => _villes
      .where((ville) => ville.countryIsoCode.toUpperCase() == isoCode.toUpperCase())
      .toList(growable: false);

  /// Établissements d'une ville, par son slug.
  List<eccore.ManagedRestaurant> restaurantsOf(String citySlug) => _etablissements
      .where((etablissement) => etablissement.citySlug == citySlug)
      .toList(growable: false);

  eccore.ManagedCountry? countryByIso(String isoCode) {
    for (final pays in _pays) {
      if (pays.isoCode.toUpperCase() == isoCode.toUpperCase()) return pays;
    }
    return null;
  }

  eccore.ManagedCity? cityById(String id) {
    for (final ville in _villes) {
      if (ville.id == id) return ville;
    }
    return null;
  }

  eccore.ManagedRestaurant? restaurantBySlug(String slug) {
    for (final etablissement in _etablissements) {
      if (etablissement.slug == slug) return etablissement;
    }
    return null;
  }

  /// Charge le réseau une fois. Un second appel ne refait rien, sauf [force].
  Future<void> resolve({bool force = false}) async {
    if (_isLoading) return;
    if (_resolu && !force) return;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Les trois lectures partent ensemble : elles ne dépendent pas les unes
      // des autres, et les enchaîner triplerait l'attente avant le premier
      // affichage d'un écran qui les montre côte à côte.
      final pays = _geographie.countries();
      final villes = _geographie.cities();
      final etablissements = _depotEtablissements.list();

      _pays = (await pays).toList()..sort((a, b) => a.name.compareTo(b.name));
      _villes = (await villes).toList()..sort((a, b) => a.name.compareTo(b.name));
      _etablissements = (await etablissements).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _resolu = true;
    } on eccore.ApiException catch (e) {
      _error = _messageDErreur(e);
      eccore.Journal.trace('Réseau : lecture impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- écritures

  /// Ouvre un marché.
  ///
  /// La devise et le fuseau se saisissent ici, à l'ouverture, et nulle part
  /// ailleurs : la devise est figée sur chaque commande passée dans ce pays, et
  /// la corriger plus tard ne convertit rien rétroactivement.
  /// Charge devises et fuseaux, une fois par session.
  ///
  /// Appelée par le formulaire d'ouverture de marché plutôt qu'au démarrage :
  /// c'est le seul écran qui s'en sert, et six cents fuseaux n'ont pas à
  /// voyager pour quelqu'un qui vient regarder ses commandes.
  ///
  /// Un échec est **silencieux** et laisse la référence vide. Le formulaire
  /// affiche alors qu'il n'a pas pu charger les valeurs disponibles : c'est
  /// une panne de configuration, pas une raison de faire échouer l'écran
  /// entier — et proposer une liste de repli reviendrait à réintroduire
  /// exactement le hardcoding qu'on retire.
  Future<void> chargerLaReference() async {
    if (!_reference.isEmpty) return;
    try {
      _reference = await _depotReference.fetch();
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('Réseau : référence illisible — ${e.code}');
    }
  }

  Future<eccore.ManagedCountry?> createCountry({
    required String isoCode,
    required String name,
    required String currency,
    required String phonePrefix,
    required String timezone,
  }) {
    return _ecrire(
      () => _geographie.createCountry(
        isoCode: isoCode,
        name: name,
        currency: currency,
        phonePrefix: phonePrefix,
        timezone: timezone,
      ),
      apres: (pays) {
        _pays = [..._pays, pays]..sort((a, b) => a.name.compareTo(b.name));
      },
    );
  }

  /// Rouvre ou ferme un marché.
  ///
  /// Fermer un pays retire ses villes, ses zones **et ses établissements** des
  /// applications clientes, sans rien supprimer : les commandes déjà passées
  /// là-bas restent lisibles dans leur devise.
  Future<bool> setCountryActive(String isoCode, bool isActive) async {
    final maj = await _ecrire(
      () => _geographie.updateCountry(isoCode: isoCode, isActive: isActive),
      apres: (pays) {
        final index = _pays.indexWhere(
          (p) => p.isoCode.toUpperCase() == pays.isoCode.toUpperCase(),
        );
        if (index != -1) _pays = [..._pays]..[index] = pays;
      },
    );
    return maj != null;
  }

  /// Ouvre une ville dans un pays.
  ///
  /// Le pays est désigné par son code ISO, et c'est ce qui rend impossible la
  /// combinaison que redoute l'exploitation — « pays Togo, ville Abidjan » :
  /// une ville n'a qu'une clé de rattachement, celle qu'on nomme ici.
  Future<eccore.ManagedCity?> createCity({
    required String countryIsoCode,
    required String name,
    required String slug,
    required double latitude,
    required double longitude,
  }) {
    return _ecrire(
      () => _geographie.createCity(
        countryIsoCode: countryIsoCode,
        name: name,
        slug: slug,
        latitude: latitude,
        longitude: longitude,
      ),
      apres: (ville) {
        _villes = [..._villes, ville]..sort((a, b) => a.name.compareTo(b.name));
      },
    );
  }

  Future<bool> setCityActive(String cityId, bool isActive) async {
    final maj = await _ecrire(
      () => _geographie.updateCity(cityId: cityId, isActive: isActive),
      apres: (ville) {
        final index = _villes.indexWhere((v) => v.id == ville.id);
        if (index != -1) _villes = [..._villes]..[index] = ville;
      },
    );
    return maj != null;
  }

  /// Ouvre un établissement — **en brouillon**, jamais publié d'emblée.
  ///
  /// Le périmètre est rafraîchi dans la foulée, sans quoi le nouvel
  /// établissement n'apparaîtrait pas dans le sélecteur : les écrans de
  /// catalogue, d'horaires et de livreurs continueraient d'écrire sur le
  /// précédent, c'est-à-dire configureraient le mauvais restaurant.
  Future<eccore.ManagedRestaurant?> createRestaurant({
    required String name,
    required String slug,
    required String zoneId,
    required String address,
    required double latitude,
    required double longitude,
    required String phone,
    String description = '',
    String? email,
    int defaultPreparationMinutes = 20,
  }) async {
    final cree = await _ecrire(
      () => _depotEtablissements.create(
        name: name,
        slug: slug,
        zoneId: zoneId,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
        description: description,
        email: email,
        defaultPreparationMinutes: defaultPreparationMinutes,
      ),
      apres: (etablissement) {
        _etablissements = [..._etablissements, etablissement]
          ..sort((a, b) => a.name.compareTo(b.name));
      },
    );

    if (cree != null) await _perimetre?.resolve(force: true);
    return cree;
  }

  /// Ouvre un établissement en repartant d'un autre.
  ///
  /// [sections] dit ce qui est recopié — `general`, `opening_hours`,
  /// `catalog`. Commandes, clients, livreurs et historiques ne sont copiables
  /// par aucune valeur : il n'existe pas de section pour eux côté serveur.
  ///
  /// Le refus le plus courant est le 409 « devises différentes » : une carte
  /// recopiée garde ses montants sans changer d'unité, et 2 500 XOF deviendrait
  /// 2 500 NGN — un prix plausible et faux. [_messageDErreur] rend le message du
  /// serveur tel quel, parce qu'il propose déjà la sortie : dupliquer sans le
  /// catalogue.
  Future<eccore.ManagedRestaurant?> duplicateRestaurant({
    required String sourceSlug,
    required String name,
    required String slug,
    required String zoneId,
    required String address,
    required double latitude,
    required double longitude,
    required String phone,
    String? email,
    List<String> sections = const [],
  }) async {
    final copie = await _ecrire(
      () => _depotEtablissements.duplicate(
        sourceSlug: sourceSlug,
        name: name,
        slug: slug,
        zoneId: zoneId,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
        email: email,
        sections: sections,
      ),
      apres: (etablissement) {
        _etablissements = [..._etablissements, etablissement]
          ..sort((a, b) => a.name.compareTo(b.name));
      },
    );

    // Le périmètre du compte s'élargit du nouvel établissement, comme à la
    // création : sans cette relecture, la fiche existe mais aucun écran de
    // configuration ne peut basculer dessus.
    if (copie != null) await _perimetre?.resolve(force: true);
    return copie;
  }

  Future<eccore.ManagedRestaurant?> updateRestaurant({
    required String slug,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    bool? acceptsOrders,
    int? defaultPreparationMinutes,
  }) {
    return _ecrire(
      () => _depotEtablissements.update(
        slug: slug,
        name: name,
        description: description,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
        email: email,
        acceptsOrders: acceptsOrders,
        defaultPreparationMinutes: defaultPreparationMinutes,
      ),
      apres: _remplacer,
    );
  }

  /// Fait avancer un établissement dans son cycle de vie.
  ///
  /// Une mise en service sur un établissement incomplet est refusée par le
  /// serveur, qui rend la liste de ce qui manque : [error] la porte alors
  /// phrase par phrase, au lieu d'un « opération impossible » que personne ne
  /// saurait corriger.
  Future<eccore.ManagedRestaurant?> setRestaurantStatus({
    required String slug,
    required eccore.RestaurantLifecycle status,
  }) async {
    final maj = await _ecrire(
      () => _depotEtablissements.updateStatus(slug: slug, status: status),
      apres: _remplacer,
    );
    if (maj != null) await _perimetre?.resolve(force: true);
    return maj;
  }

  /// Relit un établissement pour rafraîchir sa liste de manques.
  ///
  /// `configuration_gaps` est calculée par le serveur à chaque lecture, à
  /// partir du catalogue, des horaires et de la flotte. Après une visite aux
  /// écrans qui les remplissent, la fiche en mémoire est donc périmée : la
  /// relire est ce qui fait disparaître une ligne de la liste des manques.
  Future<void> refreshRestaurant(String slug) async {
    try {
      final etablissements = await _depotEtablissements.list();
      for (final etablissement in etablissements) {
        if (etablissement.slug == slug) {
          _remplacer(etablissement);
          notifyListeners();
          return;
        }
      }
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('Réseau : relecture impossible — ${e.code}');
    }
  }

  void _remplacer(eccore.ManagedRestaurant etablissement) {
    final index = _etablissements.indexWhere((e) => e.slug == etablissement.slug);
    if (index != -1) _etablissements = [..._etablissements]..[index] = etablissement;
  }

  /// Écrit, puis range **ce que le serveur rend** — jamais la saisie.
  ///
  /// Recopier la saisie serait plus court et faux : le serveur normalise (un
  /// code ISO en majuscules), calcule (`is_active` depuis le statut,
  /// `configuration_gaps` depuis trois domaines) et peut refuser. L'écran
  /// afficherait alors une fiche que la base ne porte pas.
  Future<T?> _ecrire<T>(
    Future<T> Function() ecriture, {
    required void Function(T) apres,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resultat = await ecriture();
      apres(resultat);
      return resultat;
    } on eccore.ApiException catch (e) {
      _error = _messageDErreur(e);
      eccore.Journal.trace('Réseau : écriture refusée — ${e.code}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Traduit un refus du serveur en une phrase qui dit quoi faire.
  ///
  /// Les trois cas ne se confondent pas : un droit manquant se règle avec un
  /// autre compte, une transition refusée en choisissant une autre cible, une
  /// configuration incomplète en allant remplir ce qui manque. Un message
  /// unique renverrait les trois vers la même impasse.
  @visibleForTesting
  static String messageDErreur(eccore.ApiException e) => _messageDErreur(e);

  static String _messageDErreur(eccore.ApiException e) {
    if (e.status == 403) return reserveAuSiege;

    final manques = e.stringList('missing');
    if (manques.isNotEmpty) {
      final lignes = manques.map((phrase) => '• $phrase').join('\n');
      return 'Cet établissement ne peut pas ouvrir :\n$lignes';
    }
    return e.detail;
  }

  /// Oublie le réseau — à la déconnexion.
  void reset() {
    if (!_resolu && _pays.isEmpty && _villes.isEmpty && _etablissements.isEmpty) return;
    _pays = const [];
    _villes = const [];
    _etablissements = const [];
    _resolu = false;
    _error = null;
    notifyListeners();
  }
}
