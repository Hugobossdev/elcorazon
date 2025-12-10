import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/services/promotion_service.dart';
import 'package:elcora_fast/services/social_service.dart';
import 'package:elcora_fast/services/voice_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/marketing_service.dart';
import 'package:elcora_fast/services/group_delivery_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/promo_code_service.dart';
import 'package:elcora_fast/services/advanced_gamification_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/push_notification_service.dart';
import 'package:elcora_fast/services/social_features_service.dart';
import 'package:elcora_fast/services/supabase_realtime_service.dart';
import 'package:elcora_fast/services/wallet_service.dart';
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

      // Services essentiels
      await _initializeCoreServices(context);

      // Services avancés
      await _initializeAdvancedServices(context);

      // Services optionnels
      await _initializeOptionalServices(context);

      _isInitialized = true;
      debugPrint('✅ Tous les services initialisés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des services: $e');
      rethrow;
    }
  }

  /// Initialise les services essentiels
  Future<void> _initializeCoreServices(BuildContext context) async {
    debugPrint('📱 Initialisation des services essentiels...');

    // Services de base
    await _initializeService(context,
        () => Provider.of<AppService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () =>
            Provider.of<LocationService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () => Provider.of<NotificationService>(context, listen: false)
            .initialize(),);
    await _initializeService(context,
        () => Provider.of<CartService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () async => Provider.of<GamificationService>(context, listen: false)
            .initialize(),);

    debugPrint('✅ Services essentiels initialisés');
  }

  /// Initialise les services avancés
  Future<void> _initializeAdvancedServices(BuildContext context) async {
    debugPrint('🔧 Initialisation des services avancés...');

    // Services de fonctionnalités avancées
    await _initializeService(context,
        () => Provider.of<VoiceService>(context, listen: false).initialize(),);
    await _initializeService(context,
        () => Provider.of<CustomizationService>(context, listen: false)
            .initialize(),);
    await _initializeService(context,
        () => Provider.of<WalletService>(context, listen: false).initialize(),);

    debugPrint('✅ Services avancés initialisés');
  }

  /// Initialise les services optionnels
  Future<void> _initializeOptionalServices(BuildContext context) async {
    debugPrint('🎯 Initialisation des services optionnels...');

    // Services sociaux et groupes
    await _initializeService(context,
        () => Provider.of<SocialService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () => Provider.of<SocialFeaturesService>(context, listen: false)
            .initialize(),);
    await _initializeService(
        context,
        () => Provider.of<GroupDeliveryService>(context, listen: false)
            .initialize(),);

    // Services de marketing et promotions
    await _initializeService(
        context,
        () =>
            Provider.of<PromotionService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () =>
            Provider.of<MarketingService>(context, listen: false).initialize(),);
    await _initializeService(
        context,
        () =>
            Provider.of<PromoCodeService>(context, listen: false).initialize(),);

    // Services de suivi et temps réel (initialisés plus tard avec l'utilisateur)
    // await _initializeService(
    //     context,
    //     () => Provider.of<RealtimeTrackingService>(context, listen: false)
    //         .initialize());
    // await _initializeService(
    //     context,
    //     () => Provider.of<SupabaseRealtimeService>(context, listen: false)
    //         .initialize());

    // Services de paiement et adresses
    await _initializeService(
        context,
        () => Provider.of<PayDunyaService>(context, listen: false).initialize(
              masterKey: 'test_master_key',
              privateKey: 'test_private_key',
              token: 'test_token',
            ),);
    await _initializeService(context,
        () => Provider.of<AddressService>(context, listen: false).initialize(),);

    // Services de synchronisation
    await _initializeService(
        context,
        () => Provider.of<OfflineSyncService>(context, listen: false)
            .initialize(),);
    await _initializeService(
        context,
        () => Provider.of<PushNotificationService>(context, listen: false)
            .initialize(),);

    // Services de gamification avancée
    await _initializeService(
        context,
        () => Provider.of<AdvancedGamificationService>(context, listen: false)
            .initialize(),);
    await _initializeService(
        context,
        () => Provider.of<AIRecommendationService>(context, listen: false)
            .initialize(),);

    debugPrint('✅ Services optionnels initialisés');
  }

  /// Initialise un service individuel avec gestion d'erreur
  Future<void> _initializeService(
      BuildContext context, Future<void> Function() serviceInit,) async {
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
          '👤 Initialisation des services pour l\'utilisateur: ${user.name}',);

      // Initialiser le service de suivi en temps réel avec l'utilisateur
      await _initializeService(
          context,
          () => Provider.of<RealtimeTrackingService>(context, listen: false)
              .initialize(userId: user.id, userRole: user.role),);

      // Initialiser le service Supabase Realtime avec l'utilisateur
      await _initializeService(
          context,
          () => Provider.of<SupabaseRealtimeService>(context, listen: false)
              .initialize(userId: user.id, userRole: user.role),);

      debugPrint('✅ Services utilisateur initialisés');
    } catch (e) {
      debugPrint(
          '❌ Erreur lors de l\'initialisation des services utilisateur: $e',);
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
      'WalletService': true, // Pas de propriété isInitialized
      'SocialService':
          Provider.of<SocialService>(context, listen: false).isInitialized,
      'SocialFeaturesService': true, // Pas de propriété isInitialized
      'GroupDeliveryService':
          Provider.of<GroupDeliveryService>(context, listen: false)
              .isInitialized,
      'RealtimeTrackingService':
          Provider.of<RealtimeTrackingService>(context, listen: false)
              .isConnected,
      'SupabaseRealtimeService':
          Provider.of<SupabaseRealtimeService>(context, listen: false)
              .isConnected,
      'OfflineSyncService':
          Provider.of<OfflineSyncService>(context, listen: false).isInitialized,
    };
  }
}
