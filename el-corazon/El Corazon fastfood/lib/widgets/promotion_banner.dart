import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/services/promotion_service.dart';

class PromotionBanner extends StatefulWidget {
  const PromotionBanner({super.key});

  @override
  State<PromotionBanner> createState() => _PromotionBannerState();
}

class _PromotionBannerState extends State<PromotionBanner>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    _startAutoSlide();
    
    // Charger les promotions depuis la base de données
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final promotionService = Provider.of<PromotionService>(context, listen: false);
      if (promotionService.promotions.isEmpty) {
        promotionService.refresh();
      }
    });
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        final promotionService = Provider.of<PromotionService>(context, listen: false);
        final activePromotions = promotionService.activePromotions;
        if (activePromotions.isNotEmpty) {
          _nextPromotion(activePromotions.length);
        }
        _startAutoSlide();
      }
    });
  }

  void _nextPromotion(int maxLength) {
    if (maxLength == 0) return;
    _currentIndex = (_currentIndex + 1) % maxLength;
    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
  
  Color _getColorForPromotion(int index) {
    final colors = [
      [Colors.red, Colors.orange],
      [Colors.blue, Colors.indigo],
      [Colors.green, Colors.teal],
      [Colors.purple, Colors.deepPurple],
      [Colors.orange, Colors.deepOrange],
      [Colors.pink, Colors.purple],
    ];
    return colors[index % colors.length][0];
  }
  
  List<Color> _getGradientForPromotion(int index) {
    final gradients = [
      [Colors.red, Colors.orange],
      [Colors.blue, Colors.indigo],
      [Colors.green, Colors.teal],
      [Colors.purple, Colors.deepPurple],
      [Colors.orange, Colors.deepOrange],
      [Colors.pink, Colors.purple],
    ];
    return gradients[index % gradients.length];
  }
  
  String _getDiscountText(Promotion promotion) {
    switch (promotion.discountType) {
      case 'percentage':
        return '${promotion.discountValue.toInt()}% de réduction';
      case 'fixed':
        return '${promotion.discountValue.toInt()} FCFA de réduction';
      case 'free_delivery':
        return 'Livraison gratuite';
      default:
        return 'Offre spéciale';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PromotionService>(
      builder: (context, promotionService, child) {
        final activePromotions = promotionService.activePromotions.take(5).toList();
        
        if (activePromotions.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Réinitialiser l'index si nécessaire
        if (_currentIndex >= activePromotions.length) {
          _currentIndex = 0;
        }
        
        return Container(
          height: 160,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: activePromotions.length,
                itemBuilder: (context, index) {
                  final promotion = activePromotions[index];
                  return _buildPromotionCard(promotion, index);
                },
              ),

              // Indicateurs de pages
              if (activePromotions.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: activePromotions.asMap().entries.map((entry) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentIndex == entry.key ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentIndex == entry.key
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromotionCard(Promotion promotion, int index) {
    final color = _getColorForPromotion(index);
    final gradient = _getGradientForPromotion(index);
    final discountText = _getDiscountText(promotion);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Motif de fond
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Contenu principal
              Positioned(
                left: 20,
                top: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      promotion.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      discountText,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      promotion.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Code promo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Code: ${promotion.promoCode}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copyPromoCode(promotion.promoCode),
                            child: const Icon(
                              Icons.copy,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bouton d'action
              Positioned(
                right: 20,
                top: 20,
                bottom: 20,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _usePromotion(promotion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Utiliser',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyPromoCode(String code) {
    // Implémenter la copie du code promo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copié!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _usePromotion(Promotion promotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(promotion.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(promotion.description),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Code: ${promotion.promoCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPromoCode(promotion.promoCode),
                    icon: const Icon(Icons.copy),
                    iconSize: 18,
                  ),
                ],
              ),
            ),
            if (promotion.minOrderAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Montant minimum: ${promotion.minOrderAmount.toInt()} FCFA',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Naviguer vers le menu ou la commande
              // Vous pouvez ajouter la navigation ici
            },
            child: const Text('Commander'),
          ),
        ],
      ),
    );
  }
}
