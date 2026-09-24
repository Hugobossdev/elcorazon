import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Les quatre catalogues de fidélisation que l'écran édite.
enum CatalogueDeFidelisation {
  succes('gamification.read', 'gamification.write'),
  defis('gamification.read', 'gamification.write'),
  badges('gamification.read', 'gamification.write'),
  // Les récompenses sont un autre domaine serveur (`apps.loyalty`), avec leurs
  // propres permissions : un compte peut composer les défis sans pouvoir
  // engager l'enseigne sur une remise.
  recompenses('loyalty.read', 'loyalty.write');

  const CatalogueDeFidelisation(this.lecture, this.ecriture);

  final String lecture;
  final String ecriture;
}

/// Catalogues de fidélisation — `/gamification/manage/*` et
/// `/loyalty/manage/rewards/`.
///
/// ## Ce qui a changé, et pourquoi
///
/// Relevé le 21 septembre 2026, vérifié en réel :
///
/// * **les listes étaient des `Map` à clés libres**, et l'écran lisait des
///   clés que ce service ne produisait pas (`title`, `cost`, `reward_type`
///   pour une récompense dont les champs sont `name`, `points_cost`, `kind`) :
///   les trois récompenses en base s'affichaient sans titre, à « 0 pts », et
///   leur modification envoyait un coût nul que le serveur refusait. Les
///   écrans reçoivent désormais les **modèles du socle** — une clé mal
///   orthographiée ne compile plus ;
/// * **les écritures rendaient un booléen** et rangeaient la raison dans un
///   `_error` que l'écran n'affichait pas ; les dialogues se fermaient avant
///   la réponse. Elles laissent maintenant remonter l'`ApiException`, que
///   `DialogueDeFormulaire` affiche sans se fermer ;
/// * **un échec bloquait tout** : les quatre catalogues se lisaient à la
///   suite dans un seul `try`, et le refus du premier vidait les trois
///   autres. Chacun se lit seul, avec son propre [echecDe] — et seulement si
///   le compte a la permission de le lire.
///
/// Aucune suppression : un succès supprimé emporterait ce que des clients ont
/// débloqué, une récompense retirée rendrait illisible un échange passé.
/// Désactiver retire de la circulation sans réécrire le passé.
class GamificationService extends ChangeNotifier {
  GamificationService({eccore.ManagedGamificationRepository? depot, bool Function(String)? peut})
      : _depot = depot,
        _peut = peut;

  final eccore.ManagedGamificationRepository? _depot;
  final bool Function(String)? _peut;

  eccore.ManagedGamificationRepository get _catalogues =>
      _depot ?? eccore.ManagedGamificationRepository(apiClient: AdminAuthService().apiClient);

  bool _autorise(String permission) => (_peut ?? AdminAuthService().can)(permission);

  List<eccore.ManagedAchievement> _succes = const [];
  List<eccore.ManagedChallenge> _defis = const [];
  List<eccore.ManagedBadge> _badges = const [];
  List<eccore.ManagedReward> _recompenses = const [];
  final Map<CatalogueDeFidelisation, Echec> _echecs = {};
  bool _enCours = false;
  bool _initialise = false;

  List<eccore.ManagedAchievement> get succes => _succes;
  List<eccore.ManagedChallenge> get defis => _defis;
  List<eccore.ManagedBadge> get badges => _badges;
  List<eccore.ManagedReward> get recompenses => _recompenses;
  bool get enCours => _enCours;

  /// Pourquoi ce catalogue n'a pas pu être lu — `null` s'il l'a été.
  Echec? echecDe(CatalogueDeFidelisation catalogue) => _echecs[catalogue];

  /// Le compte peut-il lire ce catalogue ? Un catalogue interdit n'est pas
  /// demandé : son 403 n'apprendrait rien que la permission ne dise déjà.
  bool peutLire(CatalogueDeFidelisation catalogue) => _autorise(catalogue.lecture);
  bool peutEcrire(CatalogueDeFidelisation catalogue) => _autorise(catalogue.ecriture);

  Future<void> initialize() async {
    if (_initialise) return;
    _initialise = true;
    await refresh();
  }

  Future<void> refresh() async {
    _enCours = true;
    notifyListeners();
    await Future.wait([
      _lire(CatalogueDeFidelisation.succes, () async => _succes = await _catalogues.achievements()),
      _lire(CatalogueDeFidelisation.defis, () async => _defis = await _catalogues.challenges()),
      _lire(CatalogueDeFidelisation.badges, () async => _badges = await _catalogues.badges()),
      _lire(
        CatalogueDeFidelisation.recompenses,
        () async => _recompenses = await _catalogues.rewards(),
      ),
    ]);
    _enCours = false;
    notifyListeners();
  }

  Future<void> _lire(CatalogueDeFidelisation catalogue, Future<void> Function() lecture) async {
    _echecs.remove(catalogue);
    if (!peutLire(catalogue)) return;
    try {
      await lecture();
    } on eccore.ApiException catch (e) {
      _echecs[catalogue] = Echec.de(e);
      eccore.Journal.trace('Fidélisation : ${catalogue.name} illisible — ${e.code}');
    }
  }

  // ------------------------------------------------------------- succès

  /// Crée ([id] nul) ou modifie un succès. Lève `ApiException`.
  Future<eccore.ManagedAchievement> enregistrerSucces({
    required String name,
    required String description,
    required String icon,
    required String conditionType,
    required int conditionValue,
    required int pointsReward,
    required bool isActive,
    String? id,
  }) async {
    final enregistre = id == null
        ? await _catalogues.createAchievement(
            name: name,
            description: description,
            icon: icon,
            conditionType: conditionType,
            conditionValue: conditionValue,
            pointsReward: pointsReward,
            isActive: isActive,
          )
        : await _catalogues.updateAchievement(
            achievementId: id,
            name: name,
            description: description,
            icon: icon,
            conditionType: conditionType,
            conditionValue: conditionValue,
            pointsReward: pointsReward,
            isActive: isActive,
          );
    _succes = _remplacer(_succes, enregistre, (e) => e.id);
    notifyListeners();
    return enregistre;
  }

  Future<void> basculerSucces(eccore.ManagedAchievement succes) async {
    final maj = await _catalogues.updateAchievement(
      achievementId: succes.id,
      isActive: !succes.isActive,
    );
    _succes = _remplacer(_succes, maj, (e) => e.id);
    notifyListeners();
  }

  // --------------------------------------------------------------- défis

  /// Crée ou modifie un défi. Les dates partent **telles que saisies** : la
  /// modification remettait autrefois « aujourd'hui → +7 jours », faute de lire
  /// les bonnes clés. Lève `ApiException`.
  Future<eccore.ManagedChallenge> enregistrerDefi({
    required String title,
    required String description,
    required String challengeType,
    required String conditionType,
    required int targetValue,
    required int rewardPoints,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool isActive,
    String? id,
  }) async {
    final enregistre = id == null
        ? await _catalogues.createChallenge(
            title: title,
            description: description,
            challengeType: challengeType,
            conditionType: conditionType,
            targetValue: targetValue,
            rewardPoints: rewardPoints,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
          )
        : await _catalogues.updateChallenge(
            challengeId: id,
            title: title,
            description: description,
            challengeType: challengeType,
            conditionType: conditionType,
            targetValue: targetValue,
            rewardPoints: rewardPoints,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: isActive,
          );
    _defis = _remplacer(_defis, enregistre, (e) => e.id);
    notifyListeners();
    return enregistre;
  }

  Future<void> basculerDefi(eccore.ManagedChallenge defi) async {
    final maj = await _catalogues.updateChallenge(challengeId: defi.id, isActive: !defi.isActive);
    _defis = _remplacer(_defis, maj, (e) => e.id);
    notifyListeners();
  }

  // -------------------------------------------------------------- badges

  Future<eccore.ManagedBadge> enregistrerBadge({
    required String title,
    required String description,
    required String icon,
    required int pointsRequired,
    required bool isActive,
    String? id,
  }) async {
    final enregistre = id == null
        ? await _catalogues.createBadge(
            title: title,
            description: description,
            icon: icon,
            pointsRequired: pointsRequired,
            isActive: isActive,
          )
        : await _catalogues.updateBadge(
            badgeId: id,
            title: title,
            description: description,
            icon: icon,
            pointsRequired: pointsRequired,
            isActive: isActive,
          );
    _badges = _remplacer(_badges, enregistre, (e) => e.id);
    notifyListeners();
    return enregistre;
  }

  Future<void> basculerBadge(eccore.ManagedBadge badge) async {
    final maj = await _catalogues.updateBadge(badgeId: badge.id, isActive: !badge.isActive);
    _badges = _remplacer(_badges, maj, (e) => e.id);
    notifyListeners();
  }

  // --------------------------------------------------------- récompenses

  /// Crée ou modifie une récompense.
  ///
  /// [restaurantId] nul crée une récompense **nationale**, que le serveur
  /// réserve au siège. La remise ([discount]) porte sa devise : celle de
  /// l'établissement choisi, ou celle que le siège a choisie pour une
  /// récompense nationale — jamais celle de l'établissement qui se trouve
  /// sélectionné dans le back-office. L'établissement n'est fixé qu'à la
  /// création. Lève `ApiException`.
  Future<eccore.ManagedReward> enregistrerRecompense({
    required String name,
    required String description,
    required String kind,
    required int pointsCost,
    required int validityDays,
    required bool isActive,
    eccore.Money? discount,
    String? restaurantId,
    String? id,
  }) async {
    final enregistre = id == null
        ? await _catalogues.createReward(
            name: name,
            description: description,
            kind: kind,
            pointsCost: pointsCost,
            discount: discount,
            validityDays: validityDays,
            restaurantId: restaurantId,
            isActive: isActive,
          )
        : await _catalogues.updateReward(
            rewardId: id,
            name: name,
            description: description,
            kind: kind,
            pointsCost: pointsCost,
            discount: discount,
            validityDays: validityDays,
            isActive: isActive,
          );
    _recompenses = _remplacer(_recompenses, enregistre, (e) => e.id);
    notifyListeners();
    return enregistre;
  }

  Future<void> basculerRecompense(eccore.ManagedReward recompense) async {
    final maj = await _catalogues.updateReward(
      rewardId: recompense.id,
      isActive: !recompense.isActive,
    );
    _recompenses = _remplacer(_recompenses, maj, (e) => e.id);
    notifyListeners();
  }

  // ------------------------------------------------------------ interne

  static List<T> _remplacer<T>(List<T> liste, T element, String Function(T) cle) {
    final index = liste.indexWhere((existant) => cle(existant) == cle(element));
    return index == -1
        ? [...liste, element]
        : [...liste.sublist(0, index), element, ...liste.sublist(index + 1)];
  }
}
