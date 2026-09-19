import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Signale chaque interaction de l'opérateur — clic, toucher, molette, touche.
///
/// C'est ce qui repousse la déconnexion automatique
/// (`AdminAuthService.recordActivity`). Sans lui, le minuteur partait à la
/// connexion et rien ne le repoussait : trente minutes après s'être connecté,
/// un opérateur en plein service se retrouvait sur l'écran de connexion.
///
/// ## Pourquoi au-dessus du `Navigator`
///
/// Posé dans `MaterialApp.builder`, il voit aussi les boîtes de dialogue et les
/// pages poussées : un formulaire de dix minutes saisi dans une boîte de
/// dialogue est une activité, et c'est même là qu'une déconnexion coûte le plus.
///
/// ## Ce qu'il ne fait pas
///
/// Il n'intercepte rien : le `Listener` est translucide et le gestionnaire de
/// clavier rend `false`, si bien que l'événement poursuit sa route comme s'il
/// n'était pas là. Le simple survol de la souris ne compte pas — un curseur qui
/// bouge sur un poste laissé ouvert n'est pas quelqu'un qui travaille.
class SuiviActivite extends StatefulWidget {
  const SuiviActivite({required this.onActivite, required this.child, super.key});

  final VoidCallback onActivite;
  final Widget child;

  @override
  State<SuiviActivite> createState() => _SuiviActiviteState();
}

class _SuiviActiviteState extends State<SuiviActivite> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_surTouche);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_surTouche);
    super.dispose();
  }

  bool _surTouche(KeyEvent evenement) {
    if (evenement is KeyDownEvent) widget.onActivite();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => widget.onActivite(),
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) widget.onActivite();
      },
      child: widget.child,
    );
  }
}
