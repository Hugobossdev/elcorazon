import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/enhanced_app_bar_actions.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
import 'package:elcora_fast/screens/client/widgets/quick_actions_widget.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/screens/client/widgets/home_section_header.dart';
import 'package:elcora_fast/screens/client/widgets/home_highlight_card.dart';

/// Écran d'accueil client
class ClientHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const ClientHomeScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late PageController _highlightController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  int _currentHighlightPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Animation principale
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    // Démarrer les animations
    _mainController.forward();

    _highlightController = PageController(viewportFraction: 0.88);
    _highlightController.addListener(() {
      final page = _highlightController.page?.round() ?? 0;
      if (page != _currentHighlightPage) {
        setState(() => _currentHighlightPage = page);
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.surfaceVariant.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: CustomScrollView(
                slivers: [
                  _buildEnhancedAppBar(),
                  _buildHeroSection(),
                  _buildQuickActions(),
                  _buildAIRecommendations(context),
                  _buildFavoritesSection(context),
                  _buildFeaturedItems(context),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Petit logo dans l'AppBar quand réduit
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/logo/logo.png',
                height: 24,
                width: 24,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'El Corazón',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Fond dégradé de base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            // Cercles décoratifs
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: 20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Effet Glassmorphism par dessus
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            // Message de bienvenue
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: Consumer<AppService>(
                builder: (context, appService, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bonjour ${appService.currentUser?.fullName ?? 'Gourmand'} !',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Que voulez-vous manger ?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: const [
        EnhancedAppBarActions(),
      ],
    );
  }

  Widget _buildHeroSection() {
    final theme = Theme.of(context);
    final highlightCards = [
      HomeHighlightCard(
        title: 'Menu Signature',
        description: 'Découvrez nos créations exclusives du chef.',
        colors: AppColors.primaryGradient,
        illustration:
            const Icon(Icons.restaurant_menu, color: Colors.white, size: 64),
        onPressed: () => widget.onNavigateToTab?.call(1),
      ),
      HomeHighlightCard(
        title: 'Commandes Groupées',
        description: 'Commandez ensemble et partagez les frais de livraison.',
        colors: const [
          Color(0xFF6C5CE7), // Violet
          Color(0xFFA29BFE), // Violet clair
        ],
        illustration: const Icon(Icons.group, color: Colors.white, size: 64),
        onPressed: () {
          final appService = Provider.of<AppService>(context, listen: false);
          if (appService.isLoggedIn) {
            context.navigateToGroupOrder();
          } else {
            NavigationService.navigateToAuth(context);
          }
        },
      ),
      HomeHighlightCard(
        title: 'Livraison Rapide',
        description: 'Vos plats préférés livrés en un éclair.',
        colors: AppColors.secondaryGradient,
        illustration:
            const Icon(Icons.delivery_dining, color: Colors.white, size: 64),
        onPressed: () => widget.onNavigateToTab?.call(2),
      ),
      HomeHighlightCard(
        title: 'Récompenses',
        description: 'Cumulez des points à chaque commande.',
        colors: AppColors.successGradient,
        illustration: const Icon(Icons.stars, color: Colors.white, size: 64),
        onPressed: () {
          final appService = Provider.of<AppService>(context, listen: false);
          if (appService.isLoggedIn) {
            context.navigateToRewards();
          } else {
            NavigationService.navigateToAuth(context);
          }
        },
      ),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HomeSectionHeader(
                title: 'Bienvenue chez El Corazón',
                subtitle: 'Votre moment gourmand livré avec passion',
                actionLabel: 'Explorer le menu',
                onActionPressed: () => widget.onNavigateToTab?.call(1),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _highlightController,
                itemCount: highlightCards.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _highlightController,
                    builder: (context, child) {
                      final isActive = index == _currentHighlightPage;
                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.only(
                          right: 16,
                          left: index == 0 ? 16 : 0,
                          top: isActive ? 0 : 12,
                          bottom: isActive ? 0 : 12,
                        ),
                        child: child,
                      );
                    },
                    child: highlightCards[index],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(highlightCards.length, (index) {
                final isActive = index == _currentHighlightPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: 'Actions rapides',
              subtitle: 'Vos raccourcis préférés à portée de main',
            ),
            SizedBox(height: 12),
            QuickActionsWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedItems(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final cardWidth = isSmallScreen ? 170.0 : 190.0;
    // Hauteur **demandée par la carte** pour cette largeur et l'échelle de
    // police en vigueur, marge basse comprise. Les 240/260 px ronds
    // d'avant écrasaient le nom, le prix et le bouton d'ajout sous le
    // bandeau de débordement dès la taille de police par défaut.
    final listHeight = MenuItemCard.hauteurPour(context, cardWidth) +
        (isSmallScreen ? 4 : 8);

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeader(
              title: 'Plats à la une',
              subtitle: 'Sélectionnés pour vous',
              actionLabel: 'Tout voir',
              onActionPressed: () => widget.onNavigateToTab?.call(1),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Consumer<AppService>(
              builder: (context, appService, child) {
                final featuredItems = appService.menuItems
                    .where((item) => item.isPopular)
                    .take(3)
                    .toList();

                if (featuredItems.isEmpty) {
                  return DesignEnhancementService.createEnhancedCard(
                    child: const Center(
                      child: Text('Aucun plat populaire disponible'),
                    ),
                  );
                }

                return SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: featuredItems.length,
                    itemBuilder: (context, index) {
                      final item = featuredItems[index];
                      return Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          right: isSmallScreen ? 12 : 16,
                          bottom: isSmallScreen ? 4 : 8,
                        ),
                        child:
                            DesignEnhancementService.createEnhancedMenuItemCard(
                          item: item,
                          onTap: () =>
                              context.navigateToItemCustomization(item),
                          onAddToCart: () {
                            Provider.of<CartService>(context, listen: false)
                                .addItem(item);
                            context.showSuccessMessage(
                              '${item.name} ajouté au panier !',
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendations(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final cardWidth = isSmallScreen ? 170.0 : 190.0;
    // Hauteur **demandée par la carte** pour cette largeur et l'échelle de
    // police en vigueur, marge basse comprise. Les 240/260 px ronds
    // d'avant écrasaient le nom, le prix et le bouton d'ajout sous le
    // bandeau de débordement dès la taille de police par défaut.
    final listHeight = MenuItemCard.hauteurPour(context, cardWidth) +
        (isSmallScreen ? 4 : 8);

    return SliverToBoxAdapter(
      child: Consumer2<AIRecommendationService, AppService>(
        builder: (context, aiService, appService, child) {
          // L'identifiant **du compte connecté**, et non la chaîne
          // `'current_user'` : les suggestions sont rangées sous l'identifiant
          // avec lequel elles ont été calculées, si bien que cette clé
          // inventée ne désignait jamais rien. La section restait vide quoi
          // qu'il arrive.
          final identifiant = appService.currentUser?.id;
          if (identifiant == null) return const SizedBox.shrink();

          // Obtenir les recommandations basées sur les produits populaires
          final recommendations = aiService
              .getRecommendationsForUser(identifiant)
              .where((item) => item.isPopular && item.ratingAverage > 4.0)
              .take(3)
              .toList();

          if (recommendations.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeSectionHeader(
                  title: 'Nos suggestions',
                  subtitle: 'Inspirées de vos commandes récentes',
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final item = recommendations[index];
                      return Consumer<FavoritesService>(
                        builder: (context, favoritesService, child) {
                          final isFavorite = favoritesService.isFavorite(item);
                          return Container(
                            width: cardWidth,
                            margin: EdgeInsets.only(
                              right: isSmallScreen ? 12 : 16,
                              bottom: isSmallScreen ? 4 : 8,
                            ),
                            child: DesignEnhancementService
                                .createEnhancedMenuItemCard(
                              item: item,
                              onTap: () =>
                                  context.navigateToItemCustomization(item),
                              onAddToCart: () {
                                Provider.of<CartService>(context, listen: false)
                                    .addItem(item);
                                context.showSuccessMessage(
                                  '${item.name} ajouté au panier !',
                                );
                              },
                              onFavoriteTap: () {
                                favoritesService.toggleFavorite(item);
                                if (isFavorite) {
                                  context.showSuccessMessage(
                                    '${item.name} retiré des favoris',
                                  );
                                } else {
                                  context.showSuccessMessage(
                                    '${item.name} ajouté aux favoris',
                                  );
                                }
                              },
                              isFavorite: isFavorite,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final cardWidth = isSmallScreen ? 160.0 : 180.0;
    // Hauteur **demandée par la carte** pour cette largeur et l'échelle de
    // police en vigueur, marge basse comprise. Les 240/260 px ronds
    // d'avant écrasaient le nom, le prix et le bouton d'ajout sous le
    // bandeau de débordement dès la taille de police par défaut.
    final listHeight = MenuItemCard.hauteurPour(context, cardWidth) +
        (isSmallScreen ? 4 : 8);

    return SliverToBoxAdapter(
      child: Consumer<FavoritesService>(
        builder: (context, favoritesService, child) {
          final favorites = favoritesService.favorites;

          if (favorites.isEmpty) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeSectionHeader(
                  title: 'Mes favoris ❤️',
                  subtitle:
                      '${favorites.length} plat${favorites.length > 1 ? 's' : ''} sauvegardé${favorites.length > 1 ? 's' : ''}',
                  actionLabel: favorites.isEmpty ? null : 'Voir tout',
                  onActionPressed: favorites.isEmpty
                      ? null
                      : () => widget.onNavigateToTab?.call(1),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final item = favorites[index];
                      return Container(
                        width: cardWidth,
                        margin: EdgeInsets.only(
                          right: isSmallScreen ? 12 : 16,
                          bottom: isSmallScreen ? 4 : 8,
                        ),
                        child:
                            DesignEnhancementService.createEnhancedMenuItemCard(
                          item: item,
                          onTap: () =>
                              context.navigateToItemCustomization(item),
                          onAddToCart: () {
                            Provider.of<CartService>(context, listen: false)
                                .addItem(item);
                            context.showSuccessMessage(
                              '${item.name} ajouté au panier !',
                            );
                          },
                          onFavoriteTap: () {
                            favoritesService.removeFromFavorites(item);
                            context.showSuccessMessage(
                              '${item.name} retiré des favoris',
                            );
                          },
                          isFavorite: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
