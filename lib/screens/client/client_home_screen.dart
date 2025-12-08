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
import 'package:elcora_fast/screens/client/widgets/quick_actions_widget.dart';
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
  late AnimationController _floatingController;
  late PageController _highlightController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;
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
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeInOut,
    ),);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ),);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    ),);

    // Animation flottante pour les éléments décoratifs
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ),);

    // Démarrer les animations
    _mainController.forward();
    _floatingController.repeat(reverse: true);

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
    _floatingController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
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
    );
  }

  Widget _buildEnhancedAppBar() {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'El Corazón',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.secondary,
                AppColors.tertiary,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Éléments décoratifs animés
              Positioned(
                top: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _floatingAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 10 * _floatingAnimation.value),
                      child: Icon(
                        Icons.restaurant,
                        size: 40,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: AnimatedBuilder(
                  animation: _floatingAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -10 * _floatingAnimation.value),
                      child: Icon(
                        Icons.local_pizza,
                        size: 30,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    );
                  },
                ),
              ),
              // Message de bienvenue
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Consumer<AppService>(
                  builder: (context, appService, child) {
                    return Text(
                      'Bonjour ${appService.currentUser?.name ?? 'Client'}!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
        description:
            'Laissez-vous surprendre par nos créations du chef, préparées chaque jour.',
        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        illustration:
            const Icon(Icons.restaurant, color: Colors.white, size: 72),
        onPressed: () => widget.onNavigateToTab?.call(1),
      ),
      HomeHighlightCard(
        title: 'Gâteaux personnalisés',
        description:
            'Designs uniques, message personnalisé, livraison planifiée.',
        colors: const [Color(0xFFF48FB1), Color(0xFF880E4F)],
        illustration: const Icon(Icons.cake, color: Colors.white, size: 72),
        onPressed: () => context.navigateToCakeOrder(),
      ),
      HomeHighlightCard(
        title: 'Offres fidélité',
        description: 'Échangez vos points pour des remises exceptionnelles.',
        colors: const [Color(0xFF42A5F5), Color(0xFF0D47A1)],
        illustration:
            const Icon(Icons.card_giftcard, color: Colors.white, size: 72),
        onPressed: () => context.navigateToRewards(),
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
                        : theme.colorScheme.primary.withOpacity(0.3),
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
    final listHeight = isSmallScreen ? 240.0 : 260.0;

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
                          id: item.id,
                          name: item.name,
                          description: item.description,
                          price: item.price,
                          imageUrl: item.imageUrl,
                          isPopular: item.isPopular,
                          isVegetarian: item.isVegetarian,
                          isVegan: item.isVegan,
                          onTap: () =>
                              context.navigateToItemCustomization(item),
                          onAddToCart: () {
                            Provider.of<CartService>(context, listen: false)
                                .addItem(item);
                            context.showSuccessMessage(
                                '${item.name} ajouté au panier !',);
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
    final listHeight = isSmallScreen ? 240.0 : 260.0;

    return SliverToBoxAdapter(
      child: Consumer<AIRecommendationService>(
        builder: (context, aiService, child) {
          // Obtenir les recommandations basées sur les produits populaires
          final recommendations = aiService
              .getRecommendationsForUser('current_user')
              .where((item) => item.isPopular && item.rating > 4.0)
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
                              id: item.id,
                              name: item.name,
                              description: item.description,
                              price: item.price,
                              imageUrl: item.imageUrl,
                              isPopular: item.isPopular,
                              isVegetarian: item.isVegetarian,
                              isVegan: item.isVegan,
                              onTap: () =>
                                  context.navigateToItemCustomization(item),
                              onAddToCart: () {
                                Provider.of<CartService>(context, listen: false)
                                    .addItem(item);
                                context.showSuccessMessage(
                                    '${item.name} ajouté au panier !',);
                              },
                              onFavoriteTap: () {
                                favoritesService.toggleFavorite(item);
                                if (isFavorite) {
                                  context.showSuccessMessage(
                                      '${item.name} retiré des favoris',);
                                } else {
                                  context.showSuccessMessage(
                                      '${item.name} ajouté aux favoris',);
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
    final listHeight = isSmallScreen ? 200.0 : 220.0;

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
                          id: item.id,
                          name: item.name,
                          description: item.description,
                          price: item.price,
                          imageUrl: item.imageUrl,
                          isPopular: item.isPopular,
                          isVegetarian: item.isVegetarian,
                          isVegan: item.isVegan,
                          onTap: () =>
                              context.navigateToItemCustomization(item),
                          onAddToCart: () {
                            Provider.of<CartService>(context, listen: false)
                                .addItem(item);
                            context.showSuccessMessage(
                                '${item.name} ajouté au panier !',);
                          },
                          onFavoriteTap: () {
                            favoritesService.removeFromFavorites(item);
                            context.showSuccessMessage(
                                '${item.name} retiré des favoris',);
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
