import 'package:flutter/material.dart';

/// Constantes de design pour garantir la cohérence dans toute l'application
class DesignConstants {
  DesignConstants._(); // Constructeur privé pour empêcher l'instanciation

  // === ESPACEMENTS ===

  /// Espacements basés sur le système 8pt Grid
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  /// EdgeInsets pré-définis pour un usage rapide
  static const EdgeInsets paddingXS = EdgeInsets.all(spacingXS);
  static const EdgeInsets paddingS = EdgeInsets.all(spacingS);
  static const EdgeInsets paddingM = EdgeInsets.all(spacingM);
  static const EdgeInsets paddingL = EdgeInsets.all(spacingL);
  static const EdgeInsets paddingXL = EdgeInsets.all(spacingXL);
  static const EdgeInsets paddingXXL = EdgeInsets.all(spacingXXL);

  /// Marges horizontales pour le contenu principal
  static const EdgeInsets marginHorizontal =
      EdgeInsets.symmetric(horizontal: spacingM);
  static const EdgeInsets marginHorizontalLarge =
      EdgeInsets.symmetric(horizontal: spacingL);

  /// Marges verticales
  static const EdgeInsets marginVertical =
      EdgeInsets.symmetric(vertical: spacingM);
  static const EdgeInsets marginVerticalLarge =
      EdgeInsets.symmetric(vertical: spacingL);

  // === BORDER RADIUS ===

  static const double radiusSmall = 8.0; // Badges, chips
  static const double radiusMedium = 12.0; // Boutons, inputs
  static const double radiusLarge = 16.0; // Cartes
  static const double radiusXLarge = 24.0; // Modals, bottom sheets

  static const BorderRadius borderRadiusSmall =
      BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius borderRadiusMedium =
      BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge =
      BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusXLarge =
      BorderRadius.all(Radius.circular(radiusXLarge));

  // === ÉLÉVATIONS ===

  static const double elevationLow = 2.0; // Cartes standard
  static const double elevationMedium = 4.0; // Boutons, cartes surélevées
  static const double elevationHigh = 8.0; // Modals, bottom sheets

  // === OMBRES ===

  static List<BoxShadow> get shadowLow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowHigh => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowPrimary => [
        BoxShadow(
          color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 2,
        ),
      ];

  static List<BoxShadow> get shadowSoft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 20,
          offset: const Offset(0, 10),
          spreadRadius: -5,
        ),
      ];

  // === DURÉES D'ANIMATION ===

  static const Duration animationInstant = Duration(milliseconds: 100);
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationVerySlow = Duration(milliseconds: 800);
  static const Duration animationExtraSlow = Duration(milliseconds: 1200);

  // === DÉLAIS D'ANIMATION ===
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration staggerDelayFast = Duration(milliseconds: 30);
  static const Duration staggerDelaySlow = Duration(milliseconds: 100);

  // === COURBES D'ANIMATION ===

  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveEaseOut = Curves.easeOutCubic;
  static const Curve curveEaseIn = Curves.easeInCubic;
  static const Curve curveBounce = Curves.elasticOut;

  // === TAILLES D'ÉLÉMENTS ===

  /// Taille minimale des zones tactiles (Accessibility)
  static const double touchTargetSize = 48.0;

  /// Tailles d'icônes standardisées
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  /// Tailles d'avatar
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge = 64.0;

  // === APP BAR ===

  static const double appBarHeight = 56.0;
  static const double appBarElevation = 0.0;

  // === BOTTOM NAVIGATION ===

  static const double bottomNavHeight = 64.0;

  // === DIALOGS ===

  static const double dialogWidth = 320.0;
  static const double dialogMaxWidth = 400.0;
  static const EdgeInsets dialogPadding = EdgeInsets.all(spacingL);

  // === CARTES ===

  static const double cardElevation = elevationLow;
  static const BorderRadius cardBorderRadius = borderRadiusLarge;
  static const EdgeInsets cardPadding = paddingM;

  // === BOUTONS ===

  static const double buttonHeight = 56.0;
  static const double buttonHeightSmall = 40.0;
  static const BorderRadius buttonBorderRadius = borderRadiusMedium;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: spacingL,
    vertical: spacingM,
  );

  // === INPUTS ===

  static const double inputHeight = 56.0;
  static const BorderRadius inputBorderRadius = borderRadiusMedium;
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: spacingM,
    vertical: spacingS,
  );

  // === LIST ITEMS ===

  static const double listItemHeight = 72.0;
  static const double listItemHeightCompact = 56.0;

  // === BREAKPOINTS (Responsive) ===

  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 900.0;
  static const double breakpointDesktop = 1200.0;

  // === MÉTHODES UTILITAIRES ===

  /// Retourne true si l'écran est mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < breakpointMobile;
  }

  /// Retourne true si l'écran est tablette
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= breakpointMobile && width < breakpointDesktop;
  }

  /// Retourne true si l'écran est desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= breakpointDesktop;
  }

  /// Retourne le padding horizontal adaptatif selon la taille de l'écran
  static EdgeInsets getAdaptiveHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) {
      final width = MediaQuery.of(context).size.width;
      final padding = (width - breakpointDesktop) / 2;
      return EdgeInsets.symmetric(
          horizontal: padding > spacingXXL ? spacingXXL : padding,);
    }
    return marginHorizontal;
  }

  /// Retourne le nombre de colonnes adaptatif pour les grilles
  static int getAdaptiveCrossAxisCount(BuildContext context) {
    if (isMobile(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }
}

/// Extensions pour simplifier l'utilisation des constantes
extension DesignConstantsExtension on BuildContext {
  bool get isMobile => DesignConstants.isMobile(this);
  bool get isTablet => DesignConstants.isTablet(this);
  bool get isDesktop => DesignConstants.isDesktop(this);

  EdgeInsets get adaptiveHorizontalPadding =>
      DesignConstants.getAdaptiveHorizontalPadding(this);
  int get adaptiveCrossAxisCount =>
      DesignConstants.getAdaptiveCrossAxisCount(this);
}
