import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Classe centralisée pour toutes les couleurs de l'app
class AppColors {
  // Couleurs principales - Palette professionnelle admin
  static const primary = Color(0xFF2563EB); // Bleu professionnel
  static const primaryDark = Color(0xFF1E40AF);
  static const primaryLight = Color(0xFF3B82F6);
  static const secondary = Color(0xFF10B981); // Vert succès
  static const tertiary = Color(0xFFF59E0B); // Orange accent

  // Couleurs de texte améliorées
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textInverse = Color(0xFFFFFFFF);

  // Couleurs de surface améliorées
  static const surface = Color(0xFFF9FAFB);
  static const surfaceContainerHighest = Color(0xFFF3F4F6);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1F2937);

  // Couleurs d'état améliorées
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);

  // Couleurs spéciales
  static const background = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF111827);
  static const onPrimary = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE5E7EB);
  static const border = Color(0xFFD1D5DB);

  // Couleurs pour les cartes et widgets
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x1A000000);

  // Couleurs pour les statuts
  static const statusPending = Color(0xFFF59E0B);
  static const statusConfirmed = Color(0xFF3B82F6);
  static const statusPreparing = Color(0xFF8B5CF6);
  static const statusReady = Color(0xFF10B981);
  static const statusDelivered = Color(0xFF059669);
  static const statusCancelled = Color(0xFFEF4444);
}

// Classe AppTheme pour la compatibilité
class AppTheme {
  // Couleurs principales pour compatibilité
  static const primaryColor = AppColors.primary;
  static const accentColor = AppColors.secondary;
  static const backgroundColor = AppColors.background;
  static const surfaceColor = AppColors.surface;
  static const cardColor = AppColors.surfaceContainerHighest;
  static const textColor = AppColors.textPrimary;
  static const onSurfaceColor = AppColors.textPrimary;

  // TextTheme pour compatibilité
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.normal),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.normal),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.normal),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
    ),
  );
}

class LightModeColors {
  // Palette professionnelle admin - Bleu moderne
  static const lightPrimary = Color(0xFF2563EB); // Bleu professionnel
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(
    0xFFDBEAFE,
  ); // Light blue container
  static const lightOnPrimaryContainer = Color(0xFF1E40AF); // Dark blue
  static const lightSecondary = Color(0xFF10B981); // Vert succès
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFFF59E0B); // Orange accent
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFEF4444);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFEE2E2);
  static const lightOnErrorContainer = Color(0xFF991B1B);
  static const lightInversePrimary = Color(0xFF93C5FD);
  static const lightShadow = Color(0x1A000000);
  static const lightSurface = Color(0xFFF9FAFB); // Surface claire moderne
  static const lightOnSurface = Color(0xFF111827);
  static const lightAppBarBackground = Color(0xFF2563EB); // Bleu app bar
  static const lightCardBackground = Color(0xFFFFFFFF);
  static const lightDivider = Color(0xFFE5E7EB);
}

class DarkModeColors {
  // Dark mode professionnel admin
  static const darkPrimary = Color(0xFF60A5FA); // Bleu clair pour dark mode
  static const darkOnPrimary = Color(0xFF0F172A);
  static const darkPrimaryContainer = Color(0xFF1E3A8A); // Dark blue container
  static const darkOnPrimaryContainer = Color(0xFFDBEAFE);
  static const darkSecondary = Color(0xFF34D399); // Vert clair
  static const darkOnSecondary = Color(0xFF064E3B);
  static const darkTertiary = Color(0xFFFBBF24); // Orange clair
  static const darkOnTertiary = Color(0xFF78350F);
  static const darkError = Color(0xFFF87171);
  static const darkOnError = Color(0xFF7F1D1D);
  static const darkErrorContainer = Color(0xFF991B1B);
  static const darkOnErrorContainer = Color(0xFFFEE2E2);
  static const darkInversePrimary = Color(0xFF2563EB);
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = Color(0xFF111827); // Surface sombre moderne
  static const darkOnSurface = Color(0xFFF9FAFB);
  static const darkAppBarBackground = Color(0xFF1E293B); // Dark blue app bar
  static const darkCardBackground = Color(0xFF1F2937);
  static const darkDivider = Color(0xFF374151);
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

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    inversePrimary: LightModeColors.lightInversePrimary,
    shadow: LightModeColors.lightShadow,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightCardBackground,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightSurface,
  appBarTheme: AppBarTheme(
    backgroundColor: LightModeColors.lightAppBarBackground,
    foregroundColor: LightModeColors.lightOnPrimary,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: LightModeColors.lightOnPrimary,
    ),
  ),
  cardTheme: CardThemeData(
    color: LightModeColors.lightCardBackground,
    elevation: 2,
    shadowColor: LightModeColors.lightShadow,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  dividerTheme: const DividerThemeData(
    color: LightModeColors.lightDivider,
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightCardBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: LightModeColors.lightDivider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: LightModeColors.lightDivider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.lightPrimary,
      foregroundColor: LightModeColors.lightOnPrimary,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.lightPrimary,
      side: const BorderSide(color: LightModeColors.lightPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.normal,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.normal,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.normal,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w500,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.normal,
    ),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
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
    surfaceContainerHighest: DarkModeColors.darkCardBackground,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: AppBarTheme(
    backgroundColor: DarkModeColors.darkAppBarBackground,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: DarkModeColors.darkOnSurface,
    ),
  ),
  cardTheme: CardThemeData(
    color: DarkModeColors.darkCardBackground,
    elevation: 2,
    shadowColor: DarkModeColors.darkShadow,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  dividerTheme: const DividerThemeData(
    color: DarkModeColors.darkDivider,
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkCardBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkModeColors.darkDivider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkModeColors.darkDivider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.darkPrimary,
      foregroundColor: DarkModeColors.darkOnPrimary,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.darkPrimary,
      side: const BorderSide(color: DarkModeColors.darkPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.normal,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.normal,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.normal,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w500,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.bold,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.normal,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.normal,
    ),
  ),
);
