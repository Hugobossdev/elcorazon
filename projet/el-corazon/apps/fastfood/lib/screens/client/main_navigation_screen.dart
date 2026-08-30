import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
// import 'package:elcora_fast/widgets/offline_indicator.dart';
import 'package:elcora_fast/screens/client/client_home_screen.dart';
import 'package:elcora_fast/screens/client/menu_screen.dart';
import 'package:elcora_fast/screens/client/orders_screen.dart';
import 'package:elcora_fast/screens/client/profile_screen.dart';
import 'package:elcora_fast/screens/guest_welcome_screen.dart';
import 'package:elcora_fast/screens/guest_contact_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

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
      Journal.trace('Retour système ignoré sur l\'onglet Accueil');
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
                      Journal.trace(
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

  /// Barre de navigation translucide, avec le panier flottant en son centre.
  ///
  /// ## Ce que la maquette impose, et ce que l'application impose
  ///
  /// La maquette place cinq destinations autour d'un bouton panier surélevé.
  /// L'application n'en a que quatre — et trois pour un visiteur non connecté,
  /// qui n'a ni commandes ni profil. Les onglets **ne changent donc pas** :
  /// c'est la barre qui s'adapte, en répartissant ce qui existe de part et
  /// d'autre du panier.
  ///
  /// ## Pourquoi le panier n'est pas un onglet
  ///
  /// Parce qu'il n'en est pas un : il ouvre un écran par-dessus la pile, dont
  /// on revient là d'où l'on vient. En faire une destination l'aurait rendu
  /// impossible à quitter sans en choisir une autre — ce qui est précisément
  /// le piège que les écrans de règlement doivent éviter.
  Widget _buildBottomNavigationBar(AppService appService) {
    final theme = Theme.of(context);
    final bool isLoggedIn = appService.isLoggedIn;

    const aGauche = [
      _Destination(
        icone: Icons.home_outlined,
        iconeActive: Icons.home_rounded,
        libelle: 'Accueil',
        index: 0,
      ),
      _Destination(
        icone: Icons.restaurant_menu_outlined,
        iconeActive: Icons.restaurant_menu_rounded,
        libelle: 'Menu',
        index: 1,
      ),
    ];

    final aDroite = isLoggedIn
        ? const [
            _Destination(
              icone: Icons.receipt_long_outlined,
              iconeActive: Icons.receipt_long_rounded,
              libelle: 'Commandes',
              index: 2,
            ),
            _Destination(
              icone: Icons.person_outline_rounded,
              iconeActive: Icons.person_rounded,
              libelle: 'Profil',
              index: 3,
            ),
          ]
        : const [
            _Destination(
              icone: Icons.contact_support_outlined,
              iconeActive: Icons.contact_support_rounded,
              libelle: 'Contact',
              index: 2,
            ),
          ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlur,
          sigmaY: AppColors.glassBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            boxShadow: DesignConstants.shadowBottomBar,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              // Assez haut pour l'icône, son libellé et la pastille active,
              // sans dépendre de la taille de l'appareil.
              height: 64,
              child: Row(
                children: [
                  for (final destination in aGauche)
                    Expanded(child: _construireDestination(destination)),
                  _PanierFlottant(onTap: () => context.navigateToCart()),
                  for (final destination in aDroite)
                    Expanded(child: _construireDestination(destination)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construireDestination(_Destination destination) {
    final theme = Theme.of(context);
    final actif = _currentIndex == destination.index;

    return Semantics(
      button: true,
      selected: actif,
      label: destination.libelle,
      child: InkWell(
        onTap: () {
          setState(() => _currentIndex = destination.index);
          _pageController.animateToPage(
            destination.index,
            duration: DesignConstants.animationNormal,
            curve: DesignConstants.curveStandard,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // La pastille colorée derrière l'icône active est le marqueur de
            // sélection de Material 3, et le seul que retienne la maquette.
            // Le dégradé plein d'avant faisait de chaque onglet un bouton
            // d'action, alors qu'une destination n'en est pas une.
            AnimatedContainer(
              duration: DesignConstants.animationFast,
              curve: DesignConstants.curveStandard,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
              decoration: BoxDecoration(
                color: actif
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                actif ? destination.iconeActive : destination.icone,
                size: 22,
                color: actif
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                destination.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLg(
                  color: actif
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ).copyWith(letterSpacing: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une destination de la barre. Simple porteur de données : la barre en
/// construit deux listes, et la logique de rendu reste au même endroit.
class _Destination {
  const _Destination({
    required this.icone,
    required this.iconeActive,
    required this.libelle,
    required this.index,
  });

  final IconData icone;
  final IconData iconeActive;
  final String libelle;
  final int index;
}

/// Le bouton panier, surélevé au centre de la barre.
///
/// Il déborde vers le haut (`Transform.translate`) au lieu d'agrandir la
/// barre : la maquette le veut posé **sur** la barre, à cheval sur le contenu
/// qui défile. L'ombre de 8 dp fait le reste du travail de séparation — c'est
/// le seul endroit où le design system en demande une aussi marquée.
class _PanierFlottant extends StatelessWidget {
  const _PanierFlottant({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<CartService>(
      builder: (context, cartService, child) {
        final nombre = cartService.itemCount;

        return SizedBox(
          width: 72,
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Semantics(
                    button: true,
                    label: nombre == 0
                        ? 'Panier, vide'
                        : 'Panier, $nombre article${nombre > 1 ? 's' : ''}',
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 8,
                      shadowColor:
                          theme.colorScheme.primary.withValues(alpha: 0.4),
                      child: InkWell(
                        onTap: onTap,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(
                            Icons.shopping_cart_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (nombre > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 22, minHeight: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            nombre > 99 ? '99+' : '$nombre',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
