import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Lecture du périmètre. Séparée du service pour que les tests n'aient pas à
/// monter une pile HTTP là où ils vérifient une décision.
typedef LectureDuPerimetre = Future<List<eccore.ManagedRestaurant>> Function();

/// Établissement supervisé — `GET /restaurants/manage/perimeter/`.
///
/// La lecture passait par `/restaurants/manage/`, qui exige `restaurants.read`.
/// Le rôle « Opérateur » ne l'a pas : son 403 était avalé, et le poste de
/// cuisine lui affichait « Aucun établissement rattaché ». La route du
/// périmètre répond à tout le personnel, dans son seul périmètre, et un refus
/// y est désormais dit comme un refus ([Echec]).
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
      eccore.ManagedRestaurantRepository(apiClient: AdminAuthService().apiClient).perimeter;

  List<eccore.ManagedRestaurant> _etablissements = const [];
  String? _slugChoisi;
  bool _isLoading = false;
  bool _resolu = false;
  Echec? _echec;

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

  /// Devise de l'établissement supervisé, celle dans laquelle il **facture**.
  ///
  /// Quatre services du back-office composaient leurs montants avec `'XOF'`
  /// écrit en dur, et un cinquième pour les remboursements. Ce n'était pas
  /// anodin : le serveur refuse un prix dont la devise n'est pas celle de
  /// l'établissement (`ManagedMenuItemSerializer.validate` : « Cet
  /// établissement facture en GHS ; prix reçu en XOF »). Le back-office ne
  /// pouvait donc pas créer un seul article pour un restaurant hors zone
  /// franc CFA — alors que l'écran « Réseau » permet précisément d'ouvrir un
  /// marché dans un autre pays, avec sa propre devise.
  ///
  /// Le repli sur `XOF` n'est pas un choix mais un dernier recours, pour le
  /// court instant où le périmètre n'est pas encore lu : le serveur tranchera
  /// de toute façon, et il le dira clairement.
  String get devise => current?.currency ?? 'XOF';

  /// Convertit une saisie en unité **majeure** (ce que le formulaire affiche)
  /// vers le montant que l'API attend.
  ///
  /// Passe par [eccore.Money.fromMajorUnits], qui connaît l'exposant de chaque
  /// devise. Les services faisaient `montant.round()`, ce qui n'est juste que
  /// pour une devise sans décimale : en cédi ou en naira, un prix de 12,50
  /// serait parti à 13 unités mineures — soit treize centièmes — au lieu de
  /// 1250. Le franc CFA masquait le défaut, n'ayant pas de décimale.
  eccore.Money versMoney(double montantMajeur) =>
      eccore.Money.fromMajorUnits(montantMajeur, devise);

  /// Le compte supervise-t-il plusieurs établissements ? C'est la condition
  /// d'affichage d'un sélecteur ; en dessous, il n'y a rien à choisir.
  bool get hasChoice => _etablissements.length > 1;

  bool get isLoading => _isLoading;

  /// Pourquoi le périmètre n'a pas pu être lu — `null` s'il l'a été, **même
  /// vide**. Un périmètre vide n'est pas un échec : c'est un compte que
  /// personne n'a rattaché, et c'est [sansPerimetre] qui le dit.
  Echec? get echec => _echec;

  /// La phrase de [echec], pour les écrans qui n'affichent qu'un texte.
  String? get error => _echec?.message;

  /// L'établissement du périmètre qui porte ce slug, ou `null`.
  eccore.ManagedRestaurant? parSlug(String? slug) {
    if (slug == null) return null;
    for (final etablissement in _etablissements) {
      if (etablissement.slug == slug) return etablissement;
    }
    return null;
  }

  /// L'établissement du périmètre qui porte cet identifiant, ou `null`.
  eccore.ManagedRestaurant? parId(String? id) {
    if (id == null) return null;
    for (final etablissement in _etablissements) {
      if (etablissement.id == id) return etablissement;
    }
    return null;
  }

  /// Les devises du périmètre, dans l'ordre de première apparition.
  ///
  /// Sert aux écritures **nationales** (code promotionnel, récompense sans
  /// établissement) : un montant national doit être libellé dans une devise
  /// choisie explicitement, pas dans celle de l'établissement qui se trouve
  /// sélectionné — XOF et XAF ne sont pas la même monnaie.
  List<String> get devises => <String>{
        for (final etablissement in _etablissements) etablissement.currency,
      }.toList(growable: false);

  /// Ce qu'affiche un écran qui voulait écrire sans périmètre connu.
  ///
  /// Il dit ce qui manque plutôt que « une erreur est survenue » : depuis que
  /// le périmètre se lit sans `restaurants.read`, le cas n'arrive qu'à un
  /// compte que personne n'a rattaché — un réglage, pas une panne que
  /// réessayer corrigerait. Un refus ou une panne ont leur propre [echec].
  static const String sansPerimetre =
      "Aucun établissement supervisé : ce compte n'est rattaché à aucun "
      "établissement. Un responsable du siège doit l'y rattacher.";

  /// Charge le périmètre une fois. Un second appel ne refait rien, sauf
  /// [force] — la composition d'un périmètre change côté serveur, pas ici.
  Future<void> resolve({bool force = false}) async {
    if (_isLoading) return;
    if (_resolu && !force) return;

    _isLoading = true;
    _echec = null;
    notifyListeners();

    try {
      _etablissements = await _lireLePerimetre();
      _resolu = true;
      eccore.Journal.trace(
        'RestaurantScopeService: ${_etablissements.length} établissement(s) supervisé(s)',
      );
    } on eccore.ApiException catch (e) {
      // Le 403 était avalé ici : l'écran concluait à un compte sans
      // établissement. Un refus se dit comme un refus, une panne comme une
      // panne — l'écran choisit son message sur la nature.
      _etablissements = const [];
      _echec = Echec.de(e);
      eccore.Journal.trace('RestaurantScopeService: périmètre illisible — ${e.code}');
    } on eccore.SessionExpiredException catch (e) {
      _etablissements = const [];
      _echec = Echec.de(e);
      eccore.Journal.trace('RestaurantScopeService: session expirée');
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
    _echec = null;
    notifyListeners();
  }
}
