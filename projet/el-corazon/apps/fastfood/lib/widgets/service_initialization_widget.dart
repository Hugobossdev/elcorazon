import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/service_initializer.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/service_initialization_helper.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
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

  @override
  void initState() {
    super.initState();
    if (widget.initializeOnStartup) {
      // Après la première image, et non pendant `initState` : ce widget est
      // posé dans `MaterialApp.builder`, donc au-dessus du `Navigator`.
      // Démarrer avant que l'arbre ne soit monté revenait à retarder
      // l'affichage de la première route.
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeServices());
    }
  }

  Future<void> _initializeServices() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      final serviceInitializer = ServiceInitializer();

      // Services périphériques seulement. `AppService` n'est **pas** dans la
      // liste, et son absence est le correctif : il y était, alors que
      // `SplashScreen` l'initialise déjà. Les deux appelants ne se
      // connaissaient pas, et le catalogue partait donc deux fois à chaque
      // démarrage — la seconde salve, dans le journal, ressemblait à un
      // rechargement spontané.
      //
      // C'est le splash qui a raison des deux : lui attend `sessionReadyFuture`
      // avant d'initialiser. L'appel qui se trouvait ici partait sans, si bien
      // que `_loadUserSession()` lisait un `_currentUser` encore nul et sautait
      // le chargement des commandes d'un client pourtant connecté.
      await _initializeCoreServicesOnly(context);

      // Services utilisateur si une session est ouverte.
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      if (appService.isLoggedIn && appService.currentUser != null) {
        if (!mounted || !context.mounted) return;
        await serviceInitializer.initializeUserServices(
          context,
          appService.currentUser!,
        );
      }

      _isInitialized = true;
    } catch (e) {
      final translatedError = ErrorHandlerService.translateError(e);
      ErrorHandlerService().logError(
        'Initialisation échouée: $translatedError',
        code: 'INIT_ERROR',
        details: e,
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// L'arbre passe **toujours**, sans attendre.
  ///
  /// Ce `build` rendait un `Scaffold` de chargement plein écran tant que
  /// l'initialisation courait, à la place de `widget.child` — c'est-à-dire à la
  /// place du `Navigator` tout entier. Tant qu'un service tardait, l'application
  /// n'avait aucune interface : ni le splash, ni rien. Avec un backend muet,
  /// cela faisait plus de trente secondes de rond blanc, et la première route
  /// n'était montée qu'ensuite.
  ///
  /// Ces services ne conditionnent aucune première image : le carnet, les
  /// notifications et la position se signalent par `notifyListeners()` quand ils
  /// sont prêts, et les écrans qui en dépendent les écoutent déjà. L'écran
  /// d'ouverture, lui, existe précisément pour couvrir ce temps-là.
  @override
  Widget build(BuildContext context) => widget.child;

  /// Initialise les services périphériques (hors `AppService`, voir plus haut).
  Future<void> _initializeCoreServicesOnly(BuildContext context) async {
    try {
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
        "Erreur lors de l'initialisation des services essentiels",
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
  Future<void> initializeUserServices(eccore.User user) async {
    final serviceInitializer = ServiceInitializer();
    await serviceInitializer.initializeUserServices(this, user);
  }
}
