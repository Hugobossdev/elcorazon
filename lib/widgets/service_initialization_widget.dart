import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/service_initializer.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/service_initialization_helper.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/models/user.dart';

/// Widget pour gérer l'initialisation des services
class ServiceInitializationWidget extends StatefulWidget {
  final Widget child;
  final bool initializeOnStartup;

  const ServiceInitializationWidget({
    required this.child, super.key,
    this.initializeOnStartup = true,
  });

  @override
  State<ServiceInitializationWidget> createState() =>
      _ServiceInitializationWidgetState();
}

class _ServiceInitializationWidgetState
    extends State<ServiceInitializationWidget> {
  bool _isInitializing = false;
  bool _isInitialized = false;
  String _currentStep = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initializeOnStartup) {
      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    if (_isInitialized || _isInitializing) return;

    setState(() {
      _isInitializing = true;
      _progress = 0.0;
    });

    try {
      final serviceInitializer = ServiceInitializer();

      // Étape 1: Services essentiels seulement (les autres seront lazy)
      setState(() {
        _currentStep = 'Initialisation des services essentiels...';
        _progress = 0.2;
      });
      // Initialiser seulement les services essentiels
      // Les autres services seront initialisés à la demande (lazy)
      await _initializeCoreServicesOnly(context);

      // Étape 2: Services utilisateur si connecté
      final appService = Provider.of<AppService>(context, listen: false);
      if (appService.isLoggedIn && appService.currentUser != null) {
        setState(() {
          _currentStep = 'Configuration des services utilisateur...';
          _progress = 0.8;
        });
        await serviceInitializer.initializeUserServices(
            context, appService.currentUser!,);
      }

      // Étape 3: Finalisation
      setState(() {
        _currentStep = 'Finalisation...';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isInitialized = true;
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation des services: $e');
      setState(() {
        _isInitializing = false;
        _currentStep = 'Erreur lors de l\'initialisation';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.initializeOnStartup || _isInitialized) {
      return widget.child;
    }

    if (_isInitializing) {
      return _buildInitializationScreen();
    }

    return widget.child;
  }

  Widget _buildInitializationScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou icône de l'application
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant,
                size: 60,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 40),

            // Titre
            Text(
              'El Corazón',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              'Initialisation en cours...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),

            const SizedBox(height: 40),

            // Barre de progression
            Container(
              width: 250,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Texte de progression
            Text(
              _currentStep,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Indicateur de chargement
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Initialise seulement les services essentiels (optimisation lazy)
  Future<void> _initializeCoreServicesOnly(BuildContext context) async {
    try {
      // Services essentiels seulement
      await ServiceInitializationHelper.initializeIfNeeded<AppService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      await ServiceInitializationHelper.initializeIfNeeded<LocationService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      await ServiceInitializationHelper.initializeIfNeeded<NotificationService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      await ServiceInitializationHelper.initializeIfNeeded<CartService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'initialisation des services essentiels: $e',);
    }
  }
}

/// Extension pour faciliter l'utilisation du widget d'initialisation
extension ServiceInitializationExtension on BuildContext {
  /// Vérifie si les services sont initialisés
  bool areServicesInitialized() {
    return ServiceInitializer().isInitialized;
  }

  /// Force l'initialisation des services
  Future<void> initializeServices() async {
    final serviceInitializer = ServiceInitializer();
    await serviceInitializer.initializeAllServices(this);
  }

  /// Initialise les services pour un utilisateur
  Future<void> initializeUserServices(User user) async {
    final serviceInitializer = ServiceInitializer();
    await serviceInitializer.initializeUserServices(this, user);
  }
}
