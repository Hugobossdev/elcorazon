import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Classe centralisée pour toutes les couleurs de l'app
class AppColors {
  // Couleurs principales - Palette El Corazón améliorée
  static const primary = Color(0xFFE53E3E);
  static const primaryLight = Color(0xFFFF6B6B);
  static const primaryDark = Color(0xFFC62828);
  static const secondary = Color(0xFFF6D55C);
  static const secondaryLight = Color(0xFFFFE082);
  static const tertiary = Color(0xFFFF8A50);
  static const tertiaryLight = Color(0xFFFFB380);

  // Couleurs de texte améliorées
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF9E9E9E);
  static const textLight = Color(0xFFFFFFFF);

  // Couleurs de surface améliorées
  static const surface = Color(0xFFFFFBF7);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E1E);

  // Couleurs d'état améliorées
  static const success = Color(0xFF4CAF50);
  static const successLight = Color(0xFF81C784);
  static const warning = Color(0xFFFF9800);
  static const warningLight = Color(0xFFFFB74D);
  static const error = Color(0xFFBA1A1A);
  static const errorLight = Color(0xFFE57373);
  static const info = Color(0xFF2196F3);
  static const infoLight = Color(0xFF64B5F6);

  // Couleurs spéciales
  static const background = Color(0xFFFFFFFF);
  static const backgroundGradient = [
    Color(0xFFFFFBF7),
    Color(0xFFFFF8F0),
  ];
  static const onPrimary = Color(0xFFFFFFFF);

  // Couleurs de gradient
  static const primaryGradient = [
    Color(0xFFE53E3E),
    Color(0xFFFF6B6B),
  ];
  static const secondaryGradient = [
    Color(0xFFF6D55C),
    Color(0xFFFFE082),
  ];
  static const heroGradient = [
    Color(0xFFE53E3E),
    Color(0xFFF6D55C),
    Color(0xFFFF8A50),
  ];
}

// Classe AppTheme pour la compatibilité
class AppTheme {
  // Couleurs principales pour compatibilité
  static const primaryColor = AppColors.primary;
  static const accentColor = AppColors.secondary;
  static const backgroundColor = AppColors.background;
  static const surfaceColor = AppColors.surface;
  static const cardColor = AppColors.surfaceVariant;
  static const textColor = AppColors.textPrimary;
  static const onSurfaceColor = AppColors.textPrimary;

  // TextTheme pour compatibilité avec gestion d'erreur
  static TextTheme get textTheme => _createTextTheme();
}

class LightModeColors {
  // El Corazón Brand Colors - Red, Yellow, Black palette
  static const lightPrimary = Color(0xFFE53E3E); // Vibrant Red
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFFFEBEE); // Light red container
  static const lightOnPrimaryContainer = Color(0xFF8B0000); // Dark red
  static const lightSecondary = Color(0xFFF6D55C); // Golden Yellow
  static const lightOnSecondary = Color(0xFF000000); // Black text on yellow
  static const lightTertiary = Color(0xFFFF8A50); // Orange accent
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);
  static const lightInversePrimary = Color(0xFFFFB3B3);
  static const lightShadow = Color(0xFF000000);
  static const lightSurface = Color(0xFFFFFBF7); // Warm white surface
  static const lightOnSurface = Color(0xFF1A1A1A);
  static const lightAppBarBackground = Color(0xFFE53E3E); // Red app bar
}

class DarkModeColors {
  // Dark mode with El Corazón branding
  static const darkPrimary = Color(0xFFFF6B6B); // Lighter red for dark mode
  static const darkOnPrimary = Color(0xFF000000);
  static const darkPrimaryContainer = Color(0xFF8B0000); // Dark red container
  static const darkOnPrimaryContainer = Color(0xFFFFEBEE);
  static const darkSecondary = Color(0xFFF6D55C); // Golden Yellow stays same
  static const darkOnSecondary = Color(0xFF000000);
  static const darkTertiary = Color(0xFFFF8A50); // Orange accent
  static const darkOnTertiary = Color(0xFF000000);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkInversePrimary = Color(0xFFE53E3E);
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = Color(0xFF1A1A1A); // Deep black surface
  static const darkOnSurface = Color(0xFFF5F5F5);
  static const darkAppBarBackground = Color(0xFF8B0000); // Dark red app bar
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// Fonction pour créer un TextStyle avec fallback optimisé
TextStyle _createTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  Color? color,
}) {
  // Pour Flutter Web, utiliser directement la police Inter depuis le CSS
  // Cela évite les problèmes avec GoogleFonts sur Web (CanvasKit/fonts)
  try {
    // Vérifier si on est sur Web via kIsWeb
    if (kIsWeb) {
      // Sur Web, utiliser la police Inter chargée via CSS dans index.html
      // Cela évite les problèmes avec GoogleFonts.inter() sur CanvasKit
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'sans-serif'],
        textBaseline: TextBaseline.alphabetic,
        height: 1.2,
      );
    }

    // Pour les autres plateformes (mobile), utiliser GoogleFonts
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      textBaseline: TextBaseline.alphabetic,
      height: 1.2,
    );
  } catch (e) {
    // Fallback vers la police système si tout échoue
    // Évite les erreurs null avec CanvasKit/fonts
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['sans-serif'],
      textBaseline: TextBaseline.alphabetic,
      height: 1.2,
    );
  }
}

// Fonction pour créer le TextTheme avec gestion d'erreur
TextTheme _createTextTheme() {
  return TextTheme(
    displayLarge: _createTextStyle(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.normal,
    ),
    displayMedium: _createTextStyle(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.normal,
    ),
    displaySmall: _createTextStyle(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: _createTextStyle(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.normal,
    ),
    headlineMedium: _createTextStyle(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w500,
    ),
    headlineSmall: _createTextStyle(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: _createTextStyle(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: _createTextStyle(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: _createTextStyle(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: _createTextStyle(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: _createTextStyle(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: _createTextStyle(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: _createTextStyle(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: _createTextStyle(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: _createTextStyle(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.normal,
    ),
  );
}

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: LightModeColors.lightPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        error: LightModeColors.lightError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        inversePrimary: LightModeColors.lightInversePrimary,
        shadow: LightModeColors.lightShadow,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.textTertiary,
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: LightModeColors.lightAppBarBackground,
        foregroundColor: LightModeColors.lightOnPrimaryContainer,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _createTextTheme().titleLarge?.copyWith(
              color: LightModeColors.lightOnPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.surfaceElevated,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(88, 48),
        ),
      ),
      textTheme: _createTextTheme(),
    );

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: DarkModeColors.darkPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        inversePrimary: DarkModeColors.darkInversePrimary,
        shadow: DarkModeColors.darkShadow,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DarkModeColors.darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkModeColors.darkAppBarBackground,
        foregroundColor: DarkModeColors.darkOnPrimaryContainer,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: DarkModeColors.darkSurface, // Or slightly lighter for elevation
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      textTheme: _createTextTheme(),
    );
