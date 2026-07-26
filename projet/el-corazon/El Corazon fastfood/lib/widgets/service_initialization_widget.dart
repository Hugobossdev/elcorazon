import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/service_initializer.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/service_initialization_helper.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/services/error_handler_service.dart';

/// Widget pour gérer l'initialisation des services
class ServiceInitializationWidget extends StatefulWidget {
  final Widget child;
  final bool initializeOnStartup;

  const ServiceInitializationWidget({
    required this.child,
    super.key,
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
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      if (appService.isLoggedIn && appService.currentUser != null) {
        setState(() {
          _currentStep = 'Configuration des services utilisateur...';
          _progress = 0.8;
        });
        if (!mounted || !context.mounted) return;
        await serviceInitializer.initializeUserServices(
          context,
          appService.currentUser!,
        );
      }

      // Étape 3: Finalisation
      setState(() {
        _currentStep = 'Finalisation...';
        _progress = 1.0;
      });

      setState(() {
        _isInitialized = true;
        _isInitializing = false;
      });
    } catch (e) {
      final translatedError = ErrorHandlerService.translateError(e);
      ErrorHandlerService().logError(
        'Initialisation échouée: $translatedError',
        code: 'INIT_ERROR',
        details: e,
      );
      setState(() {
        _isInitializing = false;
        _currentStep = translatedError;
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
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              _currentStep,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
      if (!mounted || !context.mounted) return;
      await ServiceInitializationHelper.initializeIfNeeded<AppService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      if (!mounted || !context.mounted) return;
      await ServiceInitializationHelper.initializeIfNeeded<LocationService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      if (!mounted || !context.mounted) return;
      await ServiceInitializationHelper.initializeIfNeeded<NotificationService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
      if (!mounted || !context.mounted) return;
      await ServiceInitializationHelper.initializeIfNeeded<CartService>(
        context: context,
        initializer: (service) => service.initialize(),
      );
    } catch (e) {
      ErrorHandlerService().logError(
        'Erreur lors de l\'initialisation des services essentiels',
        code: 'CORE_INIT_ERROR',
        details: e,
      );
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
