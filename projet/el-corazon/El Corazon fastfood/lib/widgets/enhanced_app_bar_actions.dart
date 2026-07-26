import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';

/// Widget amélioré pour le bouton de notification dans l'AppBar
class EnhancedNotificationButton extends StatefulWidget {
  final Color? iconColor;
  final double iconSize;

  const EnhancedNotificationButton({
    super.key,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  State<EnhancedNotificationButton> createState() =>
      _EnhancedNotificationButtonState();
}

class _EnhancedNotificationButtonState
    extends State<EnhancedNotificationButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationDatabaseService>(
      builder: (context, notificationService, child) {
        final unreadCount = notificationService.unreadCount;
        final hasNotifications = unreadCount > 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.navigateToNotifications(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: hasNotifications ? _pulseAnimation.value : 1.0,
                          child: Icon(
                            hasNotifications
                                ? Icons.notifications_active
                                : Icons.notifications_outlined,
                            color: widget.iconColor ?? Colors.white,
                            size: widget.iconSize,
                          ),
                        );
                      },
                    ),
                    if (hasNotifications)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.error,
                                      AppColors.errorLight,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99
                                        ? '99+'
                                        : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget amélioré pour le bouton de panier dans l'AppBar
class EnhancedCartButton extends StatefulWidget {
  final Color? iconColor;
  final double iconSize;

  const EnhancedCartButton({
    super.key,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  State<EnhancedCartButton> createState() => _EnhancedCartButtonState();
}

class _EnhancedCartButtonState extends State<EnhancedCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerBounce() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartService>(
      builder: (context, cartService, child) {
        final itemCount = cartService.itemCount;
        final hasItems = itemCount > 0;

        // Déclencher l'animation quand le nombre d'items change
        if (hasItems && _animationController.status != AnimationStatus.forward) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _triggerBounce();
            }
          });
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.navigateToCart(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: hasItems ? _bounceAnimation.value : 1.0,
                          child: Icon(
                            hasItems
                                ? Icons.shopping_cart
                                : Icons.shopping_cart_outlined,
                            color: widget.iconColor ?? Colors.white,
                            size: widget.iconSize,
                          ),
                        );
                      },
                    ),
                    if (hasItems)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.secondary,
                                AppColors.secondaryLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              itemCount > 99 ? '99+' : itemCount.toString(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
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
      },
    );
  }
}

/// Widget combiné pour les actions de l'AppBar (notification + panier)
class EnhancedAppBarActions extends StatelessWidget {
  final Color? iconColor;
  final double iconSize;
  final bool showNotification;
  final bool showCart;

  const EnhancedAppBarActions({
    super.key,
    this.iconColor,
    this.iconSize = 24,
    this.showNotification = true,
    this.showCart = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showNotification) ...[
          const EnhancedNotificationButton(),
          const SizedBox(width: 4),
        ],
        if (showCart) const EnhancedCartButton(),
      ],
    );
  }
}











