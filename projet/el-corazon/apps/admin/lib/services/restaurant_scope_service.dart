import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Lecture du périmètre. Séparée du service pour que les tests n'aient pas à
/// monter une pile HTTP là où ils vérifient une décision.
typedef LectureDuPerimetre = Future<List<eccore.ManagedRestaurant>> Function();

/// Établissement supervisé — `GET /restaurants/manage/`.
///
/// Cinq fichiers du back-office portaient `el-corazon-lome` en constante, avec
/// chacun le même commentaire : « le jour où il y en aura plusieurs, ce champ
/// devient un sélecteur ». Ce jour-là n'avait pas besoin d'arriver pour que la
/// constante soit fausse — le serveur cloisonne déjà le personnel par
/// établissement (`_ScopedCatalogViewSet`), si bien qu'un gérant d'une autre
/// enseigne ouvrait un back-office vide : ses lectures étaient filtrées deux
/// fois, une fois par son périmètre réel et une fois par l'enseigne écrite dans
/// le code.
///
/// **Ce service ne sert pas à protéger quoi que ce soit.** Le serveur refuse de
/// lui-même une écriture hors périmètre (`assert_in_scope`). Il sert à savoir
/// quoi écrire dans le champ `restaurant` d'une création, et où centrer la
/// carte de supervision.
///
/// Il ne filtre pas les lectures : les routes d'exploitation rendent déjà le
/// périmètre du compte, et y ajouter un slug ne pourrait que le rétrécir.
class RestaurantScopeService extends ChangeNotifier {
  static final RestaurantScopeService _instance = RestaurantScopeService._();

  factory RestaurantScopeService() => _instance;

  RestaurantScopeService._() {
    // Un second compte ne doit pas hériter du périmètre du premier : sans
    // cela, une déconnexion suivie d'une connexion depuis un autre poste
    // laisserait le slug de la session précédente dans les créations.
    AdminAuthService().addListener(_surChangementDeSession);
    // Une session restaurée est déjà ouverte quand ce service naît : le
    // signal est passé avant qu'on écoute.
    _surChangementDeSession();
  }

  /// Instance isolée, alimentée par une lecture donnée. Réservée aux tests :
  /// la version partagée lit le serveur et observe la session.
  @visibleForTesting
  RestaurantScopeService.avecLecture(LectureDuPerimetre lecture) : _lecture = lecture;

  LectureDuPerimetre? _lecture;

  LectureDuPerimetre get _lireLePerimetre =>
      _lecture ??
      eccore.ManagedRestaurantRepository(apiClient: AdminAuthService().apiClient).list;

  List<eccore.ManagedRestaurant> _etablissements = const [];
  String? _slugChoisi;
  bool _isLoading = false;
  bool _resolu = false;
  String? _error;

  /// Établissements que le compte supervise, dans l'ordre rendu par le serveur.
  List<eccore.ManagedRestaurant> get restaurants => List.unmodifiable(_etablissements);

  /// Établissement courant : celui qu'on a choisi, ou le premier du périmètre.
  ///
  /// Rendre le premier plutôt que rien n'est un raccourci assumé : un compte
  /// n'en supervise qu'un dans l'immense majorité des cas, et l'obliger à
  /// choisir pour n'avoir qu'une option serait une étape vide.
  eccore.ManagedRestaurant? get current {
    if (_etablissements.isEmpty) return null;
    final choisi = _slugChoisi;
    if (choisi == null) return _etablissements.first;
    return _etablissements.firstWhere(
      (etablissement) => etablissement.slug == choisi,
      orElse: () => _etablissements.first,
    );
  }

  /// Slug à écrire dans une création. `null` tant que le périmètre n'est pas
  /// résolu — un appelant qui écrit ne doit pas deviner à sa place.
  String? get slug => current?.slug;

  /// Le compte supervise-t-il plusieurs établissements ? C'est la condition
  /// d'affichage d'un sélecteur ; en dessous, il n'y a rien à choisir.
  bool get hasChoice => _etablissements.length > 1;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Ce qu'affiche un écran qui voulait écrire sans périmètre connu.
  ///
  /// Il dit ce qui manque plutôt que « une erreur est survenue » : le cas
  /// n'arrive qu'à un compte du personnel rattaché à aucun établissement, ou
  /// privé de `restaurants.read`, et c'est un réglage de rôle — pas une panne
  /// que réessayer corrigerait.
  static const String sansPerimetre =
      "Aucun établissement supervisé : ce compte n'est rattaché à aucun "
      'établissement, ou ne peut pas les lire. Voyez ses rôles.';

  /// Charge le périmètre une fois. Un second appel ne refait rien, sauf
  /// [force] — la composition d'un périmètre change côté serveur, pas ici.
  Future<void> resolve({bool force = false}) async {
    if (_isLoading) return;
    if (_resolu && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _etablissements = await _lireLePerimetre();
      _resolu = true;
      eccore.Journal.trace(
        'RestaurantScopeService: ${_etablissements.length} établissement(s) supervisé(s)',
      );
    } on eccore.ApiException catch (e) {
      _etablissements = const [];
      // 403 sans `restaurants.read` : un rôle qui lit sans jamais écrire, tel
      // « Opérateur », n'a aucune raison de connaître la fiche de son
      // établissement. Ce n'est pas une panne, et l'écran n'a pas à l'annoncer
      // comme telle — ses lectures marchent, le serveur les cloisonne.
      _error = e.status == 403 ? null : e.detail;
      eccore.Journal.trace('RestaurantScopeService: périmètre illisible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Slug à écrire, en résolvant le périmètre si ce n'est pas déjà fait.
  ///
  /// Rend `null` quand le compte n'a pas de quoi le lire : l'appelant doit
  /// alors refuser l'écriture plutôt que de la tenter sur un établissement
  /// inventé. Le serveur la refuserait, mais bien plus tard et sans dire
  /// pourquoi.
  Future<String?> requireSlug() async {
    if (!_resolu) await resolve();
    return slug;
  }

  /// Choisit l'établissement courant parmi ceux du périmètre.
  ///
  /// Un slug hors périmètre est ignoré : le sélecteur n'est pas une porte
  /// d'entrée vers l'établissement d'un autre.
  void select(String slug) {
    if (!_etablissements.any((etablissement) => etablissement.slug == slug)) return;
    if (_slugChoisi == slug) return;
    _slugChoisi = slug;
    notifyListeners();
  }

  void _surChangementDeSession() {
    if (AdminAuthService().isAuthenticated) {
      if (!_resolu && !_isLoading) unawaited(resolve());
    } else {
      reset();
    }
  }

  /// Oublie le périmètre — à la déconnexion.
  void reset() {
    if (!_resolu && _etablissements.isEmpty && _slugChoisi == null) return;
    _etablissements = const [];
    _slugChoisi = null;
    _resolu = false;
    _error = null;
    notifyListeners();
  }
}
