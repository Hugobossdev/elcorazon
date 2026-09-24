import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Créneau planifié d'un livreur, tel que l'affiche l'écran de planning.
///
/// [id] vaut `null` tant que la ligne n'existe pas côté serveur : l'écran
/// montre une semaine complète, sept lignes, même pour un livreur qu'on n'a
/// encore jamais planifié. L'ancienne version fabriquait des identifiants
/// (`${driverId}_3`) pour ces lignes fantômes, et les envoyait en base — où
/// rien ne les distinguait d'un vrai créneau.
class DriverSchedule {
  const DriverSchedule({
    required this.driverId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.id,
    this.isAvailable = true,
  });

  factory DriverSchedule.fromRemote(eccore.CourierShift remote) {
    return DriverSchedule(
      id: remote.id,
      driverId: remote.courierId,
      dayOfWeek: remote.dayOfWeek,
      startTime: TimeOfDay(
        hour: remote.startMinutes ~/ 60,
        minute: remote.startMinutes % 60,
      ),
      endTime: TimeOfDay(
        hour: remote.endMinutes ~/ 60,
        minute: remote.endMinutes % 60,
      ),
      isAvailable: remote.isAvailable,
    );
  }

  /// Nul tant que le créneau n'a pas été enregistré.
  final String? id;
  final String driverId;

  /// Jour ISO : 1 = lundi, 7 = dimanche.
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;

  bool get isPersisted => id != null;

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;

  DriverSchedule copyWith({
    String? id,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isAvailable,
  }) {
    return DriverSchedule(
      id: id ?? this.id,
      driverId: driverId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// Planning de la flotte — `/delivery/shifts/` (Phase 6).
///
/// **Indicatif, et non opposable.** L'éligibilité d'un livreur reste, côté
/// serveur, « en ligne, dossier validé, compte actif » (invariant L1). Un
/// créneau ne s'y ajoute pas : un livreur présent, en ligne, à qui le serveur
/// refuserait une course parce qu'il est 18 h 05 verrait un refus qu'aucun
/// écran ne sait expliquer, et la commande resterait sans porteur.
///
/// D'où la disparition d'`isDriverAvailable` : cette méthode répondait
/// « disponible » depuis le navigateur, à partir d'horaires que rien
/// n'appliquait. Elle donnait une réponse que le serveur ne partageait pas —
/// et c'est le serveur qui affecte les courses.
///
/// L'ancienne version fabriquait aussi des horaires par défaut « 7 j/7, 9 h –
/// 21 h » **quand la table n'existait pas**, puis les enregistrait comme s'ils
/// venaient de l'exploitation.
///
/// ## Ce qui a changé le 23 septembre 2026
///
/// * **Les écritures lèvent.** Elles rendaient `false` en gardant le motif dans
///   `_error`, que l'écran n'affichait nulle part : un créneau refusé — parce
///   qu'il en recouvre un autre, ou qu'il manque un droit — se soldait par une
///   carte qui revenait silencieusement à sa valeur d'avant.
/// * **Un jour porte autant de créneaux qu'il en faut.** Le service n'en
///   rendait qu'un par jour à l'écran, alors que le serveur en accepte
///   plusieurs (service du midi, service du soir) : le second était invisible,
///   et le modifier écrasait le premier.
/// * `templateWeek` a disparu avec l'écran qui l'affichait : une semaine
///   inventée ressemblait trop à un planning pour qu'on la distingue.
class DriverScheduleService extends ChangeNotifier {
  eccore.ManagedCourierRepository get _fleet =>
      eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient);

  final Map<String, List<DriverSchedule>> _schedules = {};
  bool _isLoading = false;
  Echec? _echec;

  bool get isLoading => _isLoading;

  /// Pourquoi le planning affiché est vide, quand il l'est **parce que la
  /// lecture a échoué**. Nul quand elle a abouti — fût-ce sur zéro créneau.
  Echec? get echec => _echec;

  /// Lit le planning d'un livreur. Sans effet de bord : l'écran l'appelle à
  /// l'ouverture et après chaque écriture, jamais depuis un `build`.
  Future<void> loadDriverSchedules(String driverId) async {
    _isLoading = true;
    _echec = null;
    notifyListeners();

    try {
      final creneaux = await _fleet.shifts(courierId: driverId);
      _schedules[driverId] = creneaux.map(DriverSchedule.fromRemote).toList()..sort(_parJourEtHeure);
    } on eccore.ApiException catch (e) {
      _echec = Echec.de(e);
      eccore.Journal.trace('Planning : chargement impossible — ${e.code}');
      // Pas de semaine inventée en cas d'échec : afficher « 9 h – 21 h » sur
      // une erreur réseau ferait croire à un planning qui n'existe pas.
      _schedules.remove(driverId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String driverId) => loadDriverSchedules(driverId);

  static int _parJourEtHeure(DriverSchedule a, DriverSchedule b) {
    final jours = a.dayOfWeek.compareTo(b.dayOfWeek);
    return jours != 0 ? jours : a.startMinutes.compareTo(b.startMinutes);
  }

  /// Enregistre un créneau — création s'il n'existe pas encore, sinon mise à
  /// jour. C'est [DriverSchedule.isPersisted] qui tranche, pas une convention
  /// sur la forme de l'identifiant.
  ///
  /// **Lève `ApiException`.** Le serveur refuse un créneau qui passe minuit, un
  /// créneau qui en recouvre un autre le même jour, et un livreur hors
  /// périmètre : chacun de ces refus dit quoi corriger, et l'écran l'affiche.
  Future<DriverSchedule> saveSchedule(DriverSchedule schedule) async {
    final enregistre = schedule.isPersisted
        ? await _fleet.updateShift(
            shiftId: schedule.id!,
            dayOfWeek: schedule.dayOfWeek,
            startMinutes: schedule.startMinutes,
            endMinutes: schedule.endMinutes,
            isAvailable: schedule.isAvailable,
          )
        : await _fleet.createShift(
            courierId: schedule.driverId,
            dayOfWeek: schedule.dayOfWeek,
            startMinutes: schedule.startMinutes,
            endMinutes: schedule.endMinutes,
            isAvailable: schedule.isAvailable,
          );

    final locale = DriverSchedule.fromRemote(enregistre);
    final lignes = _schedules.putIfAbsent(schedule.driverId, () => []);
    final index = lignes.indexWhere((s) => s.id == locale.id);
    if (index != -1) {
      lignes[index] = locale;
    } else {
      lignes.add(locale);
    }
    lignes.sort(_parJourEtHeure);

    notifyListeners();
    return locale;
  }

  /// Retire une ligne du planning. **Lève `ApiException`.**
  Future<void> deleteSchedule(String scheduleId, String driverId) async {
    await _fleet.deleteShift(scheduleId);
    _schedules[driverId]?.removeWhere((s) => s.id == scheduleId);
    notifyListeners();
  }

  /// Le planning d'un livreur, trié. Vide tant qu'il n'a pas été lu — ce que
  /// [echec] et [isLoading] permettent de distinguer d'un planning vide.
  List<DriverSchedule> getDriverSchedules(String driverId) =>
      _schedules[driverId] ?? const [];

  /// Les créneaux d'un jour donné, dans l'ordre des heures.
  ///
  /// Un jour en porte autant qu'il en faut : un service du midi et un service
  /// du soir sont deux lignes, et le serveur les accepte tant qu'elles ne se
  /// recouvrent pas.
  List<DriverSchedule> creneauxDuJour(String driverId, int jour) => [
        for (final ligne in getDriverSchedules(driverId))
          if (ligne.dayOfWeek == jour) ligne,
      ];

  String getDayName(int dayOfWeek) {
    const jours = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return jours[dayOfWeek - 1];
  }
}
