import 'package:flutter/material.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/screens/client/main_navigation_screen.dart';
import 'package:elcora_fast/services/onboarding_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// Présentation d'ouverture, au tout premier lancement.
///
/// ## Ce que couvrent les maquettes
///
/// Trois écrans du second lot Stitch : `onboarding_welcome`,
/// `onboarding_tracking_highlight` et `onboarding_authentication_options`.
/// Ils forment une seule séquence qui se feuillette, et non trois routes —
/// c'est ce que montre l'enchaînement des boutons (« Get Started », « Next »,
/// puis le choix de connexion).
///
/// ## Ce qui a été retiré des maquettes, et pourquoi
///
/// `onboarding_authentication_options` propose « Continue with Google » et
/// « Continue with Apple ». **Aucune des deux n'existe côté serveur** — le
/// sujet est déjà documenté dans `auth_screen.dart` et repris en BR-001 de
/// `docs/STITCH_BACKEND_REQUIREMENTS.md`. Un bouton « Continuer avec Google »
/// qui ouvre un formulaire e-mail ne fait pas patienter : il ment sur ce qui
/// va se passer, et la déception arrive une seconde plus tard.
///
/// ## Pourquoi aucune photographie
///
/// Le projet n'embarque pas de banque d'images, et le design system fait du
/// nom lui-même la marque (voir `splash_screen.dart`). Les trois pages sont
/// donc bâties sur les dégradés de la palette et les icônes Material, comme
/// l'écran d'ouverture — plutôt que sur des URL d'un hébergeur extérieur, qui
/// feraient dépendre le premier écran de l'application d'un tiers et d'une
/// connexion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  static const int _nombreDePages = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _suivante() {
    if (_page >= _nombreDePages - 1) return;
    _pages.nextPage(
      duration: DesignConstants.animationNormal,
      curve: DesignConstants.curveEaseOut,
    );
  }

  /// Sort de la présentation vers [route], en la marquant vue.
  ///
  /// Le drapeau est posé **avant** de naviguer, et non après : partir sans
  /// l'écrire ferait reparaître la présentation au prochain démarrage, ce qui
  /// est exactement ce qu'on vient de refuser.
  Future<void> _quitter({required String? route}) async {
    await OnboardingService.marquerVue();
    if (!mounted) return;

    if (route == null) {
      // « Découvrir la carte » : on entre en invité, sans compte.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const MainNavigationScreen(),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _barreDeTete(theme),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) => setState(() => _page = index),
                children: const [
                  _PageAccueil(),
                  _PageSuivi(),
                  _PageEntree(),
                ],
              ),
            ),
            _pied(theme),
          ],
        ),
      ),
    );
  }

  /// « Passer », à droite, sur les deux premières pages.
  ///
  /// La dernière page ne l'offre plus : elle *est* le choix, et un « Passer »
  /// y poserait une troisième issue à côté de deux qui suffisent.
  Widget _barreDeTete(ThemeData theme) {
    final derniere = _page == _nombreDePages - 1;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignConstants.spacingS,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              opacity: derniere ? 0 : 1,
              duration: DesignConstants.animationFast,
              child: TextButton(
                onPressed:
                    derniere ? null : () => _quitter(route: AppRouter.auth),
                child: Text(
                  'Passer',
                  style: AppTypography.labelLg(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pied(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        DesignConstants.spacingM,
        DesignConstants.edgeMargin,
        DesignConstants.spacingL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Grains(page: _page, total: _nombreDePages),
          const SizedBox(height: DesignConstants.spacingL),
          if (_page < _nombreDePages - 1) ...[
            ActionButton(
              label: _page == 0 ? 'Commencer' : 'Suivant',
              emphasis: ActionEmphasis.gradient,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _suivante,
            ),
            const SizedBox(height: DesignConstants.spacingS),
            ActionButton(
              label: 'J’ai déjà un compte',
              emphasis: ActionEmphasis.text,
              onPressed: () => _quitter(route: AppRouter.auth),
            ),
          ] else ...[
            ActionButton(
              label: 'Créer un compte',
              emphasis: ActionEmphasis.gradient,
              icon: Icons.mail_outline_rounded,
              onPressed: () => _quitter(route: AppRouter.auth),
            ),
            const SizedBox(height: DesignConstants.spacingS),
            ActionButton(
              label: 'Découvrir la carte sans compte',
              emphasis: ActionEmphasis.outlined,
              onPressed: () => _quitter(route: null),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            Text(
              'En continuant, vous acceptez nos conditions d’utilisation '
              'et notre politique de confidentialité.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- pages

/// `onboarding_welcome` — « Gourmet at Heart. Fast by Nature. »
class _PageAccueil extends StatelessWidget {
  const _PageAccueil();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Feuille(
      illustration: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignConstants.spacingL),
            child: FittedBox(
              child: Text(
                'El Corazón',
                textAlign: TextAlign.center,
                style: AppTypography.displayLg(
                  color: theme.colorScheme.onPrimary,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
      ),
      titre: 'Le goût du soin,\nla vitesse en prime.',
      texte: 'La cuisine de ${AppConstants.defaultCityName} grillée au feu '
          'de bois, livrée chaude jusque chez vous.',
    );
  }
}

/// `onboarding_tracking_highlight` — « Track Every Bite »
class _PageSuivi extends StatelessWidget {
  const _PageSuivi();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Feuille(
      illustration: Container(
        color: theme.colorScheme.surfaceContainerLow,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // La pastille de la maquette annonce « Arriving in 12 min ».
                // Ici elle ne porte **aucune durée** : ce serait une
                // estimation, et il n'y a pas de commande à estimer sur un
                // écran de présentation.
                StatusChip(
                  label: 'Suivi en direct',
                  icon: Icons.two_wheeler_rounded,
                  background: theme.colorScheme.primary,
                  foreground: theme.colorScheme.onPrimary,
                ),
                const SizedBox(height: DesignConstants.spacingL),
                const _Trajet(),
              ],
            ),
          ),
        ),
      ),
      titre: 'Suivez chaque étape.',
      texte: 'Du gril à votre porte, voyez où en est votre commande, '
          'minute par minute.',
    );
  }
}

/// `onboarding_authentication_options`, amputé de Google et Apple (BR-001).
class _PageEntree extends StatelessWidget {
  const _PageEntree();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Feuille(
      illustration: Container(
        color: theme.colorScheme.surfaceContainerLow,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignConstants.spacingL),
            child: Image.asset(
              'assets/logo/logo.png',
              height: 140,
              fit: BoxFit.contain,
              // Le logo est un asset embarqué : s'il manque, c'est une erreur
              // de compilation d'assets, pas un incident réseau. Le repli
              // évite néanmoins un carré rouge en plein premier écran.
              errorBuilder: (_, __, ___) => Icon(
                Icons.restaurant_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
      titre: 'Bienvenue chez El Corazón.',
      texte: 'Créez votre compte pour commander, suivre vos livraisons '
          'et cumuler des points.',
    );
  }
}

// -------------------------------------------------------------- structure

/// Le gabarit commun aux trois pages : une illustration en haut, un titre et
/// un texte en bas.
///
/// L'illustration prend une **part** de la hauteur plutôt qu'un nombre de
/// pixels : sur un téléphone de 320 × 640 avec la police grossie, une hauteur
/// fixe de 320 px ne laissait plus de place au titre.
class _Feuille extends StatelessWidget {
  const _Feuille({
    required this.illustration,
    required this.titre,
    required this.texte,
  });

  final Widget illustration;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, contraintes) {
        final hauteurIllustration = (contraintes.maxHeight * 0.52).clamp(
          160.0,
          420.0,
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contraintes.maxHeight),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.edgeMargin,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      DesignConstants.radiusXLarge,
                    ),
                    child: SizedBox(
                      height: hauteurIllustration,
                      width: double.infinity,
                      child: illustration,
                    ),
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXL),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.spacingXL,
                  ),
                  child: Column(
                    children: [
                      Text(
                        titre,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMd(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: DesignConstants.spacingM),
                      Text(
                        texte,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLg(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingL),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Les trois jalons du suivi — cuisine, livreur, porte — reliés par un trait.
class _Trajet extends StatelessWidget {
  const _Trajet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget jalon(IconData icone, String libelle, bool actif) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DesignConstants.avatarSizeMedium,
            height: DesignConstants.avatarSizeMedium,
            decoration: BoxDecoration(
              color: actif
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icone,
              size: DesignConstants.iconSizeMedium,
              color: actif
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            libelle,
            style: AppTypography.labelLg(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    Widget trait(bool actif) {
      return Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(
            bottom: 22,
            left: DesignConstants.spacingXS,
            right: DesignConstants.spacingXS,
          ),
          color: actif
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      );
    }

    return Row(
      children: [
        jalon(Icons.storefront_rounded, 'Cuisine', true),
        trait(true),
        jalon(Icons.two_wheeler_rounded, 'En route', true),
        trait(false),
        jalon(Icons.home_rounded, 'Chez vous', false),
      ],
    );
  }
}

/// Les grains de progression sous les pages.
class _Grains extends StatelessWidget {
  const _Grains({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: DesignConstants.animationNormal,
            curve: DesignConstants.curveEaseOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            // Le grain courant s'allonge au lieu de simplement changer de
            // teinte : la position se lit alors sans distinguer deux nuances
            // de rouge, ce qui compte pour un daltonien.
            width: i == page ? 24 : 6,
            decoration: BoxDecoration(
              color: i == page
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
