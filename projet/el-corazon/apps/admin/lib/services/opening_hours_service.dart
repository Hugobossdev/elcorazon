import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Horaires d'ouverture — `/restaurants/manage/hours/` (Phase 6).
///
/// Ce service remplace un onglet qui n'écrivait nulle part. L'écran des
/// réglages proposait une heure d'ouverture, une heure de fermeture et sept
/// interrupteurs de jours, enregistrés dans les `SharedPreferences` **du
/// poste** — c'est-à-dire relus par personne, pas même par l'écran qui venait
/// de les écrire, et jamais transmis au serveur. Le bandeau annonçait
/// « Paramètres sauvegardés avec succès » ; les applications client et livreur
/// n'en voyaient rien, et un établissement annoncé fermé le dimanche
/// continuait de prendre des commandes.
///
/// Deux différences de modèle, qui viennent du serveur et sont des gains :
///
/// * **une plage, pas une journée.** Le service du midi et celui du soir sont
///   deux lignes du même jour. Le couple ouverture/fermeture d'avant ne savait
///   pas les représenter, et forçait à déclarer ouvert entre les deux ;
/// * **fermer un jour, c'est n'y laisser aucune plage.** Il n'y a pas
///   d'interrupteur : l'absence de plage *est* la fermeture, et il ne peut donc
///   pas y avoir de désaccord entre un drapeau et des horaires.
class OpeningHoursService extends ChangeNotifier {
  eccore.ManagedOpeningHoursRepository get _horaires =>
      eccore.ManagedOpeningHoursRepository(
        apiClient: AdminAuthService().apiClient,
      );

  final RestaurantScopeService _scope = RestaurantScopeService();

  List<eccore.OpeningHours> _plages = const [];
  bool _isLoading = false;
  String? _error;
  bool _charge = false;

  List<eccore.OpeningHours> get plages => List.unmodifiable(_plages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Les plages d'un jour, dans l'ordre de la journée.
  ///
  /// [jour] suit la convention du serveur : **lundi = 0**, dimanche = 6.
  List<eccore.OpeningHours> plagesDuJour(int jour) =>
      _plages.where((plage) => plage.weekday == jour).toList()
        ..sort((a, b) => a.opensAtMinutes.compareTo(b.opensAtMinutes));

  /// L'établissement est-il déclaré ouvert ce jour-là ?
  bool ouvertLe(int jour) => plagesDuJour(jour).isNotEmpty;

  Future<void> initialize() async {
    if (_charge) return;
    _charge = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plages = await _horaires.list();
      eccore.Journal.trace('Horaires : ${_plages.length} plage(s)');
    } on eccore.ApiException catch (e) {
      // 403 sans `restaurants.write` : un rôle qui ne règle pas l'établissement
      // n'a pas à voir cet onglet en erreur. Ce n'est pas une panne.
      _error = e.status == 403
          ? 'Ce compte ne peut pas lire les horaires : il lui manque la '
              'permission « restaurants.read ».'
          : e.detail;
      eccore.Journal.trace('Horaires : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajoute une plage au jour donné.
  ///
  /// Le serveur refuse une plage vide (`22:00 → 22:00`) et un doublon exact sur
  /// le même jour ; le message remonte tel quel plutôt que d'être reformulé.
  Future<bool> ajouter({
    required int jour,
    required int ouvertureMinutes,
    required int fermetureMinutes,
  }) async {
    final etablissement = _scope.current;
    if (etablissement == null) {
      _error = RestaurantScopeService.sansPerimetre;
      notifyListeners();
      return false;
    }

    return _ecrire(() async {
      // L'identifiant et non le slug : `ManagedOpeningHoursSerializer` adresse
      // l'établissement par clé primaire, contrairement au catalogue.
      final creee = await _horaires.create(
        restaurantId: etablissement.id,
        weekday: jour,
        opensAtMinutes: ouvertureMinutes,
        closesAtMinutes: fermetureMinutes,
      );
      _plages = [..._plages, creee]..sort(_parJourPuisHeure);
    });
  }

  Future<bool> modifier({
    required String plageId,
    int? ouvertureMinutes,
    int? fermetureMinutes,
  }) async {
    return _ecrire(() async {
      final maj = await _horaires.update(
        hoursId: plageId,
        opensAtMinutes: ouvertureMinutes,
        closesAtMinutes: fermetureMinutes,
      );
      _plages = [
        for (final plage in _plages)
          if (plage.id == plageId) maj else plage,
      ]..sort(_parJourPuisHeure);
    });
  }

  /// Retire une plage. Retirer la dernière d'un jour ferme ce jour-là.
  Future<bool> supprimer(String plageId) async {
    return _ecrire(() async {
      await _horaires.delete(plageId);
      _plages = _plages.where((plage) => plage.id != plageId).toList();
    });
  }

  Future<bool> _ecrire(Future<void> Function() action) async {
    _error = null;
    try {
      await action();
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Horaires : écriture refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  static int _parJourPuisHeure(eccore.OpeningHours a, eccore.OpeningHours b) {
    final jour = a.weekday.compareTo(b.weekday);
    return jour != 0 ? jour : a.opensAtMinutes.compareTo(b.opensAtMinutes);
  }

  /// Les sept jours, dans la convention du serveur — lundi = 0.
  static const List<String> nomsDesJours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
}
