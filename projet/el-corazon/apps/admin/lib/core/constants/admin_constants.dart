// Constantes centralisées pour l'application Admin
//
// Ce fichier contient toutes les constantes réutilisables dans l'application admin
// pour éviter les valeurs magiques et faciliter la maintenance.

class AdminConstants {
  AdminConstants._(); // Constructeur privé pour empêcher l'instanciation

  // =====================================================
  // CONFIGURATION APP
  // =====================================================
  static const String appName = 'El Corazón - Admin';
  static const String appVersion = '1.0.0';
  static const String companyName = 'FastFoodGo';

  // =====================================================
  // TIMEOUTS & DELAYS
  // =====================================================
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortDelay = Duration(milliseconds: 150);
  static const Duration mediumDelay = Duration(milliseconds: 500);

  // =====================================================
  // PAGINATION & LIMITS
  // =====================================================
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  static const int dashboardRecentItemsLimit = 5;
  static const int topSellingItemsLimit = 10;

  // =====================================================
  // FORM VALIDATION
  // =====================================================
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;
  static const int maxDescriptionLength = 500;
  static const int maxPhoneLength = 20;
  static const double minPrice = 0.01;
  static const double maxPrice = 9999.99;

  // Regex patterns
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phonePattern = r'^\+?[0-9]{8,15}$';
  static const String urlPattern =
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$';

  // =====================================================
  // SPACING & DIMENSIONS
  // =====================================================
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;

  static const double borderRadiusSM = 8.0;
  static const double borderRadiusMD = 12.0;
  static const double borderRadiusLG = 16.0;
  static const double borderRadiusXL = 24.0;

  static const double iconSizeSM = 16.0;
  static const double iconSizeMD = 24.0;
  static const double iconSizeLG = 32.0;
  static const double iconSizeXL = 48.0;

  // =====================================================
  // CARD DIMENSIONS
  // =====================================================
  static const double cardElevation = 2.0;
  static const double cardElevationHigh = 4.0;
  static const double cardPadding = 16.0;

  // =====================================================
  // GRID CONFIGURATION
  // =====================================================
  static const int dashboardGridCrossAxisCount = 2;
  static const double dashboardGridChildAspectRatio = 1.2;
  static const double dashboardGridSpacing = 16.0;

  static const int quickActionsGridCrossAxisCount = 2;
  static const double quickActionsGridChildAspectRatio = 2.5;
  static const double quickActionsGridSpacing = 12.0;

  // =====================================================
  // TIME RANGES
  // =====================================================
  static const String timeRangeToday = 'today';
  static const String timeRangeWeek = 'week';
  static const String timeRangeMonth = 'month';
  static const String timeRangeYear = 'year';

  static const int defaultAnalyticsDays = 30;

  // =====================================================
  // STATUS COLORS (comme référence)
  // =====================================================
  static const int pendingColor = 0xFFFF9800; // Orange
  static const int confirmedColor = 0xFF2196F3; // Blue
  static const int preparingColor = 0xFF9C27B0; // Purple
  static const int readyColor = 0xFF4CAF50; // Green
  static const int deliveredColor = 0xFF4CAF50; // Green
  static const int cancelledColor = 0xFFF44336; // Red
  static const int errorColor = 0xFF795548; // Brown

  // =====================================================
  // ERROR MESSAGES
  // =====================================================
  static const String errorGeneric = 'Une erreur est survenue';
  static const String errorNetwork = 'Erreur de connexion réseau';
  static const String errorTimeout = 'La requête a expiré';
  static const String errorUnauthorized = 'Accès non autorisé';
  static const String errorNotFound = 'Ressource introuvable';
  static const String errorValidation = 'Les données fournies sont invalides';

  // =====================================================
  // SUCCESS MESSAGES
  // =====================================================
  static const String successSaved = 'Enregistré avec succès';
  static const String successDeleted = 'Supprimé avec succès';
  static const String successUpdated = 'Mis à jour avec succès';
  static const String successCreated = 'Créé avec succès';

  // =====================================================
  // DATABASE TABLE NAMES
  // =====================================================
  static const String tableUsers = 'users';
  static const String tableOrders = 'orders';
  static const String tableMenuItems = 'menu_items';
  static const String tableCategories = 'menu_categories';
  static const String tableDrivers = 'drivers';
  static const String tableAdminRoles = 'admin_roles';
  static const String tablePromotions = 'promotions';
}

/// Constantes pour les routes de navigation
class AdminRoutes {
  AdminRoutes._();

  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String orders = '/orders';
  static const String drivers = '/drivers';
  static const String analytics = '/analytics';
  static const String categories = '/categories';
  static const String roles = '/roles';
  static const String marketing = '/marketing';
  static const String promotions = '/promotions';
}

/// Constantes pour les clés de stockage local
class AdminStorageKeys {
  AdminStorageKeys._();

  static const String lastLogin = 'admin_last_login';
  static const String selectedTheme = 'admin_selected_theme';
  static const String dashboardPreferences = 'admin_dashboard_prefs';
  static const String userPreferences = 'admin_user_prefs';
}
