import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

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
/// venaient de l'exploitation. Ici, [templateWeek] rend la même semaine type,
/// mais explicitement non enregistrée : elle ne s'écrit que si quelqu'un la
/// valide.
class DriverScheduleService extends ChangeNotifier {
  eccore.ManagedCourierRepository get _fleet =>
      eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient);

  final Map<String, List<DriverSchedule>> _schedules = {};
  final Set<String> _chargements = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<DriverSchedule>> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDriverSchedules(String driverId) async {
    if (_chargements.contains(driverId)) return;
    _chargements.add(driverId);

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final creneaux = await _fleet.shifts(courierId: driverId);
      _schedules[driverId] = creneaux.map(DriverSchedule.fromRemote).toList();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Planning : chargement impossible — ${e.code}');
      // Pas de semaine inventée en cas d'échec : afficher « 9 h – 21 h » sur
      // une erreur réseau ferait croire à un planning qui n'existe pas.
      _schedules[driverId] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String driverId) async {
    _chargements.remove(driverId);
    await loadDriverSchedules(driverId);
  }

  /// Semaine type, **non enregistrée** : sept lignes que l'écran propose et que
  /// l'exploitation valide, jour par jour, si elle le souhaite.
  List<DriverSchedule> templateWeek(String driverId) {
    return List.generate(
      7,
      (index) => DriverSchedule(
        driverId: driverId,
        dayOfWeek: index + 1,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 21, minute: 0),
      ),
    );
  }

  /// Enregistre un créneau — création s'il n'existe pas encore, sinon mise à
  /// jour. C'est [DriverSchedule.isPersisted] qui tranche, pas une convention
  /// sur la forme de l'identifiant.
  Future<bool> saveSchedule(DriverSchedule schedule) async {
    try {
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
      lignes.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      // Le serveur refuse un créneau qui passe minuit : il s'écrit en deux
      // lignes, sur deux jours.
      _error = e.detail;
      eccore.Journal.trace('Planning : enregistrement refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSchedule(String scheduleId, String driverId) async {
    try {
      await _fleet.deleteShift(scheduleId);
      _schedules[driverId]?.removeWhere((s) => s.id == scheduleId);
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Planning : suppression refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  List<DriverSchedule> getDriverSchedules(String driverId) =>
      _schedules[driverId] ?? const [];

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
