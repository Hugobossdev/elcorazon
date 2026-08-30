import 'package:elcora_fast/utils/design_constants.dart';
import 'package:flutter/material.dart';

/// Photographie d'un plat, avec ses trois états.
///
/// ## Pourquoi ce composant existe
///
/// La photographie est « le premier moteur visuel » du design system, et elle
/// vient du serveur : elle peut manquer, tarder, ou échouer. Chaque écran
/// gérait ces trois cas à sa façon — certains affichaient une icône, d'autres
/// un rectangle gris, d'autres rien du tout, laissant la carte se replier sur
/// elle-même le temps du chargement.
///
/// Les trois états sont donc traités **une fois** :
///
/// * **absente** — l'article n'a pas de photo : une icône sur fond de surface ;
/// * **en vol** — la requête est partie : le même fond, qui laisse la place
///   exacte que l'image occupera, puis un fondu de 250 ms à l'arrivée ;
/// * **échouée** — retour à l'état « absente ».
///
/// Le fondu n'est pas un ornement : sans lui, une grille qui défile fait
/// apparaître les photos par à-coups, et l'œil lit ce clignotement comme un
/// défaut de l'application.
class FoodImage extends StatelessWidget {
  const FoodImage({
    required this.url,
    super.key,
    this.fit = BoxFit.cover,
    this.heroTag,
    this.icon = Icons.restaurant_menu_rounded,
    this.iconSize = 40,
  });

  final String? url;
  final BoxFit fit;

  /// Partage la photo entre l'aperçu et le détail. `null` désactive la
  /// transition — nécessaire dès qu'une même image apparaît deux fois sur le
  /// même écran, sinon Flutter lève sur l'étiquette dupliquée.
  final String? heroTag;

  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (url == null || url!.isEmpty) return _absente(theme);

    final image = Image.network(
      url!,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronous) {
        if (wasSynchronous || frame != null) {
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: child,
          );
        }
        return _absente(theme);
      },
      errorBuilder: (context, error, stackTrace) => _absente(theme),
    );

    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }

  Widget _absente(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Voile sombre dégradé, posé sous un texte blanc sur photo.
///
/// Une photo de plat peut être claire ou sombre, et on ne le sait qu'à
/// l'exécution. Le voile garantit le contraste quoi qu'elle contienne — c'est
/// ce que le design system appelle le « text overlay gradient » de la carte
/// mise en avant.
class ImageScrim extends StatelessWidget {
  const ImageScrim({
    super.key,
    this.height,
    this.opacity = 0.75,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  /// `null` couvre toute la zone.
  final double? height;

  final double opacity;
  final Alignment begin;
  final Alignment end;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: opacity),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de note, posée en haut d'une photo.
///
/// Fond de surface à 90 % et flou : le design system la veut « glassmorphique »
/// pour qu'elle se détache d'une photo sans en masquer un morceau opaque.
class RatingBadge extends StatelessWidget {
  const RatingBadge({
    required this.rating,
    super.key,
    this.count,
    this.onDark = false,
  });

  final double rating;

  /// Nombre d'avis. Omis, seule la note s'affiche.
  final int? count;

  /// Sur fond sombre — un voile noir plutôt qu'une surface claire.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleurTexte =
        onDark ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.black.withValues(alpha: 0.55)
            : theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
        boxShadow: onDark ? null : DesignConstants.shadowLow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 14,
            // Sur fond clair, le doré lumineux disparaît : c'est le rôle
            // `secondary` foncé qui tient le contraste, et l'inverse sur une
            // photo.
            color: onDark
                ? const Color(0xFFE4C44D)
                : theme.colorScheme.secondary,
          ),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: couleurTexte,
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '($count)',
              style: TextStyle(
                color: couleurTexte.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
