import 'dart:ui';

import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Barre supérieure translucide.
///
/// ## Pourquoi un flou plutôt qu'un aplat
///
/// Le design system demande que les barres — en haut comme en bas — laissent
/// **deviner** le contenu qui défile dessous : « background blur 15–20 px,
/// 90 % d'opacité de la surface ». C'est ce qui dit à l'utilisateur qu'il n'a
/// pas changé de page, seulement fait défiler la sienne. Un aplat opaque coupe
/// l'écran en deux et perd cette information.
///
/// ## Le coût, et pourquoi il est acceptable ici
///
/// Chaque [BackdropFilter] refiltre le fond à chaque image. Sur une grille qui
/// défile, en empiler un par carte s'écroule — c'est pourquoi
/// `MenuItemCard` s'en interdit l'usage. Ici il n'y en a **qu'un par écran**,
/// fixe, sur une bande de 64 px : le coût est constant et négligeable.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.foregroundColor,
  });

  final String? title;

  /// Remplace complètement le titre — pour l'accueil, dont l'entête porte
  /// l'avatar et l'adresse de livraison plutôt qu'un intitulé.
  final Widget? titleWidget;

  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  /// Par défaut le rouge de marque : dans les maquettes, le titre d'un écran
  /// transactionnel est rouge, pas noir.
  final Color? foregroundColor;

  static const double hauteur = 64;

  @override
  Size get preferredSize =>
      Size.fromHeight(hauteur + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleurTitre = foregroundColor ?? theme.colorScheme.primary;
    final peutRevenir = showBack && Navigator.of(context).canPop();

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlur,
          sigmaY: AppColors.glassBlur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: hauteur,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignConstants.spacingS,
                    ),
                    child: Row(
                      children: [
                        if (leading != null)
                          leading!
                        else if (peutRevenir)
                          _BoutonRond(
                            icone: Icons.arrow_back_rounded,
                            semantique: 'Retour',
                            onTap: onBack ?? () => Navigator.of(context).pop(),
                          )
                        else
                          const SizedBox(width: DesignConstants.spacingS),
                        Expanded(
                          child: titleWidget ??
                              (title == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      title!,
                                      textAlign: centerTitle
                                          ? TextAlign.center
                                          : TextAlign.start,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.headlineSm(
                                        color: couleurTitre,
                                      ),
                                    )),
                        ),
                        // Contrepoids du bouton retour : sans lui, un titre
                        // centré se décale de la largeur de la flèche.
                        if (actions != null && actions!.isNotEmpty)
                          ...actions!
                        else if (centerTitle && (peutRevenir || leading != null))
                          const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre ancrée en bas de l'écran, translucide elle aussi.
///
/// Sert de socle au récapitulatif de panier collant et aux actions de
/// règlement. Le rembourrage bas suit l'encoche (`SafeArea`) : sans lui, le
/// bouton « Commander » se glisse sous la barre gestuelle d'Android.
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DesignConstants.edgeMargin,
      vertical: DesignConstants.spacingM,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlur,
          sigmaY: AppColors.glassBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            boxShadow: DesignConstants.shadowBottomBar,
          ),
          child: SafeArea(
            top: false,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Pastille tactile ronde de 44 px — la cible minimale du design system.
class _BoutonRond extends StatelessWidget {
  const _BoutonRond({
    required this.icone,
    required this.onTap,
    required this.semantique,
  });

  final IconData icone;
  final VoidCallback onTap;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semantique,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icone, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Bouton rond posé sur une barre — même cible tactile, réutilisable depuis
/// les écrans qui composent leurs propres actions.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.badge,
    this.filled = true,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  /// Compteur affiché en pastille. `null` ou `0` n'affiche rien.
  final int? badge;

  /// Un fond `surfaceContainer` derrière l'icône, comme la cloche de l'accueil.
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teinte = color ?? theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: filled ? theme.colorScheme.surfaceContainer : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: teinte),
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: AppTypography.labelLg(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 10, letterSpacing: 0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
