import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Les trois emphases de bouton du design system.
enum ActionEmphasis {
  /// Aplat rouge, texte blanc. L'action principale d'un écran.
  primary,

  /// Rouge → orange. Réservé au règlement (« Passer la commande »), où le
  /// dégradé signale qu'on franchit une étape, pas qu'on navigue.
  gradient,

  /// Fond de surface, liseré rouge. L'alternative crédible à l'action
  /// principale, pas un lien déguisé.
  outlined,

  /// Sans fond ni liseré. Une action tertiaire, qu'on peut ignorer.
  text,
}

/// Bouton d'action, uniformisé sur les maquettes.
///
/// ## Pourquoi il double `ElevatedButton`
///
/// Trois besoins que le thème seul ne couvre pas : le **dégradé** (Material
/// ne peint qu'un aplat), l'**état de chargement** qui doit conserver la
/// largeur du bouton pour ne pas faire sauter la mise en page, et le **retrait
/// à la pression** (`active:scale-95`) que toutes les maquettes appliquent.
///
/// Le retrait n'est pas décoratif : sur un téléphone, le doigt masque le
/// bouton qu'il touche, et l'échelle est le seul retour visible sur les bords.
class ActionButton extends StatefulWidget {
  const ActionButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.emphasis = ActionEmphasis.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.height = 52,
    this.foregroundColor,
    this.backgroundColor,
  });

  final String label;

  /// `null` grise le bouton — c'est aussi ce qui l'empêche d'être pressé
  /// pendant un chargement.
  final VoidCallback? onPressed;

  final ActionEmphasis emphasis;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;

  /// Prend toute la largeur disponible. Vrai par défaut : sur mobile, une
  /// action principale à mi-largeur se touche moins bien et se voit moins.
  final bool expand;

  final double height;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _presse = false;

  bool get _actif => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rayon = BorderRadius.circular(DesignConstants.radiusMedium);

    final (Color fond, Color texte, Gradient? degrade, BoxBorder? contour) =
        _apparence(theme);

    return Semantics(
      button: true,
      enabled: _actif,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _actif ? (_) => setState(() => _presse = true) : null,
        onTapUp: _actif ? (_) => setState(() => _presse = false) : null,
        onTapCancel: _actif ? () => setState(() => _presse = false) : null,
        onTap: _actif ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _presse ? 0.96 : 1,
          duration: DesignConstants.animationFast,
          curve: DesignConstants.curveStandard,
          child: AnimatedOpacity(
            opacity: _actif ? 1 : 0.5,
            duration: DesignConstants.animationFast,
            child: Container(
              width: widget.expand ? double.infinity : null,
              height: widget.height,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignConstants.spacingL,
              ),
              decoration: BoxDecoration(
                color: degrade == null ? fond : null,
                gradient: degrade,
                borderRadius: rayon,
                border: contour,
                boxShadow: _actif && widget.emphasis == ActionEmphasis.gradient
                    ? DesignConstants.shadowPrimary
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(texte),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 20, color: texte),
                            const SizedBox(width: DesignConstants.spacingS),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(color: texte),
                            ),
                          ),
                          if (widget.trailingIcon != null) ...[
                            const SizedBox(width: DesignConstants.spacingS),
                            Icon(widget.trailingIcon, size: 20, color: texte),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, Gradient?, BoxBorder?) _apparence(ThemeData theme) {
    switch (widget.emphasis) {
      case ActionEmphasis.primary:
        return (
          widget.backgroundColor ?? theme.colorScheme.primary,
          widget.foregroundColor ?? theme.colorScheme.onPrimary,
          null,
          null,
        );
      case ActionEmphasis.gradient:
        return (
          Colors.transparent,
          widget.foregroundColor ?? AppColors.textLight,
          // Horizontal — c'est l'orientation par défaut d'un
          // `LinearGradient`, et celle que veut la maquette : le dégradé
          // accompagne le sens de lecture jusqu'au libellé de l'action au
          // lieu de traverser le bouton en diagonale.
          const LinearGradient(colors: AppColors.actionGradient),
          null,
        );
      case ActionEmphasis.outlined:
        return (
          widget.backgroundColor ?? theme.colorScheme.surface,
          widget.foregroundColor ?? theme.colorScheme.primary,
          null,
          Border.all(color: theme.colorScheme.primary),
        );
      case ActionEmphasis.text:
        return (
          Colors.transparent,
          widget.foregroundColor ?? theme.colorScheme.primary,
          null,
          null,
        );
    }
  }
}
