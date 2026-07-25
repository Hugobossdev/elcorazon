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

    Widget logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icône principale avec moto de livraison
        Container(
          width: size,
          height: size * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: logoColor.withValues(alpha: 0.3),
                blurRadius: size * 0.1,
                offset: Offset(0, size * 0.05),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arrière-plan stylisé
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.2),
                    gradient: LinearGradient(
                      colors: [
                        Colors.yellow.withValues(alpha: 0.3),
                        Colors.orange.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
              // Icône de livraison
              Icon(
                Icons.delivery_dining,
                size: size * 0.4,
                color: Colors.white,
              ),
              // Cœur en overlay
              Positioned(
                top: size * 0.1,
                right: size * 0.1,
                child: Icon(
                  Icons.favorite,
                  size: size * 0.15,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.15),
          // Texte du logo
          Text(
            'EL CORAZON DELY',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: logoColor,
              letterSpacing: 2,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: size * 0.05),
          Text(
            'L\'AMOUR, NOTRE INGRÉDIENT SECRET',
            style: TextStyle(
              fontSize: size * 0.1,
              color: logoColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
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
            child: Opacity(
              opacity: value,
              child: logo,
            ),
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
    super.key,
    required this.title,
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
              child: Container(
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      size: 20,
                      color: Colors.white,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.favorite,
                        size: 8,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
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
  late AnimationController _rotationController;
  late AnimationController _heartController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _heartAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));

    // Démarrer les animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _rotationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _heartController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_scaleAnimation, _rotationAnimation, _heartAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo principal animé
              Container(
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotation de la moto de livraison
                    Transform.rotate(
                      angle: _rotationAnimation.value * 0.1,
                      child: Icon(
                        Icons.delivery_dining,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    // Cœur animé
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Transform.scale(
                        scale: _heartAnimation.value,
                        child: Icon(
                          Icons.favorite,
                          size: 20,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Texte du logo
              Text(
                'EL CORAZON DELY',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'L\'AMOUR, NOTRE INGRÉDIENT SECRET',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
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
