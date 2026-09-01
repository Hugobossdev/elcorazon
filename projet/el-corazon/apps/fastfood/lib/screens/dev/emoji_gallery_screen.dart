import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// La planche de relecture du pack emojis — outil interne.
///
/// Pourquoi cet écran existe
/// -------------------------
///
/// Les trente illustrations ne se jugent pas une par une. Ce qui fait un pack,
/// c'est la constance : même angle de caméra, même éclairage, mêmes
/// proportions, même palette. Un burger dessiné seul peut être très bon et
/// détonner à côté d'une pizza vue de trois quarts. Il faut donc un endroit
/// qui les mette côte à côte, aux tailles réelles d'emploi, sur les deux fonds
/// de l'application.
///
/// Il sert aussi de constat : chaque case dit si le SVG est **embarqué** ou si
/// c'est le repli en icône qui s'affiche. C'est la liste de ce qui reste à
/// produire, tenue par le bundle lui-même plutôt que par un tableau à jour.
///
/// Il n'est pas accessible aux clients
/// -----------------------------------
///
/// [ouvrir] ne fait rien en `release`, et aucune route ne mène ici : l'écran
/// se pousse à la main depuis un point de mise au point. Le garder hors du
/// routeur évite qu'un lien traîne jusqu'en production.
class EmojiGalleryScreen extends StatefulWidget {
  const EmojiGalleryScreen({super.key});

  /// Pousse la galerie, en debug seulement.
  static Future<void> ouvrir(BuildContext context) {
    if (kReleaseMode) return Future<void>.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EmojiGalleryScreen()),
    );
  }

  @override
  State<EmojiGalleryScreen> createState() => _EmojiGalleryScreenState();
}

class _EmojiGalleryScreenState extends State<EmojiGalleryScreen> {
  /// Les chemins réellement présents dans le bundle. `null` tant que le
  /// manifeste n'a pas répondu.
  Set<String>? _embarques;

  /// Le fond sur lequel la planche se relit.
  Brightness _fond = Brightness.light;

  @override
  void initState() {
    super.initState();
    AppEmoji.assetsEmbarques().then((chemins) {
      if (mounted) setState(() => _embarques = chemins);
    });
  }

  @override
  Widget build(BuildContext context) {
    final toutes = AppEmojis.toutes;
    final embarques = _embarques;
    final presents = embarques == null
        ? 0
        : toutes.where((t) => embarques.contains(t.asset)).length;

    // La planche impose son propre thème : c'est tout l'intérêt de pouvoir
    // basculer clair / sombre sans quitter l'écran ni relancer l'application.
    return Theme(
      data: _fond == Brightness.dark ? darkTheme : lightTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Pack emojis'),
              actions: [
                IconButton(
                  tooltip: _fond == Brightness.light
                      ? 'Voir sur fond sombre'
                      : 'Voir sur fond clair',
                  icon: Icon(
                    _fond == Brightness.light
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  onPressed: () => setState(
                    () => _fond = _fond == Brightness.light
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(DesignConstants.edgeMargin),
              children: [
                _Constat(
                  present: presents,
                  total: toutes.length,
                  charge: embarques != null,
                ),
                for (final famille in AppEmojis.parFamille.entries) ...[
                  const SizedBox(height: DesignConstants.spacingL),
                  Text(
                    famille.key,
                    style: AppTypography.headlineSm(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DesignConstants.spacingS),
                  for (final token in famille.value)
                    _Planche(
                      token: token,
                      embarque: embarques?.contains(token.asset) ?? false,
                    ),
                ],
                const SizedBox(height: DesignConstants.spacingXL),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Combien des trente sont là.
class _Constat extends StatelessWidget {
  const _Constat({
    required this.present,
    required this.total,
    required this.charge,
  });

  final int present;
  final int total;
  final bool charge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complet = present == total;

    return SectionCard(
      child: Row(
        children: [
          Icon(
            complet ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            color: complet
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Text(
              charge
                  ? '$present illustration(s) embarquée(s) sur $total. '
                      'Les autres s\'affichent avec le repli en icône du '
                      'design system.'
                  : 'Lecture du manifeste…',
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les tailles auxquelles la planche montre chaque illustration.
const _tailles = [AppEmoji.tailleXS, AppEmoji.tailleM, AppEmoji.tailleL];

/// Une illustration, aux trois tailles d'emploi.
class _Planche extends StatelessWidget {
  const _Planche({required this.token, required this.embarque});

  final AppEmojiToken token;
  final bool embarque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingS),
      child: Row(
        children: [
          // Les trois tailles que le design system emploie réellement : une
          // pastille de puce, un accompagnement de titre, une illustration
          // portante. Une seule taille cacherait les silhouettes qui se
          // brouillent en petit.
          for (final taille in _tailles) ...[
            AppEmoji(token, size: taille, decoratif: true),
            const SizedBox(width: DesignConstants.spacingS),
          ],
          const SizedBox(width: DesignConstants.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  token.libelle,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  token.asset.replaceFirst('assets/emojis/', ''),
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: embarque ? 'SVG' : 'repli',
            background: embarque
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            foreground: embarque
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
