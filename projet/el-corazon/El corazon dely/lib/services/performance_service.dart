import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Service de monitoring des performances
class PerformanceService extends ChangeNotifier {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, DateTime> _startTimes = {};
  final Map<String, Duration> _durations = {};
  final List<PerformanceMetric> _metrics = [];
  bool _isInitialized = false;

  List<PerformanceMetric> get metrics => List.unmodifiable(_metrics);
  bool get isInitialized => _isInitialized;

  // Propriétés pour l'écran analytics
  Duration? get averageOperationTime {
    if (_metrics.isEmpty) return null;
    final totalMs =
        _metrics.fold<int>(0, (sum, m) => sum + m.duration.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ _metrics.length);
  }

  int get operationCount => _metrics.length;

  int get errorCount =>
      _metrics.where((m) => m.operation.contains('error')).length;

  double get performanceScore {
    if (_metrics.isEmpty) return 0.0;
    final avgMs = averageOperationTime?.inMilliseconds ?? 0;
    // Score basé sur la rapidité (plus c'est rapide, plus le score est élevé)
    return (1000 / (avgMs + 1)).clamp(0.0, 100.0);
  }

  Map<String, Duration?> get operationTimes {
    final Map<String, List<Duration>> operationDurations = {};

    for (final metric in _metrics) {
      operationDurations.putIfAbsent(metric.operation, () => []);
      operationDurations[metric.operation]!.add(metric.duration);
    }

    final Map<String, Duration?> result = {};
    for (final entry in operationDurations.entries) {
      final durations = entry.value;
      final avgMs =
          durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) ~/
              durations.length;
      result[entry.key] = Duration(milliseconds: avgMs);
    }

    return result;
  }

  double get efficiencyScore {
    if (_metrics.isEmpty) return 0.0;
    final successfulOps =
        _metrics.where((m) => !m.operation.contains('error')).length;
    return (successfulOps / _metrics.length) * 100;
  }

  double get reliabilityScore {
    if (_metrics.isEmpty) return 0.0;
    final errorOps =
        _metrics.where((m) => m.operation.contains('error')).length;
    return ((_metrics.length - errorOps) / _metrics.length) * 100;
  }

  double get speedScore {
    if (_metrics.isEmpty) return 0.0;
    final avgMs = averageOperationTime?.inMilliseconds ?? 0;
    // Score inversement proportionnel au temps (plus c'est rapide, plus le score est élevé)
    return (1000 / (avgMs + 1)).clamp(0.0, 100.0);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;
    notifyListeners();
  }

  /// Démarre le chronométrage d'une opération
  void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  /// Arrête le chronométrage d'une opération
  Duration? stopTimer(String operation) {
    final startTime = _startTimes.remove(operation);
    if (startTime == null) return null;

    final duration = DateTime.now().difference(startTime);
    _durations[operation] = duration;

    // Enregistrer la métrique
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
    );
    _metrics.add(metric);

    // Garder seulement les 100 dernières métriques
    if (_metrics.length > 100) {
      _metrics.removeAt(0);
    }

    notifyListeners();
    return duration;
  }

  /// Mesure le temps d'exécution d'une fonction
  Future<T> measureOperation<T>(
      String operation, Future<T> Function() function) async {
    startTimer(operation);
    try {
      final result = await function();
      stopTimer(operation);
      return result;
    } catch (e) {
      stopTimer(operation);
      rethrow;
    }
  }

  /// Mesure le temps d'exécution d'une fonction synchrone
  T measureSyncOperation<T>(String operation, T Function() function) {
    startTimer(operation);
    try {
      final result = function();
      stopTimer(operation);
      return result;
    } catch (e) {
      stopTimer(operation);
      rethrow;
    }
  }

  /// Obtient la durée moyenne d'une opération
  Duration? getAverageDuration(String operation) {
    final operationMetrics =
        _metrics.where((m) => m.operation == operation).toList();
    if (operationMetrics.isEmpty) return null;

    final totalMilliseconds = operationMetrics.fold<int>(
      0,
      (sum, metric) => sum + metric.duration.inMilliseconds,
    );

    return Duration(milliseconds: totalMilliseconds ~/ operationMetrics.length);
  }

  /// Obtient les métriques d'une opération
  List<PerformanceMetric> getMetricsForOperation(String operation) {
    return _metrics.where((m) => m.operation == operation).toList();
  }

  /// Obtient les opérations les plus lentes
  List<PerformanceMetric> getSlowestOperations({int limit = 10}) {
    final sortedMetrics = List<PerformanceMetric>.from(_metrics);
    sortedMetrics.sort((a, b) => b.duration.compareTo(a.duration));
    return sortedMetrics.take(limit).toList();
  }

  /// Efface toutes les métriques
  void clearMetrics() {
    _metrics.clear();
    _durations.clear();
    _startTimes.clear();
    notifyListeners();
  }

  /// Obtient un rapport de performance
  PerformanceReport getPerformanceReport() {
    final totalOperations = _metrics.length;
    final averageDuration = totalOperations > 0
        ? Duration(
            milliseconds: _metrics.fold<int>(
                    0, (sum, m) => sum + m.duration.inMilliseconds) ~/
                totalOperations,
          )
        : Duration.zero;

    final slowestOperations = getSlowestOperations(limit: 5);
    final operationCounts = <String, int>{};

    for (final metric in _metrics) {
      operationCounts[metric.operation] =
          (operationCounts[metric.operation] ?? 0) + 1;
    }

    return PerformanceReport(
      totalOperations: totalOperations,
      averageDuration: averageDuration,
      slowestOperations: slowestOperations,
      operationCounts: operationCounts,
      generatedAt: DateTime.now(),
    );
  }

  /// Log des métriques en mode debug
  void logMetrics() {
    if (kDebugMode) {
      final report = getPerformanceReport();
      Journal.trace('📊 Performance Report:');
      Journal.trace('   Total operations: ${report.totalOperations}');
      Journal.trace(
          '   Average duration: ${report.averageDuration.inMilliseconds}ms');
      Journal.trace('   Slowest operations:');
      for (final metric in report.slowestOperations) {
        Journal.trace(
            '     ${metric.operation}: ${metric.duration.inMilliseconds}ms');
      }
    }
  }
}

/// Métrique de performance
class PerformanceMetric {
  final String operation;
  final Duration duration;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operation,
    required this.duration,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'PerformanceMetric(operation: $operation, duration: ${duration.inMilliseconds}ms, timestamp: $timestamp)';
  }
}

/// Rapport de performance
class PerformanceReport {
  final int totalOperations;
  final Duration averageDuration;
  final List<PerformanceMetric> slowestOperations;
  final Map<String, int> operationCounts;
  final DateTime generatedAt;

  PerformanceReport({
    required this.totalOperations,
    required this.averageDuration,
    required this.slowestOperations,
    required this.operationCounts,
    required this.generatedAt,
  });

  @override
  String toString() {
    return 'PerformanceReport(totalOperations: $totalOperations, averageDuration: ${averageDuration.inMilliseconds}ms, generatedAt: $generatedAt)';
  }
}
