import 'package:flutter/material.dart';

class ElCorazonLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;
  final bool animated;

  const ElCorazonLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.color,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? Theme.of(context).colorScheme.primary;

    final Widget logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo image
        Image.asset(
          'lib/assets/logo/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback si l'image ne charge pas
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: logoColor,
                borderRadius: BorderRadius.circular(size * 0.2),
                boxShadow: [
                  BoxShadow(
                    color: logoColor.withValues(alpha: 0.3),
                    blurRadius: size * 0.1,
                    offset: Offset(0, size * 0.05),
                  ),
                ],
              ),
              child: Icon(
                Icons.restaurant_rounded,
                size: size * 0.5,
                color: Colors.white,
              ),
            );
          },
        ),
        if (showText) ...[
          SizedBox(height: size * 0.15),
          // Texte du logo
          Text(
            'El corazon',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: logoColor,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'L\'amour, notre ingrédient secret',
            style: TextStyle(
              fontSize: size * 0.1,
              color: logoColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value, child: logo),
          );
        },
      );
    }

    return logo;
  }
}

class ElCorazonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;
  final VoidCallback? onLogoTap;

  const ElCorazonAppBar({
    required this.title,
    super.key,
    this.actions,
    this.showLogo = true,
    this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          if (showLogo) ...[
            GestureDetector(
              onTap: onLogoTap,
              child: Image.asset(
                'lib/assets/logo/logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      actions: actions,
      elevation: 2,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ElCorazonSplashLogo extends StatefulWidget {
  const ElCorazonSplashLogo({super.key});

  @override
  State<ElCorazonSplashLogo> createState() => _ElCorazonSplashLogoState();
}

class _ElCorazonSplashLogoState extends State<ElCorazonSplashLogo>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Démarrer l'animation
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo image
              Image.asset(
                'lib/assets/logo/logo.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Texte du logo
              Text(
                'El corazon',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'L\'amour, notre ingrédient secret',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
