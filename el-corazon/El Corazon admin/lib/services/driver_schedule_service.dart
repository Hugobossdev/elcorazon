import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modèle pour un horaire de livreur
class DriverSchedule {
  final String id;
  final String driverId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DriverSchedule({
    required this.id,
    required this.driverId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory DriverSchedule.fromMap(Map<String, dynamic> map) {
    final startParts = (map['start_time'] as String).split(':');
    final endParts = (map['end_time'] as String).split(':');
    
    return DriverSchedule(
      id: map['id'] as String,
      driverId: map['driver_id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      isAvailable: map['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'day_of_week': dayOfWeek,
      'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Service de gestion des horaires des livreurs
class DriverScheduleService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, List<DriverSchedule>> _schedules = {}; // driverId -> schedules
  bool _isLoading = false;

  Map<String, List<DriverSchedule>> get schedules => _schedules;
  bool get isLoading => _isLoading;

  /// Charger les horaires d'un livreur
  Future<void> loadDriverSchedules(String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('driver_schedules')
          .select()
          .eq('driver_id', driverId)
          .order('day_of_week', ascending: true);

      _schedules[driverId] = (response as List)
          .map((data) => DriverSchedule.fromMap(data))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Table driver_schedules non trouvée ou erreur: $e');
      // Créer un horaire par défaut si la table n'existe pas
      _schedules[driverId] = _getDefaultSchedules(driverId);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtenir les horaires par défaut (7j/7, 9h-21h)
  List<DriverSchedule> _getDefaultSchedules(String driverId) {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return DriverSchedule(
        id: '${driverId}_${index + 1}',
        driverId: driverId,
        dayOfWeek: index + 1,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 21, minute: 0),
        isAvailable: true,
        createdAt: now,
      );
    });
  }

  /// Vérifier si un livreur est disponible à un moment donné
  bool isDriverAvailable(String driverId, DateTime dateTime) {
    final schedules = _schedules[driverId] ?? [];
    if (schedules.isEmpty) return true; // Disponible par défaut

    final dayOfWeek = dateTime.weekday;
    final schedule = schedules.firstWhere(
      (s) => s.dayOfWeek == dayOfWeek && s.isAvailable,
      orElse: () => schedules.first,
    );

    if (!schedule.isAvailable) return false;

    final currentTime = TimeOfDay.fromDateTime(dateTime);
    final startMinutes = schedule.startTime.hour * 60 + schedule.startTime.minute;
    final endMinutes = schedule.endTime.hour * 60 + schedule.endTime.minute;
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /// Sauvegarder un horaire
  Future<bool> saveSchedule(DriverSchedule schedule) async {
    try {
      try {
        await _supabase.from('driver_schedules').upsert(schedule.toMap());
      } catch (e) {
        debugPrint('⚠️ Table driver_schedules non disponible: $e');
      }

      if (!_schedules.containsKey(schedule.driverId)) {
        _schedules[schedule.driverId] = [];
      }
      
      final index = _schedules[schedule.driverId]!
          .indexWhere((s) => s.id == schedule.id);
      
      if (index != -1) {
        _schedules[schedule.driverId]![index] = schedule;
      } else {
        _schedules[schedule.driverId]!.add(schedule);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving schedule: $e');
      return false;
    }
  }

  /// Supprimer un horaire
  Future<bool> deleteSchedule(String scheduleId, String driverId) async {
    try {
      try {
        await _supabase.from('driver_schedules').delete().eq('id', scheduleId);
      } catch (e) {
        debugPrint('⚠️ Table driver_schedules non disponible: $e');
      }

      _schedules[driverId]?.removeWhere((s) => s.id == scheduleId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting schedule: $e');
      return false;
    }
  }

  /// Obtenir les horaires d'un livreur
  List<DriverSchedule> getDriverSchedules(String driverId) {
    return _schedules[driverId] ?? [];
  }

  /// Obtenir le nom du jour
  String getDayName(int dayOfWeek) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return days[dayOfWeek - 1];
  }
}
