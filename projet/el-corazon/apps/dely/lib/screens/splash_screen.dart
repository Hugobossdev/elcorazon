import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/screens/driver_gate.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.sessionReady});

  /// Résolu quand `sessionProvider.restoreSession()` (Phase 6) a fini de
  /// décider si un jeton valide était stocké — voir `main()`. `null` par
  /// défaut pour que `const SplashScreen()` reste utilisable (l'extension
  /// `showSplashScreen()` ci-dessous, notamment) ; dans ce cas, l'écran
  /// n'attend rien de spécial avant d'interroger `AppService`.
  final Future<void>? sessionReady;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );
  }

  void _startSplashSequence() async {
    // Start logo animation
    unawaited(_logoController.forward());

    // Initialize AppService while splash is showing
    final initFuture = _initializeAppService();

    // Wait a bit, then start text animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    unawaited(_textController.forward());

    // Wait for total splash duration (minimum)
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;

    // Ensure initialization is complete before navigating
    await initFuture;

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _initializeAppService() async {
    try {
      // Attend que la session Django (Phase 6) soit restaurée — sinon
      // `AppService.initialize()` lirait un `_currentUser` pas encore à
      // jour et enverrait un livreur déjà connecté vers l'écran de
      // connexion.
      await widget.sessionReady;
      if (!mounted) return;

      final appService = context.read<AppService>();
      if (!appService.isInitialized) {
        await appService.initialize();
      }
    } catch (e) {
      Journal.trace('Error initializing AppService in Splash: $e');
    }
  }

  /// Cède la main à [DriverGate], qui décide — et continue de décider.
  ///
  /// Cet écran choisissait lui-même entre l'accueil et la connexion. C'était
  /// un second endroit où lire l'état de la session, donc un second endroit où
  /// en oublier un cas : le compte non vérifié y entrait comme n'importe quel
  /// autre. La porte fait cette lecture une fois, et la refait à chaque
  /// changement — ce qu'une décision prise au démarrage ne peut pas faire.
  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DriverGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha: 0.8),
              theme.colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animation
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        size: 60,
                        color: Colors.red,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Text animations
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _textAnimation,
                      child: Column(
                        children: [
                          // App name
                          Text(
                            'El Corazon Dely',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tagline
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              'Ton repas à la vitesse de ta faim',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),

              // Loading indicator
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textAnimation,
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension for easier usage
extension SplashScreenExtension on BuildContext {
  void showSplashScreen() {
    Navigator.of(this).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
    );
  }
}
