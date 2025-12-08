import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Service pour optimiser les performances de l'application
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  final List<PerformanceMetric> _metrics = [];

  /// Mesure le temps d'exécution d'une opération
  static Future<T> measureOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    bool logResult = false,
  }) async {
    final startTime = DateTime.now();
    
    try {
      final result = await operation();
      final duration = DateTime.now().difference(startTime);
      
      if (logResult || kDebugMode) {
        debugPrint(
          '⏱️ $operationName: ${duration.inMilliseconds}ms',
        );
      }
      
      _instance._recordMetric(
        operationName,
        duration,
        success: true,
      );
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      _instance._recordMetric(
        operationName,
        duration,
        success: false,
        error: e.toString(),
      );
      
      rethrow;
    }
  }

  /// Mesure une opération synchrone
  static T measureSyncOperation<T>({
    required String operationName,
    required T Function() operation,
    bool logResult = false,
  }) {
    final startTime = DateTime.now();
    
    try {
      final result = operation();
      final duration = DateTime.now().difference(startTime);
      
      if (logResult || kDebugMode) {
        debugPrint(
          '⏱️ $operationName: ${duration.inMilliseconds}ms',
        );
      }
      
      _instance._recordMetric(
        operationName,
        duration,
        success: true,
      );
      
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      _instance._recordMetric(
        operationName,
        duration,
        success: false,
        error: e.toString(),
      );
      
      rethrow;
    }
  }

  void _recordMetric(
    String operationName,
    Duration duration, {
    required bool success,
    String? error,
  }) {
    _metrics.add(PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: DateTime.now(),
      success: success,
      error: error,
    ),);

    // Garder seulement les 100 dernières métriques
    if (_metrics.length > 100) {
      _metrics.removeAt(0);
    }

    // Les statistiques sont calculées à partir de _metrics
  }

  /// Obtient les statistiques de performance
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, Map<String, dynamic>>{};

    for (final metric in _metrics) {
      final operationStats = stats.putIfAbsent(
        metric.operationName,
        () => {
          'count': 0,
          'totalDuration': Duration.zero,
          'successCount': 0,
          'failureCount': 0,
          'minDuration': const Duration(hours: 1),
          'maxDuration': Duration.zero,
        },
      );

      operationStats['count'] = (operationStats['count'] as int) + 1;
      operationStats['totalDuration'] =
          (operationStats['totalDuration'] as Duration) + metric.duration;

      if (metric.success) {
        operationStats['successCount'] =
            (operationStats['successCount'] as int) + 1;
      } else {
        operationStats['failureCount'] =
            (operationStats['failureCount'] as int) + 1;
      }

      if (metric.duration < (operationStats['minDuration'] as Duration)) {
        operationStats['minDuration'] = metric.duration;
      }

      if (metric.duration > (operationStats['maxDuration'] as Duration)) {
        operationStats['maxDuration'] = metric.duration;
      }
    }

    // Calculer les moyennes
    for (final entry in stats.entries) {
      final count = entry.value['count'] as int;
      final totalDuration = entry.value['totalDuration'] as Duration;
      entry.value['averageDuration'] = Duration(
        milliseconds: totalDuration.inMilliseconds ~/ count,
      );
    }

    return stats;
  }

  /// Débounce une fonction pour éviter les appels trop fréquents
  static Timer? _debounceTimer;

  static void debounce({
    required Duration delay,
    required VoidCallback action,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, action);
  }

  /// Throttle une fonction pour limiter la fréquence d'exécution
  static DateTime? _lastThrottleExecution;
  static Timer? _throttleTimer;

  static void throttle({
    required Duration delay,
    required VoidCallback action,
  }) {
    final now = DateTime.now();

    if (_lastThrottleExecution == null ||
        now.difference(_lastThrottleExecution!) >= delay) {
      action();
      _lastThrottleExecution = now;
    } else {
      _throttleTimer?.cancel();
      _throttleTimer = Timer(
        delay - now.difference(_lastThrottleExecution!),
        action,
      );
    }
  }

  /// Exécute une opération sur le prochain frame pour améliorer les performances
  static void scheduleFrameCallback(VoidCallback callback) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callback();
    });
  }

  /// Nettoie les métriques anciennes
  void clearOldMetrics({Duration? olderThan}) {
    final cutoff = olderThan ?? const Duration(hours: 24);
    final now = DateTime.now();

    _metrics.removeWhere(
      (metric) => now.difference(metric.timestamp) > cutoff,
    );
  }
}

/// Métrique de performance
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final DateTime timestamp;
  final bool success;
  final String? error;

  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
    required this.success,
    this.error,
  });
}

