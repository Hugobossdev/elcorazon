import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette El Corazón — jetons du système de design « El Corazón Mobile ».
///
/// ## D'où viennent ces valeurs
///
/// Elles sont reprises telles quelles de l'entête du design system livré par
/// Stitch (`DESIGN.md`). C'est une palette Material 3 complète, engendrée
/// depuis la graine rouge `#b91c24` : chaque rôle y a son pendant « on- » et
/// son conteneur, ce qui permet d'écrire l'interface en termes de rôles
/// (`primary`, `surfaceContainerHigh`…) plutôt qu'en couleurs nommées.
///
/// ## Ce qui a changé par rapport à la version précédente
///
/// Le rouge passe de `#E53E3E` à `#b51822` — plus sombre, plus dense, il tient
/// le contraste AA sur fond clair là où l'ancien échouait pour du texte. Le
/// « doré » n'est plus une couleur unique : Material 3 le scinde en un rôle
/// **secondary** foncé (`#715d00`, pour du texte ou une icône sur fond clair)
/// et un accent lumineux **secondaryFixedDim** (`#e4c44d`, pour se poser sur
/// une photo ou un fond sombre). [secondary] garde ce second rôle, parce que
/// c'est celui qu'attendaient déjà tous ses lecteurs — l'étoile d'une note,
/// la pastille du panier — et [secondaryDeep] porte le premier.
class AppColors {
  AppColors._();

  // === Rouge de marque ===
  static const primary = Color(0xFFB51822);
  static const primaryLight = Color(0xFFD93537); // primary-container
  static const primaryDark = Color(0xFF930013); // on-primary-fixed-variant
  static const onPrimary = Color(0xFFFFFFFF);

  /// Accent doré tel qu'il se pose **sur une photo ou un fond sombre**.
  /// Correspond au jeton `secondary-fixed-dim`.
  static const secondary = Color(0xFFE4C44D);

  /// Doré tel qu'il se pose **sur un fond clair** — le rôle `secondary` de
  /// Material 3. Presque olive : c'est la seule déclinaison qui reste lisible
  /// en texte sur du blanc cassé.
  static const secondaryDeep = Color(0xFF715D00);
  static const secondaryLight = Color(0xFFFFE177); // secondary-fixed
  static const secondaryContainer = Color(0xFFFFDE64);

  static const tertiary = Color(0xFF9C4007);
  static const tertiaryLight = Color(0xFFFFB694); // tertiary-fixed-dim
  static const tertiaryContainer = Color(0xFFBC5721);

  // === Texte ===
  static const textPrimary = Color(0xFF1C1B1B); // on-surface
  static const textSecondary = Color(0xFF5B403E); // on-surface-variant
  static const textTertiary = Color(0xFF8F6F6D); // outline
  static const textLight = Color(0xFFFFFFFF);

  // === Surfaces ===
  //
  // Les cinq niveaux de conteneur remplacent les ombres pour hiérarchiser :
  // c'est la « Tonal Layer » que réclame le design system, moins salissante
  // qu'une ombre portée sur un fond chaud.
  static const surface = Color(0xFFFCF9F8);
  static const surfaceDim = Color(0xFFDCD9D9);
  static const surfaceBright = Color(0xFFFCF9F8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF6F3F2);
  static const surfaceContainer = Color(0xFFF0EDED);
  static const surfaceContainerHigh = Color(0xFFEAE7E7);
  static const surfaceContainerHighest = Color(0xFFE5E2E1);
  static const surfaceVariant = Color(0xFFE5E2E1);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const outline = Color(0xFF8F6F6D);
  static const outlineVariant = Color(0xFFE4BEBA);

  // === États ===
  //
  // `success` et `info` n'existent pas dans Material 3 : ils sont conservés
  // parce que les puces de statut de commande — « Préparation », « En route »,
  // « Livrée » — en ont besoin, et le design system les rattache aux rôles
  // tertiaire et secondaire.
  static const success = Color(0xFF2E6B3E);
  static const successLight = Color(0xFF9BD3A8);
  static const warning = Color(0xFF9C4007); // tertiary
  static const warningLight = Color(0xFFFFB694);
  static const error = Color(0xFFBA1A1A);
  static const errorLight = Color(0xFFFFDAD6);
  static const info = Color(0xFF3F5A8F);
  static const infoLight = Color(0xFFB8CBF5);

  // === Fonds ===
  static const background = Color(0xFFFCF9F8);
  static const backgroundGradient = [
    Color(0xFFFCF9F8),
    Color(0xFFF6F3F2),
  ];

  // === Verre dépoli ===
  //
  // 90 % d'opacité, pas 60 : le design system veut qu'on devine le contenu
  // qui défile dessous sans jamais avoir à le déchiffrer.
  static const glassLight = Color(0xE6FCF9F8);
  static const glassDark = Color(0xE61A1A1A);
  static const glassBorderLight = Color(0x33FFFFFF);
  static const glassBorderDark = Color(0x33FFFFFF);

  /// Flou des barres translucides, en pixels logiques.
  static const double glassBlur = 18;

  // === Dégradés ===
  //
  // Réservés aux zones à forte intention — bannière promotionnelle, en-tête de
  // catégorie, bouton « Commander ». Partout ailleurs, un aplat.
  static const primaryGradient = [
    Color(0xFFB51822),
    Color(0xFFD93537),
  ];
  static const secondaryGradient = [
    Color(0xFFE4C44D),
    Color(0xFFFFE177),
  ];
  static const successGradient = [
    Color(0xFF9C4007),
    Color(0xFFE4C44D),
  ];

  /// Rouge → doré, à 135°. C'est le `bg-gradient-promo` des maquettes : le
  /// seul dégradé qui traverse deux familles de teinte, et la raison pour
  /// laquelle il est réservé aux bannières.
  static const heroGradient = [
    Color(0xFFB51822),
    Color(0xFFE4C44D),
  ];

  /// Rouge → orange, pour l'action de règlement (« Passer la commande »).
  static const actionGradient = [
    Color(0xFFB51822),
    Color(0xFF9C4007),
  ];

  /// Voile posé sous un texte blanc sur photo. Sans lui, la légende d'une
  /// carte devient illisible dès que le plat est clair.
  static const imageScrim = [
    Color(0x00000000),
    Color(0xB3000000),
  ];
}

/// Alias de compatibilité, conservés pour les écrans qui les lisent encore.
class AppTheme {
  static const primaryColor = AppColors.primary;
  static const accentColor = AppColors.secondary;
  static const backgroundColor = AppColors.background;
  static const surfaceColor = AppColors.surface;
  static const cardColor = AppColors.surfaceContainerLowest;
  static const textColor = AppColors.textPrimary;
  static const onSurfaceColor = AppColors.textPrimary;

  static TextTheme get textTheme => _createTextTheme();
}

/// Schéma clair complet.
class LightModeColors {
  LightModeColors._();

  static const lightPrimary = Color(0xFFB51822);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFD93537);
  static const lightOnPrimaryContainer = Color(0xFFFFFBFF);
  static const lightSecondary = Color(0xFF715D00);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightSecondaryContainer = Color(0xFFFFDE64);
  static const lightOnSecondaryContainer = Color(0xFF766100);
  static const lightTertiary = Color(0xFF9C4007);
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightTertiaryContainer = Color(0xFFBC5721);
  static const lightOnTertiaryContainer = Color(0xFFFFFBFF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF93000A);
  static const lightInversePrimary = Color(0xFFFFB3AD);
  static const lightInverseSurface = Color(0xFF313030);
  static const lightOnInverseSurface = Color(0xFFF3F0EF);
  static const lightShadow = Color(0xFF000000);
  static const lightScrim = Color(0xFF000000);
  static const lightSurfaceTint = Color(0xFFB91C24);
  static const lightSurface = Color(0xFFFCF9F8);
  static const lightOnSurface = Color(0xFF1C1B1B);
  static const lightSurfaceVariant = Color(0xFFE5E2E1);
  static const lightOnSurfaceVariant = Color(0xFF5B403E);
  static const lightOutline = Color(0xFF8F6F6D);
  static const lightOutlineVariant = Color(0xFFE4BEBA);

  /// La barre supérieure n'est plus rouge : les maquettes la veulent
  /// translucide sur le contenu, avec un titre rouge. Un aplat rouge pleine
  /// largeur écrasait la photographie, qui est le premier moteur visuel du
  /// design system.
  static const lightAppBarBackground = Color(0xFFFCF9F8);
  static const lightOnAppBar = Color(0xFF1C1B1B);
}

/// Schéma sombre, dérivé de la même graine.
///
/// Stitch ne livre pas de palette sombre : celle-ci est construite selon les
/// correspondances de Material 3 — le `primary` sombre est l'`inversePrimary`
/// clair, le `primaryContainer` sombre est l'`onPrimaryFixedVariant` clair, et
/// ainsi de suite. La surface suit en revanche la prose du design system
/// (« deep charcoal #1A1A1A ») plutôt que le neutre M3, plus froid : le fond
/// doit rester chaud pour ne pas verdir les photos de plats.
class DarkModeColors {
  DarkModeColors._();

  static const darkPrimary = Color(0xFFFFB3AD);
  static const darkOnPrimary = Color(0xFF680011);
  static const darkPrimaryContainer = Color(0xFF930013);
  static const darkOnPrimaryContainer = Color(0xFFFFDAD7);
  static const darkSecondary = Color(0xFFE4C44D);
  static const darkOnSecondary = Color(0xFF3B2F00);
  static const darkSecondaryContainer = Color(0xFF554500);
  static const darkOnSecondaryContainer = Color(0xFFFFE177);
  static const darkTertiary = Color(0xFFFFB694);
  static const darkOnTertiary = Color(0xFF561F00);
  static const darkTertiaryContainer = Color(0xFF7B2F00);
  static const darkOnTertiaryContainer = Color(0xFFFFDBCC);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkInversePrimary = Color(0xFFB51822);
  static const darkInverseSurface = Color(0xFFE5E2E1);
  static const darkOnInverseSurface = Color(0xFF313030);
  static const darkShadow = Color(0xFF000000);
  static const darkScrim = Color(0xFF000000);
  static const darkSurfaceTint = Color(0xFFFFB3AD);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkOnSurface = Color(0xFFE5E2E1);
  static const darkSurfaceVariant = Color(0xFF534341);
  static const darkOnSurfaceVariant = Color(0xFFD8C2BF);
  static const darkOutline = Color(0xFFA08D8B);
  static const darkOutlineVariant = Color(0xFF534341);

  static const darkSurfaceContainerLowest = Color(0xFF0F0E0E);
  static const darkSurfaceContainerLow = Color(0xFF201F1F);
  static const darkSurfaceContainer = Color(0xFF252424);
  static const darkSurfaceContainerHigh = Color(0xFF2F2E2E);
  static const darkSurfaceContainerHighest = Color(0xFF3A3939);

  static const darkAppBarBackground = Color(0xFF1A1A1A);
  static const darkOnAppBar = Color(0xFFE5E2E1);
}

/// Corps de texte du système de design.
///
/// L'échelle est resserrée par rapport à Material : `display-lg` plafonne à
/// 32 px là où `displayLarge` en faisait 57. Une application de commande se
/// lit sur un téléphone tenu d'une main, et chaque point gagné sur le titre
/// est un plat de plus visible sans défiler.
class FontSizes {
  FontSizes._();

  static const double displayLarge = 32.0;
  static const double displayMedium = 28.0;
  static const double displaySmall = 26.0;
  static const double headlineLarge = 28.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 20.0;
  static const double titleLarge = 18.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

/// Les huit styles nommés du design system, tels quels.
///
/// Ils doublent volontairement le `TextTheme` de Material : celui-ci porte
/// quinze rôles génériques, celui-ci en porte huit, nommés d'après l'usage
/// qu'en fait la maquette. Écrire `AppTypography.priceDisplay` dit ce qu'on
/// affiche ; `textTheme.titleMedium` ne dit que sa taille.
class AppTypography {
  AppTypography._();

  /// Titre d'une bannière promotionnelle. Nulle part ailleurs.
  static TextStyle displayLg({Color? color}) => _createTextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        height: 40 / 32,
        letterSpacing: -0.02 * 32,
      );

  /// Titre d'écran, titre de section forte.
  static TextStyle headlineMd({Color? color}) => _createTextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        height: 32 / 24,
        letterSpacing: -0.01 * 24,
      );

  /// Titre de section courante (« Populaires près de vous »).
  static TextStyle headlineSm({Color? color}) => _createTextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        height: 28 / 20,
      );

  /// Nom d'un plat dans une liste.
  static TextStyle titleLg({Color? color}) => _createTextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
        height: 24 / 18,
      );

  /// Corps de texte de référence. 16 px, pour rester lisible sans réglage.
  static TextStyle bodyLg({Color? color}) => _createTextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 24 / 16,
      );

  /// Information secondaire : délai de préparation, distance, catégorie.
  static TextStyle bodyMd({Color? color}) => _createTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 20 / 14,
      );

  /// Étiquette, badge, libellé de bouton compact. Interlettrage ouvert : à
  /// 12 px et en gras, les caractères se touchent sans lui.
  static TextStyle labelLg({Color? color}) => _createTextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
      );

  /// Un prix. Toujours gras, toujours dans le rouge de marque — c'est un
  /// jeton typographique à part entière dans le design system, pas une
  /// variante de titre.
  static TextStyle priceDisplay({Color? color}) => _createTextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.primary,
      );
}

/// Construit un `TextStyle` Inter, avec repli.
///
/// Sur le web, `GoogleFonts` passe par CanvasKit et échoue silencieusement
/// tant que la police n'est pas résolue ; la feuille de style d'`index.html`
/// a déjà chargé Inter, on s'appuie donc dessus. Sur mobile, `GoogleFonts`
/// fait le travail. Le `try` couvre le cas où ni l'un ni l'autre n'aboutit.
TextStyle _createTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  Color? color,
  double height = 1.2,
  double? letterSpacing,
}) {
  try {
    if (kIsWeb) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'sans-serif'],
        textBaseline: TextBaseline.alphabetic,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      textBaseline: TextBaseline.alphabetic,
      height: height,
      letterSpacing: letterSpacing,
    );
  } catch (e) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['sans-serif'],
      textBaseline: TextBaseline.alphabetic,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// `TextTheme` Material aligné sur l'échelle du design system.
///
/// Les interlignes sont ceux de la maquette (1,5 pour le corps, 1,33 pour les
/// titres) et non le 1,2 uniforme d'avant : un texte de description sur trois
/// lignes était compact au point de baver.
TextTheme _createTextTheme() {
  return TextTheme(
    displayLarge: _createTextStyle(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w800,
      height: 40 / 32,
      letterSpacing: -0.64,
    ),
    displayMedium: _createTextStyle(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w800,
      height: 36 / 28,
      letterSpacing: -0.56,
    ),
    displaySmall: _createTextStyle(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w700,
      height: 34 / 26,
    ),
    headlineLarge: _createTextStyle(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w700,
      height: 36 / 28,
      letterSpacing: -0.28,
    ),
    headlineMedium: _createTextStyle(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w700,
      height: 32 / 24,
      letterSpacing: -0.24,
    ),
    headlineSmall: _createTextStyle(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      height: 28 / 20,
    ),
    titleLarge: _createTextStyle(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
      height: 24 / 18,
    ),
    titleMedium: _createTextStyle(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w600,
      height: 24 / 16,
    ),
    titleSmall: _createTextStyle(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
    ),
    labelLarge: _createTextStyle(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      letterSpacing: 0.2,
    ),
    labelMedium: _createTextStyle(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      letterSpacing: 0.6,
    ),
    labelSmall: _createTextStyle(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w600,
      height: 16 / 11,
      letterSpacing: 0.5,
    ),
    bodyLarge: _createTextStyle(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
    ),
    bodyMedium: _createTextStyle(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    ),
    bodySmall: _createTextStyle(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
    ),
  );
}

/// Formes du système : « Soft-Modern ».
///
/// La distinction porte du sens — 16 px encadre un **contenu** (carte, photo),
/// 12 px désigne une **action** (bouton, champ). L'œil apprend la règle en
/// deux écrans et sait ensuite ce qui se touche.
const _rayonCarte = 16.0;
const _rayonAction = 12.0;

ThemeData get lightTheme => _construireTheme(
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: LightModeColors.lightPrimary,
        onPrimary: LightModeColors.lightOnPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        onSecondary: LightModeColors.lightOnSecondary,
        secondaryContainer: LightModeColors.lightSecondaryContainer,
        onSecondaryContainer: LightModeColors.lightOnSecondaryContainer,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        tertiaryContainer: LightModeColors.lightTertiaryContainer,
        onTertiaryContainer: LightModeColors.lightOnTertiaryContainer,
        error: LightModeColors.lightError,
        onError: LightModeColors.lightOnError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
        surfaceDim: AppColors.surfaceDim,
        surfaceBright: AppColors.surfaceBright,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
        outline: LightModeColors.lightOutline,
        outlineVariant: LightModeColors.lightOutlineVariant,
        inverseSurface: LightModeColors.lightInverseSurface,
        onInverseSurface: LightModeColors.lightOnInverseSurface,
        inversePrimary: LightModeColors.lightInversePrimary,
        surfaceTint: LightModeColors.lightSurfaceTint,
        shadow: LightModeColors.lightShadow,
        scrim: LightModeColors.lightScrim,
      ),
      scaffoldBackground: AppColors.background,
      appBarBackground: LightModeColors.lightAppBarBackground,
      appBarForeground: LightModeColors.lightOnAppBar,
      cardColor: AppColors.surfaceContainerLowest,
      inputFill: AppColors.surfaceVariant,
    );

ThemeData get darkTheme => _construireTheme(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: DarkModeColors.darkPrimary,
        onPrimary: DarkModeColors.darkOnPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        onSecondary: DarkModeColors.darkOnSecondary,
        secondaryContainer: DarkModeColors.darkSecondaryContainer,
        onSecondaryContainer: DarkModeColors.darkOnSecondaryContainer,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        tertiaryContainer: DarkModeColors.darkTertiaryContainer,
        onTertiaryContainer: DarkModeColors.darkOnTertiaryContainer,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
        surfaceDim: DarkModeColors.darkSurface,
        surfaceBright: DarkModeColors.darkSurfaceContainerHighest,
        surfaceContainerLowest: DarkModeColors.darkSurfaceContainerLowest,
        surfaceContainerLow: DarkModeColors.darkSurfaceContainerLow,
        surfaceContainer: DarkModeColors.darkSurfaceContainer,
        surfaceContainerHigh: DarkModeColors.darkSurfaceContainerHigh,
        surfaceContainerHighest: DarkModeColors.darkSurfaceContainerHighest,
        onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
        outline: DarkModeColors.darkOutline,
        outlineVariant: DarkModeColors.darkOutlineVariant,
        inverseSurface: DarkModeColors.darkInverseSurface,
        onInverseSurface: DarkModeColors.darkOnInverseSurface,
        inversePrimary: DarkModeColors.darkInversePrimary,
        surfaceTint: DarkModeColors.darkSurfaceTint,
        shadow: DarkModeColors.darkShadow,
        scrim: DarkModeColors.darkScrim,
      ),
      scaffoldBackground: DarkModeColors.darkSurface,
      appBarBackground: DarkModeColors.darkAppBarBackground,
      appBarForeground: DarkModeColors.darkOnAppBar,
      cardColor: DarkModeColors.darkSurfaceContainerLow,
      inputFill: DarkModeColors.darkSurfaceContainerHigh,
    );

/// Les deux thèmes ne diffèrent que par leurs couleurs : formes, espacements
/// et typographie sont les mêmes. Les factoriser évite qu'un rayon corrigé en
/// clair reste faux en sombre — c'était le cas de `cardTheme`, dont seule la
/// version claire avait reçu le rayon de 16.
ThemeData _construireTheme({
  required Brightness brightness,
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required Color appBarBackground,
  required Color appBarForeground,
  required Color cardColor,
  required Color inputFill,
}) {
  final textTheme = _createTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme: textTheme,

    // La barre supérieure est plate et claire : le relief vient du flou que
    // `GlassAppBar` pose derrière elle, pas d'une ombre.
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: appBarForeground),
      iconTheme: IconThemeData(color: appBarForeground),
    ),

    cardTheme: CardThemeData(
      // Zéro : l'ombre du design system (`0 2px 8px rgba(26,26,26,.08)`) est
      // bien plus douce que celle qu'attache Material à une élévation de 2, et
      // c'est `DesignConstants.shadowLow` qui la porte.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rayonCarte),
      ),
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rayonAction),
        ),
        // 48 px de haut : la zone tactile minimale de 44 px que réclame le
        // design system, marge comprise.
        minimumSize: const Size(88, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: BorderSide(color: colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rayonAction),
        ),
        minimumSize: const Size(88, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rayonAction),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rayonAction),
        ),
        minimumSize: const Size(88, 48),
        textStyle: textTheme.labelLarge,
      ),
    ),

    // Champs pleins, sans bordure au repos : la maquette ne dessine un trait
    // qu'au focus et à l'erreur, là où il apprend quelque chose.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),

    // Puces en pilule — « Badges … fully pill-shaped ».
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.primary,
      labelStyle: textTheme.titleSmall,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // Les feuilles montent depuis le bas et gardent leur coin haut arrondi :
    // 24 px, le rayon « modal » du design system.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
      ),
    ),

    // 8 dp : le bouton flottant doit se détacher franchement du contenu qui
    // défile dessous, c'est le seul endroit où le design system demande une
    // ombre marquée.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 8,
      shape: const CircleBorder(),
    ),

    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.titleSmall,
      dividerColor: Colors.transparent,
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.surfaceContainerHigh,
      circularTrackColor: colorScheme.surfaceContainerHigh,
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rayonAction),
      ),
      iconColor: colorScheme.onSurfaceVariant,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
