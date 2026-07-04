import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/performance_service.dart';
import 'package:elcora_fast/screens/client/main_navigation_screen.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
    _startSplashSequence();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startSplashSequence() async {
    // Initialize app services with performance monitoring
    await _initializeAppWithPerformance();

    // Ensure animation has enough time to be seen
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  /// Initialize app services with performance monitoring
  Future<void> _initializeAppWithPerformance() async {
    final performanceService = context.read<PerformanceService>();
    final errorHandler = context.read<ErrorHandlerService>();

    try {
      await performanceService.measureOperation('app_initialization', () async {
        final appService = context.read<AppService>();
        await appService.initialize();
      });
    } catch (e) {
      errorHandler.logError('Failed to initialize app', details: e.toString());
    }
  }

  void _navigateToNextScreen() {
    final appService = context.read<AppService>();

    try {
      if (appService.currentUser != null && appService.isLoggedIn) {
        // Utiliser le service de navigation pour naviguer vers l'écran approprié selon le rôle
        NavigationService.navigateBasedOnRole(context, appService.currentUser!);
      } else {
        // Naviguer vers l'écran d'accueil pour les invités (Mode Invité)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
        );
      }
    } catch (e) {
      // En cas d'erreur, rediriger vers l'authentification
      NavigationService.navigateToAuth(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _opacityAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo de l'application
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo/logo.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.restaurant_menu,
                              size: 100,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Loading indicator
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
