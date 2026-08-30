import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/main.dart' show sessionReadyFuture;
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/error_handler_service.dart';
import 'package:elcora_fast/services/performance_service.dart';
import 'package:elcora_fast/services/onboarding_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/screens/client/main_navigation_screen.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// Écran d'ouverture.
///
/// ## Ce qu'il fait pendant qu'il s'affiche
///
/// Trois choses, dans cet ordre : attendre que la session Django soit
/// restaurée, initialiser `AppService`, puis router selon le rôle. Rien de
/// tout cela n'a changé avec la refonte — seule la peinture est neuve.
///
/// ## Ce que montre la maquette
///
/// Un halo rouge diffus qui respire derrière un mot-symbole en italique, la
/// signature en petites capitales espacées, et trois points qui rebondissent
/// en bas. Pas de logo : le design system fait du nom lui-même la marque sur
/// cet écran, et une vignette de 180 px au centre d'un fond crème le
/// contredirait.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Apparition du contenu — le mot-symbole, puis la signature, puis les
  /// points, chacun décalé par un `Interval`.
  late AnimationController _apparition;

  /// Respiration du halo. Séparée de [_apparition] parce qu'elle **boucle** :
  /// les mêler obligerait à rejouer l'apparition à chaque battement.
  late AnimationController _halo;

  late Animation<double> _opaciteTitre;
  late Animation<double> _opaciteSignature;
  late Animation<double> _opacitePoints;
  late Animation<Offset> _monteeTitre;

  @override
  void initState() {
    super.initState();

    _apparition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _opaciteTitre = CurvedAnimation(
      parent: _apparition,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _opaciteSignature = CurvedAnimation(
      parent: _apparition,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _opacitePoints = CurvedAnimation(
      parent: _apparition,
      curve: const Interval(0.6, 1, curve: Curves.easeOut),
    );
    _monteeTitre = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _apparition,
        curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _apparition.forward();
    _startSplashSequence();
  }

  @override
  void dispose() {
    _apparition.dispose();
    _halo.dispose();
    super.dispose();
  }

  void _startSplashSequence() async {
    // Initialize app services with performance monitoring
    await _initializeAppWithPerformance();

    // Lu **pendant** que l'animation se joue, et non après : la lecture d'un
    // drapeau dans `SharedPreferences` prend quelques millisecondes, mais les
    // enchaîner derrière l'attente les ajouterait au démarrage.
    final presentationDejaVue = await OnboardingService.dejaVue();

    // Ensure animation has enough time to be seen
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      _navigateToNextScreen(presentationDejaVue: presentationDejaVue);
    }
  }

  /// Initialize app services with performance monitoring
  Future<void> _initializeAppWithPerformance() async {
    final performanceService = context.read<PerformanceService>();
    final errorHandler = context.read<ErrorHandlerService>();

    try {
      await performanceService.measureOperation('app_initialization', () async {
        // Attend que la session Django (Phase 6) soit restaurée — sinon
        // `AppService.initialize()` lirait un `_currentUser` pas encore à
        // jour et enverrait un client déjà connecté vers l'écran d'accueil
        // invité.
        await sessionReadyFuture;
        if (!mounted) return;

        final appService = context.read<AppService>();
        await appService.initialize();
      });
    } catch (e) {
      errorHandler.logError('Failed to initialize app', details: e.toString());
    }
  }

  /// Route de sortie de l'écran d'ouverture.
  ///
  /// La présentation ne s'interpose que devant un **visiteur** : quelqu'un
  /// dont la session est restaurée a déjà fait ce chemin, et lui remontrer
  /// trois écrans de découverte à chaque réinstallation d'une mise à jour
  /// serait un péage, pas un accueil.
  void _navigateToNextScreen({required bool presentationDejaVue}) {
    final appService = context.read<AppService>();

    try {
      if (!presentationDejaVue &&
          !(appService.currentUser != null && appService.isLoggedIn)) {
        Navigator.of(context).pushReplacementNamed(AppRouter.onboarding);
        return;
      }

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        alignment: Alignment.center,
        children: [
          _construireHalo(theme),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                FadeTransition(
                  opacity: _opaciteTitre,
                  child: SlideTransition(
                    position: _monteeTitre,
                    child: Text(
                      'El Corazón',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayLg(
                        color: theme.colorScheme.primary,
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingS),
                FadeTransition(
                  opacity: _opaciteSignature,
                  child: Text(
                    'CUISINE AU FEU DE BOIS',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLg(
                      color: theme.colorScheme.onSurfaceVariant,
                    ).copyWith(letterSpacing: 2.4),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _opacitePoints,
                  child: const _PointsRebondissants(),
                ),
                const SizedBox(height: DesignConstants.spacingXL),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Halo rouge flouté qui bat lentement derrière le mot-symbole.
  ///
  /// Un `BackdropFilter` serait ici du gaspillage : il n'y a rien à filtrer
  /// derrière. Le flou est donc peint directement, par une interpolation
  /// radiale qui s'éteint avant le bord — une passe de peinture, là où un
  /// flou gaussien en coûterait trois, sur un écran qui doit précisément
  /// laisser le processeur libre pour l'initialisation qui tourne dessous.
  Widget _construireHalo(ThemeData theme) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _halo,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_halo.value);
          return Container(
            width: 340 + 40 * t,
            height: 340 + 40 * t,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.20 + 0.10 * t),
                  theme.colorScheme.primary.withValues(alpha: 0.08 + 0.04 * t),
                  theme.colorScheme.primary.withValues(alpha: 0),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Trois points qui rebondissent en décalé.
///
/// Ils remplacent l'indicateur circulaire : la maquette veut un signal
/// « discret » (« Loading Indicator (Subtle) »), et un anneau de 40 px au
/// centre bas d'un écran par ailleurs presque vide ne l'est pas.
class _PointsRebondissants extends StatefulWidget {
  const _PointsRebondissants();

  @override
  State<_PointsRebondissants> createState() => _PointsRebondissantsState();
}

class _PointsRebondissantsState extends State<_PointsRebondissants>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;

  /// Un seul contrôleur pour les trois points, décalés par un déphasage sur
  /// sa valeur. Trois contrôleurs indépendants dériveraient les uns des
  /// autres au fil des minutes.
  static const _dephasages = [0.0, 0.2, 0.4];

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final dephasage in _dephasages)
            AnimatedBuilder(
              animation: _controleur,
              builder: (context, child) {
                final phase = (_controleur.value + dephasage) % 1.0;
                // Le point monte puis retombe sur la première moitié du
                // cycle, et reste posé sur la seconde — sans ce temps mort,
                // les trois points ondulent en continu et l'œil y lit un
                // mouvement de fond plutôt qu'une attente.
                final saut = phase < 0.5
                    ? Curves.easeOut.transform(1 - (phase * 4 - 1).abs())
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, -6 * saut),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
