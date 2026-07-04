import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:elcora_fast/services/lazy_service_provider.dart';

/// Helper pour initialiser les services à la demande
class ServiceInitializationHelper {
  /// Initialise un service seulement s'il n'est pas déjà initialisé
  static Future<void> initializeIfNeeded<T extends ChangeNotifier>({
    required BuildContext context,
    required Future<void> Function(T) initializer,
    bool forceReinitialize = false,
  }) async {
    try {
      final service = Provider.of<T>(context, listen: false);
      
      // Vérifier si le service a une propriété isInitialized
      if (!forceReinitialize) {
        if (service is LazyInitializable) {
          final lazyService = service as LazyInitializable;
          if (lazyService.isInitialized) {
            debugPrint('✅ Service ${T.toString()} déjà initialisé');
            return;
          }
        }
      }
      
      debugPrint('🔄 Initialisation du service ${T.toString()}...');
      await initializer(service);
      
      if (service is LazyInitializable) {
        (service as LazyInitializable).markAsInitialized();
      }
      
      debugPrint('✅ Service ${T.toString()} initialisé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation de ${T.toString()}: $e');
      // Ne pas faire échouer l'application si un service optionnel échoue
    }
  }
  
  /// Initialise plusieurs services en parallèle
  static Future<void> initializeMultiple({
    required BuildContext context,
    required List<ServiceInitializationTask> tasks,
    bool stopOnError = false,
  }) async {
    final futures = <Future<void>>[];
    
    for (final task in tasks) {
      futures.add(
        initializeIfNeeded(
          context: context,
          initializer: task.initializer,
          forceReinitialize: task.forceReinitialize,
        ).catchError((error) {
          if (stopOnError) {
            throw error;
          }
          debugPrint('⚠️ Erreur dans ${task.name}: $error');
        }),
      );
    }
    
    await Future.wait(futures);
  }
  
  /// Vérifie si un service est initialisé
  static bool isServiceInitialized<T extends ChangeNotifier>(BuildContext context) {
    try {
      final service = Provider.of<T>(context, listen: false);
      if (service is LazyInitializable) {
        return (service as LazyInitializable).isInitialized;
      }
      return true; // Si pas de LazyInitializable, considérer comme initialisé
    } catch (e) {
      return false;
    }
  }
}

/// Tâche d'initialisation de service
class ServiceInitializationTask {
  final String name;
  final Future<void> Function(dynamic) initializer;
  final bool forceReinitialize;
  
  ServiceInitializationTask({
    required this.name,
    required this.initializer,
    this.forceReinitialize = false,
  });
}

/// Extension pour faciliter l'initialisation lazy
extension LazyServiceExtension on BuildContext {
  /// Initialise un service à la demande
  Future<void> initializeService<T extends ChangeNotifier>({
    required Future<void> Function(T) initializer,
    bool forceReinitialize = false,
  }) async {
    await ServiceInitializationHelper.initializeIfNeeded<T>(
      context: this,
      initializer: initializer,
      forceReinitialize: forceReinitialize,
    );
  }
  
  /// Vérifie si un service est initialisé
  bool isServiceInitialized<T extends ChangeNotifier>() {
    return ServiceInitializationHelper.isServiceInitialized<T>(this);
  }
}

