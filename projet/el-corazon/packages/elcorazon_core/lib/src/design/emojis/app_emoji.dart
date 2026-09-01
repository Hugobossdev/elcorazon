import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'package:elcorazon_core/src/design/emojis/app_emojis.dart';

/// Le seul endroit où une illustration du pack est rendue.
///
/// Pourquoi ce composant existe
/// ----------------------------
///
/// Centraliser le rendu, et non seulement les chemins. Trois choses s'y
/// décident une fois pour toutes plutôt qu'à chaque appel : la taille, ce que
/// le lecteur d'écran annonce, et **ce qui s'affiche quand l'illustration
/// n'est pas là**.
///
/// ## Le repli, et pourquoi il n'est pas provisoire
///
/// Les trente SVG se dessinent en plusieurs vagues. Un `SvgPicture.asset`
/// pointé sur un fichier absent lève à la construction : carré rouge en debug,
/// zone vide en production. Migrer l'interface aurait donc supposé d'attendre
/// le pack complet, et de tout basculer d'un coup — exactement la manœuvre
/// qu'on ne veut pas faire sur une application en service.
///
/// [AppEmoji] lit une fois le manifeste d'assets du bundle et sert :
///
/// * l'illustration, si le SVG est embarqué ;
/// * sinon l'icône du design system portée par le token
///   ([AppEmojiToken.repli]).
///
/// Déposer un fichier dans `assets/emojis/` suffit alors à faire basculer tous
/// ses points d'appel, sans toucher une ligne de code. Et le repli n'est
/// jamais un emoji Unicode : le but n'est pas de repousser le problème, c'est
/// de sortir l'interface du rendu emoji du système.
///
/// ## Ce qu'il ne faut pas lui faire porter
///
/// Ni une icône de navigation, ni une photo produit — voir l'en-tête de
/// `app_emojis.dart`.
class AppEmoji extends StatefulWidget {
  const AppEmoji(
    this.token, {
    super.key,
    this.size = tailleM,
    this.color,
    this.semanticsLabel,
    this.decoratif = false,
  });

  /// L'illustration à rendre, prise dans [AppEmojis].
  final AppEmojiToken token;

  /// Le côté du carré. Les illustrations sont carrées par contrat.
  final double size;

  /// Teinte **du repli seulement**.
  ///
  /// L'illustration porte ses propres couleurs — la reteindre ferait
  /// disparaître le travail de matière et d'éclairage qui fait tout le pack.
  /// Ce paramètre existe pour que l'icône de repli suive l'encre de son
  /// contenant : dans une puce sélectionnée, elle doit passer en `onPrimary`
  /// comme le texte à côté d'elle. `null` la laisse suivre l'`IconTheme`.
  final Color? color;

  /// Ce que le lecteur d'écran annonce. À défaut, [AppEmojiToken.libelle].
  final String? semanticsLabel;

  /// L'illustration est purement ornementale.
  ///
  /// Elle est alors retirée de l'arbre d'accessibilité : le texte voisin dit
  /// déjà tout. C'est le cas le plus fréquent — une pastille de catégorie
  /// posée devant l'intitulé « Burgers » n'a rien à ajouter.
  ///
  /// Une information critique ne doit jamais reposer sur la seule
  /// illustration : si rien à côté ne la porte, laisser `false`.
  final bool decoratif;

  // ---------------------------------------------------------------- tailles

  /// Pastille posée dans une puce ou une ligne de liste.
  static const double tailleXS = 20;

  /// Petit élément accompagnant un intitulé.
  static const double tailleS = 24;

  /// La taille standard.
  static const double tailleM = 32;

  /// Illustration portante — en-tête de section, carte d'état.
  static const double tailleL = 48;

  /// État vide, écran de succès, illustration d'accueil.
  static const double tailleHero = 96;

  /// Charge le manifeste d'assets à l'avance.
  ///
  /// Facultatif : sans lui, la première [AppEmoji] montée déclenche la lecture
  /// et se redessine une fois. L'appeler au démarrage évite ce clignotement du
  /// repli vers l'illustration sur le premier écran.
  static Future<void> precharger() => _ManifesteEmojis.charger();

  /// Les chemins du pack réellement embarqués — ce que la galerie de
  /// relecture compare aux trente attendus.
  static Future<Set<String>> assetsEmbarques() => _ManifesteEmojis.charger();

  @override
  State<AppEmoji> createState() => _AppEmojiState();
}

class _AppEmojiState extends State<AppEmoji> {
  Set<String>? _embarques;

  @override
  void initState() {
    super.initState();
    // Déjà lu : on peint l'illustration dès la première frame.
    _embarques = _ManifesteEmojis.connusOuNull;
    if (_embarques == null) {
      _ManifesteEmojis.charger().then((chemins) {
        if (mounted) setState(() => _embarques = chemins);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final disponible = _embarques?.contains(token.asset) ?? false;

    final dessin = disponible
        ? SvgPicture.asset(
            token.asset,
            width: widget.size,
            height: widget.size,
          )
        : Icon(token.repli, size: widget.size, color: widget.color);

    // Une taille explicite dans les deux branches : l'icône de repli et le
    // SVG n'occupent pas tout à fait la même boîte, et une pastille qui change
    // de largeur au chargement décale la ligne entière.
    final boite = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: dessin),
    );

    if (widget.decoratif) return ExcludeSemantics(child: boite);

    return Semantics(
      image: true,
      label: widget.semanticsLabel ?? token.libelle,
      excludeSemantics: true,
      child: boite,
    );
  }
}

/// Le manifeste des assets embarqués, lu une fois pour toute l'application.
///
/// La lecture passe par `rootBundle`, donc par le disque : la refaire à chaque
/// construction de puce de catégorie coûterait cher pour une réponse qui ne
/// change jamais de la vie du processus. Le `Future` est mémorisé, et tous les
/// appelants attendent le même.
abstract final class _ManifesteEmojis {
  /// Le pack vit dans `elcorazon_core`, pas dans l'application : le manifeste
  /// le publie donc sous le préfixe `packages/<paquet>/`. Les trente SVG
  /// n'existent ainsi qu'en un seul exemplaire pour les trois applications.
  static const _racineDuPack = 'packages/elcorazon_core/assets/emojis/';

  static Set<String>? _connus;
  static Future<Set<String>>? _enCours;

  /// Le résultat s'il est déjà là, `null` sinon. Jamais bloquant.
  static Set<String>? get connusOuNull => _connus;

  static Future<Set<String>> charger() => _enCours ??= _lire();

  static Future<Set<String>> _lire() async {
    try {
      final manifeste = await AssetManifest.loadFromAssetBundle(rootBundle);
      // Seuls les chemins du pack nous intéressent : garder le manifeste
      // entier en mémoire pour trente entrées n'aurait pas de sens.
      return _connus = manifeste
          .listAssets()
          .where((chemin) => chemin.startsWith(_racineDuPack))
          .toSet();
    } catch (_) {
      // Pas de manifeste : test unitaire sans binding, plateforme sans
      // bundle. Tout se replie sur les icônes, ce qui reste un écran juste.
      return _connus = const <String>{};
    }
  }
}
