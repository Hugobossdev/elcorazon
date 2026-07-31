import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/services/group_cart_service.dart';
import 'package:elcora_fast/services/voice_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/promo_code_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/services/subscription_service.dart';
import 'package:elcora_fast/models/user.dart';

/// Service centralisé pour initialiser tous les services de l'application
class ServiceInitializer {
  static final ServiceInitializer _instance = ServiceInitializer._internal();
  factory ServiceInitializer() => _instance;
  ServiceInitializer._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialise tous les services de l'application
  Future<void> initializeAllServices(BuildContext context) async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Initialisation des services...');

      // Capturer tous les services avant les gaps asynchrones
      final appService = Provider.of<AppService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);
      final cartService = Provider.of<CartService>(context, listen: false);
      final gamificationService =
          Provider.of<GamificationService>(context, listen: false);
      final voiceService = Provider.of<VoiceService>(context, listen: false);
      final customizationService =
          Provider.of<CustomizationService>(context, listen: false);
      final groupCartService = Provider.of<GroupCartService>(context, listen: false);
      final promoCodeService =
          Provider.of<PromoCodeService>(context, listen: false);
      final payDunyaService =
          Provider.of<PayDunyaService>(context, listen: false);
      final addressService =
          Provider.of<AddressService>(context, listen: false);
      final offlineSyncService =
          Provider.of<OfflineSyncService>(context, listen: false);
      final pushNotificationService =
          Provider.of<PushNotificationService>(context, listen: false);
      final aiRecommendationService =
          Provider.of<AIRecommendationService>(context, listen: false);

      // Services essentiels
      await _initializeCoreServices(
        appService: appService,
        locationService: locationService,
        notificationService: notificationService,
        cartService: cartService,
        gamificationService: gamificationService,
      );

      // Services avancés
      await _initializeAdvancedServices(
        voiceService: voiceService,
        customizationService: customizationService,
      );

      // Services optionnels
      await _initializeOptionalServices(
        groupCartService: groupCartService,
        promoCodeService: promoCodeService,
        payDunyaService: payDunyaService,
        addressService: addressService,
        offlineSyncService: offlineSyncService,
        pushNotificationService: pushNotificationService,
        aiRecommendationService: aiRecommendationService,
      );

      _isInitialized = true;
      debugPrint('✅ Tous les services initialisés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des services: $e');
      rethrow;
    }
  }

  /// Initialise les services essentiels
  Future<void> _initializeCoreServices({
    required AppService appService,
    required LocationService locationService,
    required NotificationService notificationService,
    required CartService cartService,
    required GamificationService gamificationService,
  }) async {
    debugPrint('📱 Initialisation des services essentiels...');

    // Services de base
    await _initializeServiceWithoutContext(
      () => appService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => locationService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => notificationService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => cartService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => gamificationService.initialize(),
    );

    debugPrint('✅ Services essentiels initialisés');
  }

  /// Initialise les services avancés
  Future<void> _initializeAdvancedServices({
    required VoiceService voiceService,
    required CustomizationService customizationService,
  }) async {
    debugPrint('🔧 Initialisation des services avancés...');

    // Services de fonctionnalités avancées
    await _initializeServiceWithoutContext(
      () => voiceService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => customizationService.initialize(),
    );

    debugPrint('✅ Services avancés initialisés');
  }

  /// Initialise les services optionnels
  Future<void> _initializeOptionalServices({
    required GroupCartService groupCartService,
    required PromoCodeService promoCodeService,
    required PayDunyaService payDunyaService,
    required AddressService addressService,
    required OfflineSyncService offlineSyncService,
    required PushNotificationService pushNotificationService,
    required AIRecommendationService aiRecommendationService,
  }) async {
    debugPrint('🎯 Initialisation des services optionnels...');

    // Services sociaux et groupes
    await _initializeServiceWithoutContext(
      () => groupCartService.initialize(),
    );

    // Codes promotionnels
    await _initializeServiceWithoutContext(
      () => promoCodeService.initialize(),
    );

    // Services de suivi et temps réel (initialisés plus tard avec l'utilisateur)
    // Ces services nécessitent un utilisateur, donc ils sont initialisés dans initializeUserServices

    // Services de paiement et adresses
    await _initializeServiceWithoutContext(
      () => payDunyaService.initialize(
        masterKey: 'test_master_key',
        privateKey: 'test_private_key',
        token: 'test_token',
      ),
    );
    await _initializeServiceWithoutContext(
      () => addressService.initialize(),
    );

    // Services de synchronisation
    await _initializeServiceWithoutContext(
      () => offlineSyncService.initialize(),
    );
    await _initializeServiceWithoutContext(
      () => pushNotificationService.initialize(),
    );

    // Services de gamification avancée
    await _initializeServiceWithoutContext(
      () => aiRecommendationService.initialize(),
    );

    debugPrint('✅ Services optionnels initialisés');
  }

  /// Initialise un service individuel sans BuildContext (pour éviter les gaps asynchrones)
  Future<void> _initializeServiceWithoutContext(
    Future<void> Function() serviceInit,
  ) async {
    try {
      await serviceInit();
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'initialisation d\'un service: $e');
      // Ne pas faire échouer l'initialisation complète pour un service optionnel
    }
  }

  /// Initialise les services pour un utilisateur spécifique
  Future<void> initializeUserServices(BuildContext context, User user) async {
    try {
      debugPrint(
        '👤 Initialisation des services pour l\'utilisateur: ${user.name}',
      );

      // Capturer les services avant le gap asynchrone
      final realtimeTrackingService =
          Provider.of<RealtimeTrackingService>(context, listen: false);
      final notificationDatabaseService =
          Provider.of<NotificationDatabaseService>(context, listen: false);
      final subscriptionService =
          Provider.of<SubscriptionService>(context, listen: false);

      // Charger l'historique de notifications du compte. Plus d'identifiant à
      // passer : le serveur cloisonne sur le jeton.
      await _initializeServiceWithoutContext(
        () => notificationDatabaseService.loadNotifications(),
      );

      // Abonnement en cours : décide de l'accès aux articles `vip_exclusive`.
      await _initializeServiceWithoutContext(
        () => subscriptionService.load(),
      );

      // Initialiser le service de suivi en temps réel avec l'utilisateur
      // (pas besoin de passer context car le service est déjà capturé)
      await _initializeServiceWithoutContext(
        () => realtimeTrackingService.initialize(
          userId: user.id,
          userRole: user.role,
        ),
      );

      debugPrint('✅ Services utilisateur initialisés');
    } catch (e) {
      debugPrint(
        '❌ Erreur lors de l\'initialisation des services utilisateur: $e',
      );
    }
  }

  /// Réinitialise tous les services
  Future<void> resetServices() async {
    _isInitialized = false;
    debugPrint('🔄 Services réinitialisés');
  }

  /// Vérifie l'état d'initialisation des services
  Map<String, bool> getServicesStatus(BuildContext context) {
    return {
      'AppService':
          Provider.of<AppService>(context, listen: false).isInitialized,
      'LocationService':
          Provider.of<LocationService>(context, listen: false).isInitialized,
      'NotificationService':
          Provider.of<NotificationService>(context, listen: false)
              .isInitialized,
      'CartService':
          Provider.of<CartService>(context, listen: false).isInitialized,
      'GamificationService':
          Provider.of<GamificationService>(context, listen: false)
              .isInitialized,
      'CustomizationService':
          Provider.of<CustomizationService>(context, listen: false)
              .isInitialized,
      'GroupCartService':
          Provider.of<GroupCartService>(context, listen: false).isInitialized,
      'RealtimeTrackingService':
          Provider.of<RealtimeTrackingService>(context, listen: false)
              .isConnected,
      'OfflineSyncService':
          Provider.of<OfflineSyncService>(context, listen: false).isInitialized,
    };
  }
}
