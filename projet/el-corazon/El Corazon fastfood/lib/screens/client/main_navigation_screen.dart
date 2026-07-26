import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
// import 'package:elcora_fast/widgets/offline_indicator.dart';
import 'package:elcora_fast/screens/client/client_home_screen.dart';
import 'package:elcora_fast/screens/client/menu_screen.dart';
import 'package:elcora_fast/screens/client/orders_screen.dart';
import 'package:elcora_fast/screens/client/profile_screen.dart';
import 'package:elcora_fast/screens/guest_welcome_screen.dart';
import 'package:elcora_fast/screens/guest_contact_screen.dart';

/// Écran de navigation principal pour les clients
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Gérer le bouton retour système
  void _handleSystemBack() {
    // Si on est sur l'onglet Accueil (0), sortir de l'app ou aller à l'auth
    if (_currentIndex == 0) {
      // Optionnel: demander confirmation avant de sortir
      // Pour l'instant, on ne fait rien (l'app reste ouverte)
      debugPrint('Retour système ignoré sur l\'onglet Accueil');
    } else {
      // Revenir à l'onglet Accueil
      setState(() {
        _currentIndex = 0;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        // Mode Invité ou Utilisateur Connecté
        // On permet l'accès même si pas connecté

        // Note: Cette application est uniquement destinée aux clients.
        // Les utilisateurs admin et delivery doivent utiliser leurs applications dédiées.

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _handleSystemBack();
            }
          },
          child: Scaffold(
            body: Column(
              children: [
                // Indicateur de statut de connexion supprimé
                // const OfflineIndicator(),
                // Contenu principal
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Empêcher le swipe
                    onPageChanged: (index) {
                      debugPrint(
                        'MainNavigationScreen: Page changed to index $index',
                      );
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: [
                      // Onglet 0: Accueil
                      if (appService.isLoggedIn)
                        ClientHomeScreen(
                          onNavigateToTab: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        )
                      else
                        GuestWelcomeScreen(
                          onNavigateToTab: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),

                      // Onglet 1: Menu (Commun)
                      const MenuScreen(),

                      // Onglets suivants dépendent du statut
                      if (appService.isLoggedIn) ...[
                        // Onglet 2 (Loggé): Commandes
                        const OrdersScreen(),
                        // Onglet 3 (Loggé): Profil
                        const ProfileScreen(),
                      ] else ...[
                        // Onglet 2 (Invité): Contact
                        const GuestContactScreen(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomNavigationBar(appService),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(AppService appService) {
    final bool isLoggedIn = appService.isLoggedIn;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        boxShadow: DesignConstants.shadowHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppColors.textTertiary.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Accueil',
                index: 0,
                isActive: _currentIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.restaurant_menu_outlined,
                activeIcon: Icons.restaurant_menu_rounded,
                label: 'Menu',
                index: 1,
                isActive: _currentIndex == 1,
              ),
              if (isLoggedIn) ...[
                _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Commandes',
                  index: 2,
                  isActive: _currentIndex == 2,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                  index: 3,
                  isActive: _currentIndex == 3,
                ),
              ] else ...[
                _buildNavItem(
                  icon: Icons.contact_support_outlined,
                  activeIcon: Icons.contact_support_rounded,
                  label: 'Contact',
                  index: 2,
                  isActive: _currentIndex == 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        _pageController.animateToPage(
          index,
          duration: DesignConstants.animationNormal,
          curve: DesignConstants.curveStandard,
        );
      },
      child: Container(
        color: Colors.transparent, // Zone de touche étendue
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: DesignConstants.animationFast,
              curve: DesignConstants.curveStandard,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: AppColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isActive ? DesignConstants.shadowPrimary : null,
              ),
              child: AnimatedSwitcher(
                duration: DesignConstants.animationFast,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color:
                      isActive ? AppColors.textLight : AppColors.textSecondary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: DesignConstants.animationFast,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
