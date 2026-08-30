import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Écran d'accueil des visiteurs non connectés.
///
/// ## L'image de fond vient du catalogue, pas d'un asset
///
/// La maquette pose une photographie de plat en pleine page. Elle n'est pas
/// embarquée dans l'application : ce serait figer une image de démonstration
/// dans le binaire, et la première chose qu'un nouveau visiteur verrait ne
/// serait pas ce que la cuisine sert aujourd'hui.
///
/// C'est donc le **catalogue** qui la fournit — le premier article populaire
/// pourvu d'une photo, tel que `AppService` l'a chargé depuis `/api/v1/`. Si
/// le catalogue n'est pas encore là, ou qu'aucun article n'a de photo, le
/// dégradé de marque tient la place seul : il est conçu pour ça, et l'écran
/// reste lisible sans jamais afficher de cadre vide.
class GuestWelcomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const GuestWelcomeScreen({super.key, this.onNavigateToTab});

  @override
  State<GuestWelcomeScreen> createState() => _GuestWelcomeScreenState();
}

class _GuestWelcomeScreenState extends State<GuestWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Photo du premier article populaire qui en possède une.
  ///
  /// L'ordre de `menuItems` est celui du serveur (`sort_order`), donc stable
  /// d'un lancement à l'autre : l'écran ne change pas d'illustration à chaque
  /// ouverture, ce qui donnerait l'impression d'un défaut.
  String? _photoDAccueil(AppService appService) {
    for (final article in appService.menuItems) {
      final image = article.image;
      if (article.isPopular && image != null && image.isNotEmpty) return image;
    }
    for (final article in appService.menuItems) {
      final image = article.image;
      if (image != null && image.isNotEmpty) return image;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final photo = _photoDAccueil(appService);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Fond de repli : il reste visible dans les marges d'une photo
              // qui ne remplit pas exactement l'écran, et tient seul tant que
              // le catalogue n'est pas chargé.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.actionGradient,
                  ),
                ),
              ),
              if (photo != null) FoodImage(url: photo, iconSize: 96),

              // Voile : du transparent en haut au presque noir en bas, pour
              // que le texte blanc tienne quelle que soit la photo servie.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x99000000),
                      Color(0xF21A1A1A),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),

              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignConstants.edgeMargin,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'El Corazón',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayLg(color: Colors.white)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: DesignConstants.spacingS),
                          Text(
                            "Le cœur de la cuisine d'Abidjan.",
                            textAlign: TextAlign.center,
                            style:
                                AppTypography.headlineMd(color: Colors.white),
                          ),
                          const SizedBox(height: DesignConstants.spacingS),
                          Text(
                            'Grillé au feu de bois, livré chez vous.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLg(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: DesignConstants.spacingXL),
                          ActionButton(
                            label: 'Explorer le menu',
                            icon: Icons.restaurant_menu_rounded,
                            onPressed: () => widget.onNavigateToTab?.call(1),
                          ),
                          const SizedBox(height: DesignConstants.spacingM),
                          // Contour clair plutôt que rouge : sur une photo
                          // sombre, le rouge de marque est le seul repère
                          // qu'on ne peut pas se permettre de rendre discret,
                          // et il est déjà pris par le bouton du dessus.
                          ActionButton(
                            label: "Se connecter / S'inscrire",
                            icon: Icons.login_rounded,
                            emphasis: ActionEmphasis.outlined,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            foregroundColor: Colors.white,
                            onPressed: () =>
                                NavigationService.navigateToAuth(context),
                          ),
                          const SizedBox(height: DesignConstants.spacingXL),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
