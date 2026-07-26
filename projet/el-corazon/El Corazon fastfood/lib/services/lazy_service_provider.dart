import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

/// Mixin pour les services qui peuvent être initialisés à la demande
mixin LazyInitializable {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  void markAsInitialized() {
    _isInitialized = true;
  }
  
  void resetInitialization() {
    _isInitialized = false;
  }
}

/// Helper pour créer des providers lazy avec initialisation conditionnelle
class LazyServiceFactory {
  /// Crée un provider lazy qui initialise le service seulement quand nécessaire
  static ChangeNotifierProvider<T> createLazy<T extends ChangeNotifier>(
    T Function() factory, {
    bool Function()? shouldInitialize,
  }) {
    return ChangeNotifierProvider<T>(
      create: (_) {
        final service = factory();
        if (shouldInitialize?.call() ?? false) {
          // Initialisation sera faite ailleurs
        }
        return service;
      },
      lazy: true,
    );
  }
  
  /// Crée un provider proxy lazy qui dépend d'un autre service
  static ChangeNotifierProxyProvider<S, T> createLazyProxy<S extends ChangeNotifier, T extends ChangeNotifier>(
    T Function() factory,
    T Function(BuildContext, S, T?) update, {
    bool Function(S)? shouldInitialize,
  }) {
    return ChangeNotifierProxyProvider<S, T>(
      create: (_) => factory(),
      update: (context, source, previous) {
        if (previous == null) {
          final service = factory();
          if (shouldInitialize?.call(source) ?? false) {
            // Initialisation sera faite ailleurs
          }
          return service;
        }
        return update(context, source, previous);
      },
      lazy: true,
    );
  }
}

/// Service manager pour gérer l'initialisation lazy des services
class LazyServiceManager {
  static final Map<Type, bool> _initializedServices = {};
  static final Map<Type, Future<void> Function()> _initializers = {};
  
  /// Enregistre un initializer pour un service
  static void registerInitializer<T>(
    Future<void> Function(T) initializer,
  ) {
    _initializers[T] = () async {
      // L'initializer sera appelé avec l'instance du service
      // Cette implémentation nécessite d'être appelée avec l'instance
    };
  }
  
  /// Vérifie si un service est initialisé
  static bool isInitialized<T>() {
    return _initializedServices[T] ?? false;
  }
  
  /// Marque un service comme initialisé
  static void markAsInitialized<T>() {
    _initializedServices[T] = true;
  }
  
  /// Réinitialise un service
  static void reset<T>() {
    _initializedServices.remove(T);
  }
  
  /// Réinitialise tous les services
  static void resetAll() {
    _initializedServices.clear();
  }
}

