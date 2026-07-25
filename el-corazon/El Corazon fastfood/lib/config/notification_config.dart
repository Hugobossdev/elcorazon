import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Configuration des notifications push pour FastGo
class NotificationConfig {
  // Configuration des canaux Android
  static const Map<String, AndroidNotificationChannel> androidChannels = {
    'orders': AndroidNotificationChannel(
      'orders',
      'Commandes',
      description: 'Notifications pour les commandes',
      importance: Importance.max,
      enableLights: true,
    ),
    'delivery': AndroidNotificationChannel(
      'delivery',
      'Livraisons',
      description: 'Notifications pour les livraisons',
      importance: Importance.max,
      enableLights: true,
    ),
    'promotions': AndroidNotificationChannel(
      'promotions',
      'Promotions',
      description: 'Notifications pour les promotions',
      importance: Importance.high,
      enableVibration: false,
    ),
    'achievements': AndroidNotificationChannel(
      'achievements',
      'Achievements',
      description: 'Notifications pour les achievements',
      importance: Importance.high,
    ),
    'social': AndroidNotificationChannel(
      'social',
      'Social',
      description: 'Notifications sociales',
      playSound: false,
      enableVibration: false,
    ),
  };

  // Configuration des topics Firebase
  static const Map<String, String> firebaseTopics = {
    'all_users': 'all_users',
    'new_promotions': 'new_promotions',
    'order_updates': 'order_updates',
    'delivery_updates': 'delivery_updates',
    'achievements': 'achievements',
    'social_activity': 'social_activity',
  };

  // Configuration des types de notifications
  static const Map<String, NotificationTypeConfig> notificationTypes = {
    'order_status': NotificationTypeConfig(
      priority: 'high',
      sound: true,
      vibration: true,
      lights: true,
      badge: true,
      persistent: true,
    ),
    'delivery': NotificationTypeConfig(
      priority: 'high',
      sound: true,
      vibration: true,
      lights: true,
      badge: true,
      persistent: true,
    ),
    'promotion': NotificationTypeConfig(
      priority: 'medium',
      sound: true,
      vibration: false,
      lights: false,
      badge: true,
      persistent: false,
    ),
    'achievement': NotificationTypeConfig(
      priority: 'medium',
      sound: true,
      vibration: true,
      lights: false,
      badge: true,
      persistent: false,
    ),
    'social': NotificationTypeConfig(
      priority: 'low',
      sound: false,
      vibration: false,
      lights: false,
      badge: true,
      persistent: false,
    ),
  };

  // Configuration des templates par défaut
  static const Map<String, String> defaultTemplates = {
    'order_confirmed': '🎉 Votre commande #{orderId} a été confirmée!',
    'order_preparing': '👨‍🍳 Votre commande #{orderId} est en préparation',
    'order_ready': '🍔 Votre commande #{orderId} est prête!',
    'order_delivered': '😋 Votre commande #{orderId} a été livrée!',
    'promotion_welcome': '🎁 Bienvenue! Profitez de {discount}% de réduction',
    'achievement_unlocked': '🏆 Achievement débloqué: {achievementName}!',
    'delivery_assigned': '🚚 {deliveryPerson} livrera votre commande',
    'social_friend_activity': '👥 {friendName} a une nouvelle activité',
  };

  // Configuration des délais
  static const Map<String, Duration> notificationDelays = {
    'order_reminder': Duration(minutes: 30),
    'delivery_reminder': Duration(minutes: 15),
    'promotion_expiry': Duration(hours: 24),
    'achievement_celebration': Duration(seconds: 5),
  };

  // Configuration des limites
  static const Map<String, int> notificationLimits = {
    'max_notifications_per_hour': 10,
    'max_notifications_per_day': 50,
    'max_pending_notifications': 100,
    'notification_retention_days': 30,
  };

  // Configuration des couleurs par type
  static const Map<String, int> notificationColors = {
    'order_status': 0xFF2196F3, // Bleu
    'delivery': 0xFF4CAF50, // Vert
    'promotion': 0xFFFF9800, // Orange
    'achievement': 0xFF9C27B0, // Violet
    'social': 0xFFE91E63, // Rose
    'general': 0xFF607D8B, // Gris
  };

  // Configuration des icônes par type
  static const Map<String, String> notificationIcons = {
    'order_status': 'shopping_bag',
    'delivery': 'delivery_dining',
    'promotion': 'local_offer',
    'achievement': 'emoji_events',
    'social': 'people',
    'general': 'notifications',
  };

  // Configuration des sons par type
  static const Map<String, String> notificationSounds = {
    'order_status': 'notification_order.wav',
    'delivery': 'notification_delivery.wav',
    'promotion': 'notification_promotion.wav',
    'achievement': 'notification_achievement.wav',
    'social': 'notification_social.wav',
    'general': 'notification_default.wav',
  };

  // Configuration des vibrations par type
  static const Map<String, List<int>> notificationVibrations = {
    'order_status': [0, 500, 200, 500],
    'delivery': [0, 300, 100, 300],
    'promotion': [0, 200],
    'achievement': [0, 1000],
    'social': [],
    'general': [0, 250],
  };

  // Configuration des permissions
  static const Map<String, bool> defaultPermissions = {
    'order_notifications': true,
    'delivery_notifications': true,
    'promotion_notifications': true,
    'achievement_notifications': true,
    'social_notifications': false,
    'marketing_notifications': false,
  };

  // Configuration des heures de notification
  static const Map<String, String> notificationHours = {
    'start_hour': '08:00',
    'end_hour': '22:00',
    'quiet_hours_start': '22:00',
    'quiet_hours_end': '08:00',
  };

  // Configuration des fuseaux horaires
  static const String defaultTimezone = 'Africa/Bamako';
  static const List<String> supportedTimezones = [
    'Africa/Bamako',
    'Africa/Abidjan',
    'Africa/Dakar',
    'Africa/Ouagadougou',
    'Africa/Niamey',
  ];

  // Configuration des langues
  static const String defaultLanguage = 'fr';
  static const List<String> supportedLanguages = [
    'fr',
    'en',
    'ar',
    'bm',
  ];

  // Configuration des templates par langue
  static const Map<String, Map<String, String>> localizedTemplates = {
    'fr': {
      'order_confirmed': '🎉 Votre commande #{orderId} a été confirmée!',
      'order_preparing': '👨‍🍳 Votre commande #{orderId} est en préparation',
      'promotion_welcome': '🎁 Bienvenue! Profitez de {discount}% de réduction',
    },
    'en': {
      'order_confirmed': '🎉 Your order #{orderId} has been confirmed!',
      'order_preparing': '👨‍🍳 Your order #{orderId} is being prepared',
      'promotion_welcome': '🎁 Welcome! Enjoy {discount}% discount',
    },
    'ar': {
      'order_confirmed': '🎉 تم تأكيد طلبك #{orderId}!',
      'order_preparing': '👨‍🍳 طلبك #{orderId} قيد التحضير',
      'promotion_welcome': '🎁 مرحباً! استمتع بخصم {discount}%',
    },
  };

  // Configuration des tests
  static const Map<String, dynamic> testConfig = {
    'enable_test_mode': kDebugMode,
    'test_notification_interval': Duration(seconds: 5),
    'test_user_id': 'test_user_123',
    'test_order_id': 'test_order_456',
    'test_delivery_person': 'Test Delivery Person',
  };

  // Configuration des analytics
  static const Map<String, bool> analyticsConfig = {
    'track_notification_sends': true,
    'track_notification_opens': true,
    'track_notification_dismissals': true,
    'track_user_preferences': true,
    'track_performance_metrics': true,
  };

  // Configuration des retry
  static const Map<String, dynamic> retryConfig = {
    'max_retry_attempts': 3,
    'retry_delay_seconds': 5,
    'exponential_backoff': true,
  };

  // Configuration des rate limits
  static const Map<String, int> rateLimitConfig = {
    'max_notifications_per_minute': 5,
    'max_notifications_per_hour': 20,
    'max_notifications_per_day': 100,
    'cooldown_period_minutes': 1,
  };

  // Configuration des fallbacks
  static const Map<String, String> fallbackConfig = {
    'default_title': 'Notification FastGo',
    'default_body': 'Vous avez une nouvelle notification',
    'default_icon': 'ic_notification',
    'default_sound': 'notification_default.wav',
  };

  // Configuration des groupes de notifications
  static const Map<String, String> notificationGroups = {
    'orders': 'orders_group',
    'deliveries': 'deliveries_group',
    'promotions': 'promotions_group',
    'achievements': 'achievements_group',
    'social': 'social_group',
  };

  // Configuration des actions de notification
  static const Map<String, List<NotificationAction>> notificationActions = {
    'order_status': [
      NotificationAction('view_order', 'Voir la commande'),
      NotificationAction('track_delivery', 'Suivre la livraison'),
    ],
    'delivery': [
      NotificationAction('view_delivery', 'Voir la livraison'),
      NotificationAction('contact_delivery', 'Contacter le livreur'),
    ],
    'promotion': [
      NotificationAction('view_promotion', 'Voir la promotion'),
      NotificationAction('use_promo_code', 'Utiliser le code'),
    ],
    'achievement': [
      NotificationAction('view_achievement', 'Voir l\'achievement'),
      NotificationAction('share_achievement', 'Partager'),
    ],
  };

  // Configuration des deep links
  static const Map<String, String> deepLinkConfig = {
    'order_details': '/order-details',
    'delivery_tracking': '/delivery-tracking',
    'promotions': '/promotions',
    'achievements': '/achievements',
    'social': '/social',
    'profile': '/profile',
  };

  // Configuration des expirations
  static const Map<String, Duration> expirationConfig = {
    'order_notifications': Duration(hours: 24),
    'delivery_notifications': Duration(hours: 12),
    'promotion_notifications': Duration(days: 7),
    'achievement_notifications': Duration(days: 30),
    'social_notifications': Duration(days: 3),
  };

  // Configuration des priorités
  static const Map<String, int> priorityConfig = {
    'critical': 5,
    'high': 4,
    'medium': 3,
    'low': 2,
    'minimal': 1,
  };

  // Configuration des catégories
  static const Map<String, List<String>> categoryConfig = {
    'orders': ['order_status', 'order_reminder', 'order_update'],
    'deliveries': [
      'delivery_assigned',
      'delivery_on_way',
      'delivery_delivered',
    ],
    'promotions': ['promotion_new', 'promotion_expiring', 'promotion_special'],
    'achievements': [
      'achievement_unlocked',
      'badge_earned',
      'milestone_reached',
    ],
    'social': ['friend_activity', 'group_invite', 'social_achievement'],
  };

  // Configuration des filtres
  static const Map<String, List<String>> filterConfig = {
    'by_type': [
      'order_status',
      'delivery',
      'promotion',
      'achievement',
      'social',
    ],
    'by_priority': ['critical', 'high', 'medium', 'low', 'minimal'],
    'by_status': ['unread', 'read', 'archived', 'deleted'],
    'by_date': ['today', 'yesterday', 'this_week', 'this_month', 'older'],
  };

  // Configuration des templates avancés
  static const Map<String, Map<String, dynamic>> advancedTemplates = {
    'order_confirmed': {
      'title': '🎉 Commande confirmée!',
      'body': 'Votre commande #{orderId} a été confirmée et est en préparation',
      'emoji': '🎉',
      'color': 0xFF2196F3,
      'sound': 'notification_order.wav',
      'vibration': [0, 500, 200, 500],
    },
    'delivery_assigned': {
      'title': '🚚 Livreur assigné',
      'body': '{deliveryPerson} livrera votre commande #{orderId}',
      'emoji': '🚚',
      'color': 0xFF4CAF50,
      'sound': 'notification_delivery.wav',
      'vibration': [0, 300, 100, 300],
    },
    'promotion_welcome': {
      'title': '🎁 Bienvenue chez El Corazón!',
      'body': 'Profitez de {discount}% de réduction avec le code {promoCode}',
      'emoji': '🎁',
      'color': 0xFFFF9800,
      'sound': 'notification_promotion.wav',
      'vibration': [0, 200],
    },
  };

  // Configuration des tests de performance
  static const Map<String, int> performanceConfig = {
    'max_concurrent_notifications': 10,
    'notification_timeout_seconds': 30,
    'batch_size': 50,
    'cache_size': 1000,
  };

  // Configuration des métriques
  static const Map<String, String> metricsConfig = {
    'notification_send_rate': 'notifications_per_minute',
    'notification_open_rate': 'open_rate_percentage',
    'notification_click_rate': 'click_rate_percentage',
    'user_engagement': 'engagement_score',
  };

  // Configuration des alertes
  static const Map<String, Map<String, dynamic>> alertConfig = {
    'high_error_rate': {
      'threshold': 0.1,
      'action': 'disable_notifications',
      'duration': Duration(minutes: 30),
    },
    'low_engagement': {
      'threshold': 0.05,
      'action': 'reduce_frequency',
      'duration': Duration(hours: 24),
    },
    'system_overload': {
      'threshold': 0.8,
      'action': 'throttle_notifications',
      'duration': Duration(minutes: 15),
    },
  };

  // Configuration des sauvegardes
  static const Map<String, Duration> backupConfig = {
    'notification_backup_interval': Duration(hours: 6),
    'user_preferences_backup_interval': Duration(days: 1),
    'analytics_backup_interval': Duration(days: 1),
    'retention_period': Duration(days: 90),
  };

  // Configuration des migrations
  static const Map<String, String> migrationConfig = {
    'current_version': '1.0.0',
    'supported_versions': '0.9.0,1.0.0',
    'migration_script': 'migrate_notifications.sql',
    'rollback_script': 'rollback_notifications.sql',
  };

  // Configuration des logs
  static const Map<String, bool> loggingConfig = {
    'log_notification_sends': true,
    'log_notification_opens': true,
    'log_notification_errors': true,
    'log_performance_metrics': true,
    'log_user_interactions': true,
  };

  // Configuration des environnements
  static const Map<String, Map<String, dynamic>> environmentConfig = {
    'development': {
      'enable_debug_logs': true,
      'enable_test_notifications': true,
      'notification_delay': Duration(seconds: 1),
      'max_notifications_per_hour': 100,
    },
    'staging': {
      'enable_debug_logs': false,
      'enable_test_notifications': false,
      'notification_delay': Duration(seconds: 5),
      'max_notifications_per_hour': 50,
    },
    'production': {
      'enable_debug_logs': false,
      'enable_test_notifications': false,
      'notification_delay': Duration(seconds: 10),
      'max_notifications_per_hour': 20,
    },
  };
}

/// Configuration d'un type de notification
class NotificationTypeConfig {
  final String priority;
  final bool sound;
  final bool vibration;
  final bool lights;
  final bool badge;
  final bool persistent;

  const NotificationTypeConfig({
    required this.priority,
    required this.sound,
    required this.vibration,
    required this.lights,
    required this.badge,
    required this.persistent,
  });
}

/// Configuration d'une action de notification
class NotificationAction {
  final String id;
  final String title;

  const NotificationAction(this.id, this.title);
}
