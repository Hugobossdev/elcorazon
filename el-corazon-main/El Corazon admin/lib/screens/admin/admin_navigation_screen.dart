import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_auth_service.dart';
import '../../widgets/loading_widget.dart';
import '../../dialogs/notifications_dialog.dart';
import '../../utils/dialog_helper.dart';
import '../../ui/ui.dart';
import 'admin_dashboard_screen.dart';
import 'admin_roles_screen.dart';
import 'advanced_order_management_screen.dart';
import 'driver_management_screen.dart';
import 'analytics_screen.dart';
import 'category_management_screen.dart';
import 'customization_management_screen.dart';
import 'menu_management_screen.dart';
import 'marketing_screen.dart';
import 'promotions_screen.dart';
import 'gamification_management_screen.dart';
import 'client_management_screen.dart';
import 'settings_screen.dart';
import 'driver_map_screen.dart';
import 'global_search_screen.dart';
import 'active_deliveries_screen.dart';
import 'driver_documents_dashboard_screen.dart';

// Modèle de données pour les groupes de navigation
class NavigationGroup {
  final String title;
  final List<NavigationItem> items;
  final IconData? icon;

  const NavigationGroup({
    required this.title,
    required this.items,
    this.icon,
  });
}

class NavigationItem {
  final String title;
  final IconData icon;
  final int index;
  final Color? color;

  const NavigationItem({
    required this.title,
    required this.icon,
    required this.index,
    this.color,
  });
}

/// Nouvelle interface de navigation admin moderne avec sidebar groupée
class AdminNavigationScreen extends StatefulWidget {
  const AdminNavigationScreen({super.key});

  @override
  State<AdminNavigationScreen> createState() => _AdminNavigationScreenState();
}

class _AdminNavigationScreenState extends State<AdminNavigationScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  // État d'expansion des groupes dans la sidebar
  // ignore: unused_field
  final Map<String, bool> _expandedGroups = {
    'Opérations': true,
    'Catalogue': true,
  };

  // Définition de la structure de navigation
  static const List<NavigationGroup> _navigationGroups = [
    NavigationGroup(
      title: 'VUE D\'ENSEMBLE',
      items: [
        NavigationItem(
          title: 'Tableau de bord',
          icon: Icons.dashboard_rounded,
          index: 0,
        ),
        NavigationItem(
          title: 'Analyses & Stats',
          icon: Icons.analytics_rounded,
          index: 4,
        ),
      ],
    ),
    NavigationGroup(
      title: 'OPÉRATIONS',
      items: [
        NavigationItem(
          title: 'Commandes',
          icon: Icons.shopping_cart_rounded,
          index: 2,
        ),
        NavigationItem(
          title: 'Livraisons actives',
          icon: Icons.local_shipping_rounded,
          index: 14,
        ),
        NavigationItem(
          title: 'Carte temps réel',
          icon: Icons.map_rounded,
          index: 11,
        ),
      ],
    ),
    NavigationGroup(
      title: 'CATALOGUE',
      items: [
        NavigationItem(
          title: 'Menu',
          icon: Icons.restaurant_menu_rounded,
          index: 1,
        ),
        NavigationItem(
          title: 'Catégories',
          icon: Icons.category_rounded,
          index: 6,
        ),
        NavigationItem(
          title: 'Personnalisations',
          icon: Icons.tune_rounded,
          index: 13,
        ),
      ],
    ),
    NavigationGroup(
      title: 'UTILISATEURS',
      items: [
        NavigationItem(
          title: 'Clients',
          icon: Icons.people_rounded,
          index: 5,
        ),
        NavigationItem(
          title: 'Livreurs',
          icon: Icons.delivery_dining_rounded,
          index: 3,
        ),
        NavigationItem(
          title: 'Validation Docs',
          icon: Icons.verified_user_rounded,
          index: 15,
        ),
      ],
    ),
    NavigationGroup(
      title: 'MARKETING',
      items: [
        NavigationItem(
          title: 'Campagnes',
          icon: Icons.campaign_rounded,
          index: 8,
        ),
        NavigationItem(
          title: 'Promotions',
          icon: Icons.local_offer_rounded,
          index: 9,
        ),
        NavigationItem(
          title: 'Gamification',
          icon: Icons.emoji_events_rounded,
          index: 10,
        ),
      ],
    ),
    NavigationGroup(
      title: 'SYSTÈME',
      items: [
        NavigationItem(
          title: 'Rôles & Accès',
          icon: Icons.admin_panel_settings_rounded,
          index: 7,
        ),
        NavigationItem(
          title: 'Paramètres',
          icon: Icons.settings_rounded,
          index: 12,
        ),
      ],
    ),
  ];

  // Items pour la BottomNavigationBar (Mobile uniquement)
  static const List<NavigationItem> _mobileNavItems = [
    NavigationItem(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      index: 0,
    ),
    NavigationItem(
      title: 'Menu',
      icon: Icons.restaurant_menu_rounded,
      index: 1,
    ),
    NavigationItem(
      title: 'Commandes',
      icon: Icons.shopping_cart_rounded,
      index: 2,
    ),
    NavigationItem(
      title: 'Livreurs',
      icon: Icons.delivery_dining_rounded,
      index: 3,
    ),
  ];

  Widget _getCurrentScreen() {
    Widget screen;
    switch (_selectedIndex) {
      case 0:
        screen = const AdminDashboardScreen();
        break;
      case 1:
        screen = const MenuManagementScreen();
        break;
      case 2:
        screen = const AdvancedOrderManagementScreen();
        break;
      case 3:
        screen = const DriverManagementScreen();
        break;
      case 4:
        screen = const AnalyticsScreen();
        break;
      case 5:
        screen = const ClientManagementScreen();
        break;
      case 6:
        screen = const CategoryManagementScreen();
        break;
      case 7:
        screen = const AdminRolesScreen();
        break;
      case 8:
        screen = const MarketingScreen();
        break;
      case 9:
        screen = const PromotionsScreen();
        break;
      case 10:
        screen = const GamificationManagementScreen();
        break;
      case 11:
        screen = const DriverMapScreen();
        break;
      case 12:
        screen = const SettingsScreen();
        break;
      case 13:
        screen = const CustomizationManagementScreen();
        break;
      case 14:
        screen = const ActiveDeliveriesScreen();
        break;
      case 15:
        screen = const DriverDocumentsDashboardScreen();
        break;
      default:
        screen = const AdminDashboardScreen();
    }

    return KeyedSubtree(
      key: ValueKey(_selectedIndex),
      child: RepaintBoundary(child: _SafeScreenWrapper(child: screen)),
    );
  }

  String _getCurrentTitle() {
    for (var group in _navigationGroups) {
      for (var item in group.items) {
        if (item.index == _selectedIndex) {
          return item.title;
        }
      }
    }
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAuthService>(
      builder: (context, adminAuthService, child) {
        if (adminAuthService.isLoading) {
          return const Scaffold(body: LoadingWidget(message: 'Chargement...'));
        }

        if (!adminAuthService.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/admin-login');
            }
          });
          return const Scaffold(
            body: LoadingWidget(
              message: 'Vérification de l\'authentification...',
            ),
          );
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isMobile =
            MediaQuery.of(context).size.width < 1024; // Tablet breakpoint

        if (isMobile) {
          return Scaffold(
            appBar: _buildMobileAppBar(context, adminAuthService, theme),
            body: _getCurrentScreen(),
            bottomNavigationBar: _buildMobileBottomNav(theme),
            drawer: _buildMobileDrawer(context, adminAuthService, theme),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildModernSidebar(context, adminAuthService, theme),
              Expanded(
                child: Column(
                  children: [
                    _buildModernAppBar(context, adminAuthService, theme),
                    Expanded(
                      child: Container(
                        color: scheme.surface,
                        child: _getCurrentScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _itemAccentColor(BuildContext context, NavigationItem item) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    // Couleurs "sémantiques" stables par section (pas de hardcoded Colors.*).
    switch (item.index) {
      case 0: // Dashboard
        return sem.info;
      case 4: // Analytics
        return scheme.tertiary;
      case 2: // Orders
        return sem.warning;
      case 14: // Active deliveries
        return sem.danger;
      case 11: // Map
        return scheme.secondary;
      case 1: // Menu
        return sem.success;
      case 6: // Categories
        return scheme.primary;
      case 13: // Customizations
        return scheme.tertiary;
      case 5: // Clients
        return scheme.primary;
      case 3: // Drivers
        return scheme.secondary;
      case 15: // Docs validation
        return sem.success;
      case 8: // Marketing
        return scheme.primary;
      case 9: // Promotions
        return sem.warning;
      case 10: // Gamification
        return scheme.primary;
      case 7: // Roles
        return scheme.primary;
      case 12: // Settings
        return scheme.onSurfaceVariant;
      default:
        return scheme.primary;
    }
  }

  // ===========================================================================
  // SIDEBAR (DESKTOP)
  // ===========================================================================

  Widget _buildModernSidebar(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    final sem = AdminColorTokens.semantic(theme.colorScheme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isSidebarExpanded ? 280 : 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(context, theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _navigationGroups.map((group) {
                  return _buildNavigationGroup(group, theme);
                }).toList(),
              ),
            ),
          ),
          _buildSidebarFooter(context, adminAuth, theme),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, ThemeData theme) {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 24 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: _isSidebarExpanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  );
                },
              ),
            ),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'El Corazón',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Administration',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_open_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () => setState(() => _isSidebarExpanded = false),
              tooltip: 'Réduire le menu',
              splashRadius: 24,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationGroup(NavigationGroup group, ThemeData theme) {
    if (!_isSidebarExpanded) {
      // Version compacte (juste les icônes)
      return Column(
        children: [
          ...group.items.map((item) => _buildNavItemCompact(item, theme)),
          const SizedBox(height: 8),
          Divider(
            color: theme.dividerColor.withValues(alpha: 0.1),
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            group.title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...group.items.map((item) => _buildNavItem(item, theme)),
      ],
    );
  }

  Widget _buildNavItem(NavigationItem item, ThemeData theme) {
    final isSelected = _selectedIndex == item.index;
    final primaryColor = item.color ?? _itemAccentColor(context, item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = item.index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.1)
                  : theme.colorScheme.surface.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : theme.colorScheme.surface.withValues(alpha: 0),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemCompact(NavigationItem item, ThemeData theme) {
    final isSelected = _selectedIndex == item.index;
    final primaryColor = item.color ?? _itemAccentColor(context, item);

    return Tooltip(
      message: item.title,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = item.index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.1)
                    : theme.colorScheme.surface.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.2)
                      : theme.colorScheme.surface.withValues(alpha: 0),
                  width: 1,
                ),
              ),
              child: Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? primaryColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(
      BuildContext context, AdminAuthService adminAuth, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: _isSidebarExpanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (adminAuth.currentAdmin?.name ?? 'A')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminAuth.currentAdmin?.name ?? 'Admin',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        adminAuth.currentRole?.name ?? 'Rôle',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: theme.colorScheme.error,
                  onPressed: () => _logout(context),
                  tooltip: 'Déconnexion',
                ),
              ],
            )
          : IconButton(
              icon: Icon(
                _isSidebarExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
              ),
              onPressed: () =>
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            ),
    );
  }

  // ===========================================================================
  // APP BAR (DESKTOP)
  // ===========================================================================

  Widget _buildModernAppBar(
      BuildContext context, AdminAuthService adminAuth, ThemeData theme) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getCurrentTitle(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bienvenue sur votre espace d\'administration',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildAppBarAction(
            context,
            icon: Icons.search,
            tooltip: 'Recherche globale',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildAppBarAction(
            context,
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            hasBadge: true,
            onTap: () => _showNotifications(context),
          ),
          const SizedBox(width: 12),
          _buildAppBarAction(
            context,
            icon: Icons.settings_outlined,
            tooltip: 'Paramètres',
            onTap: () => _showSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                if (hasBadge)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE UI
  // ===========================================================================

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    return AppBar(
      title: Text(
        _getCurrentTitle(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotifications(context),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav(ThemeData theme) {
    final sem = AdminColorTokens.semantic(theme.colorScheme);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _mobileNavItems.map((item) {
              final isSelected = _selectedIndex == item.index;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = item.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    final scheme = theme.colorScheme;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: scheme.onPrimary.withValues(alpha: 0.18),
              child: Text(
                (adminAuth.currentAdmin?.name ?? 'A')
                    .substring(0, 1)
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            accountName: Text(
              adminAuth.currentAdmin?.name ?? 'Admin',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              adminAuth.currentRole?.name ?? 'Rôle',
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._navigationGroups.map((group) {
                  return ExpansionTile(
                    title: Text(
                      group.title,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    initiallyExpanded: true,
                    children: group.items.map((item) {
                      return ListTile(
                        leading: Icon(
                          item.icon,
                          color: _selectedIndex == item.index
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: _selectedIndex == item.index
                                ? theme.colorScheme.primary
                                : null,
                            fontWeight: _selectedIndex == item.index
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                        selected: _selectedIndex == item.index,
                        onTap: () {
                          setState(() => _selectedIndex = item.index);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                }),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: Text('Déconnexion',
                      style: TextStyle(color: scheme.error)),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  void _showNotifications(BuildContext context) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _logout(BuildContext context) async {
    final adminAuth = Provider.of<AdminAuthService>(context, listen: false);
    await adminAuth.logoutAdmin();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/admin-login');
    }
  }
}

/// Wrapper pour garantir que le layout est prêt avant les interactions
class _SafeScreenWrapper extends StatefulWidget {
  final Widget child;

  const _SafeScreenWrapper({required this.child});

  @override
  State<_SafeScreenWrapper> createState() => _SafeScreenWrapperState();
}

class _SafeScreenWrapperState extends State<_SafeScreenWrapper> {
  bool _hasLayout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hasLayout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        if (!_hasLayout) {
          return IgnorePointer(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: widget.child,
            ),
          );
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: widget.child,
        );
      },
    );
  }
}
