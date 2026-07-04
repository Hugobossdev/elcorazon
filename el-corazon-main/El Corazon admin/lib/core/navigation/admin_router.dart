import 'package:flutter/material.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/menu_management_screen.dart';
import '../../screens/admin/advanced_order_management_screen.dart';
import '../../screens/admin/driver_management_screen.dart';
import '../../screens/admin/analytics_screen.dart';
import '../../screens/admin/client_management_screen.dart';
import '../../screens/admin/category_management_screen.dart';
import '../../screens/admin/customization_management_screen.dart';
import '../../screens/admin/admin_roles_screen.dart';
import '../../screens/admin/marketing_screen.dart';
import '../../screens/admin/promotions_screen.dart';
import '../../screens/admin/gamification_management_screen.dart';
import '../../screens/admin/driver_map_screen.dart';
import '../../screens/admin/settings_screen.dart';

/// Routeur centralisé pour la navigation admin
class AdminRouter {
  AdminRouter._();

  /// Obtenir l'écran correspondant à l'index de navigation
  static Widget getScreen(int index) {
    switch (index) {
      case 0:
        return const AdminDashboardScreen();
      case 1:
        return const MenuManagementScreen();
      case 2:
        return const AdvancedOrderManagementScreen();
      case 3:
        return const DriverManagementScreen();
      case 4:
        return const AnalyticsScreen();
      case 5:
        return const ClientManagementScreen();
      case 6:
        return const CategoryManagementScreen();
      case 7:
        return const AdminRolesScreen();
      case 8:
        return const MarketingScreen();
      case 9:
        return const PromotionsScreen();
      case 10:
        return const GamificationManagementScreen();
      case 11:
        return const DriverMapScreen();
      case 12:
        return const SettingsScreen();
      case 13:
        return const CustomizationManagementScreen();
      default:
        return const AdminDashboardScreen();
    }
  }

  /// Obtenir le titre de l'écran
  static String getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Menu';
      case 2:
        return 'Livreurs';
      case 3:
        return 'Analytics';
      case 4:
        return 'Clients';
      case 5:
        return 'Catégories';
      case 6:
        return 'Rôles';
      case 7:
        return 'Marketing';
      case 8:
        return 'Promotions';
      case 9:
        return 'Gamification';
      case 10:
        return 'Carte';
      case 11:
        return 'Paramètres';
      case 12:
        return 'Personnalisations';
      default:
        return 'Dashboard';
    }
  }
}
