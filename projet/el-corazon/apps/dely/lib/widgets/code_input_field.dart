import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saisie d'un code à usage unique — une case par chiffre.
///
/// ## Ce que ce widget prend en charge, et pourquoi
///
/// Un champ de texte ordinaire ferait l'affaire fonctionnellement. Il ne ferait
/// pas l'affaire *en service* : le livreur saisit ce code une main sur le
/// guidon, sous le soleil, en basculant vers son application de courriel et en
/// revenant. Chacun des comportements ci-dessous existe pour un de ces
/// moments-là.
///
/// * **Avance et recul automatiques.** Un chiffre tapé passe à la case
///   suivante ; `Retour arrière` sur une case vide revient à la précédente et
///   l'efface. Sans le second, corriger une faute demande de viser une case de
///   quarante pixels.
/// * **Collage.** Coller les six chiffres dans n'importe quelle case les
///   répartit sur toutes. C'est le geste naturel après « copier » depuis le
///   courriel, et un champ par chiffre le casse par défaut — le collage
///   n'atterrirait que dans la case visée.
/// * **Validation automatique.** [onCompleted] part dès que la dernière case
///   est remplie. Un bouton reste affiché à côté : l'envoi automatique échoue
///   parfois (réseau), et il faut alors pouvoir réessayer sans tout retaper.
/// * **Chiffres seulement**, clavier numérique, et aucune suggestion : le code
///   n'est pas un mot.
///
/// La longueur n'est pas figée à six : elle vient du serveur
/// (`code_length`, `ACCOUNT_VERIFICATION_CODE_LENGTH`). Une grille qui
/// refuserait un code que le serveur vient d'envoyer serait un blocage sans
/// message compréhensible.
class CodeInputField extends StatefulWidget {
  const CodeInputField({
    required this.length,
    required this.onCompleted,
    super.key,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  final int length;

  /// Appelé quand toutes les cases sont remplies.
  final ValueChanged<String> onCompleted;

  /// Appelé à chaque frappe — sert à effacer le message d'erreur précédent dès
  /// que le livreur recommence à taper.
  final ValueChanged<String>? onChanged;

  final bool enabled;

  /// Colore les cases en rouge après un refus du serveur.
  final bool hasError;

  @override
  State<CodeInputField> createState() => CodeInputFieldState();
}

class CodeInputFieldState extends State<CodeInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(CodeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La longueur vient du serveur : elle peut changer entre la construction de
    // l'écran (valeur par défaut) et la réponse à la demande de code.
    if (oldWidget.length != widget.length) {
      _disposeAll();
      _controllers = List.generate(widget.length, (_) => TextEditingController());
      _focusNodes = List.generate(widget.length, (_) => FocusNode());
    }
  }

  void _disposeAll() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
  }

  @override
  void dispose() {
    _disposeAll();
    super.dispose();
  }

  String get value => _controllers.map((controller) => controller.text).join();

  /// Vide la grille et rend le curseur à la première case.
  ///
  /// Appelé par l'écran après un refus : le code précédent ne vaut plus rien,
  /// et le laisser affiché invite à réappuyer sur « Valider » avec la même
  /// valeur.
  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    if (mounted) {
      _focusNodes.first.requestFocus();
    }
  }

  void _ecrire(int index, String chiffre) {
    // La sélection est posée en fin de texte à chaque écriture : c'est ce qui
    // rend la frappe suivante prévisible, donc ce qui permet plus bas de
    // prendre « le dernier caractère » comme étant le chiffre voulu.
    _controllers[index].value = TextEditingValue(
      text: chiffre,
      selection: TextSelection.collapsed(offset: chiffre.length),
    );
  }

  void _onChanged(int index, String saisie) {
    final chiffres = saisie.replaceAll(RegExp(r'\D'), '');

    // Collage : le code entier arrive d'un coup dans une seule case, quelle
    // qu'elle soit. Le seuil est la longueur complète et non « plus d'un
    // chiffre », pour ne pas confondre un collage avec une frappe qui écrase
    // une case déjà remplie.
    if (chiffres.length >= widget.length) {
      _repartir(chiffres.substring(0, widget.length));
      return;
    }

    final chiffre = chiffres.isEmpty ? '' : chiffres[chiffres.length - 1];
    _ecrire(index, chiffre);
    if (chiffre.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _annoncer();
  }

  void _repartir(String chiffres) {
    for (var i = 0; i < widget.length; i++) {
      _ecrire(i, i < chiffres.length ? chiffres[i] : '');
    }
    _focusNodes[widget.length - 1].requestFocus();
    _annoncer();
  }

  void _annoncer() {
    final code = value;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      // Le clavier a fini son office ; le garder ouvert masquerait le message
      // de résultat sur un petit écran.
      FocusScope.of(context).unfocus();
      widget.onCompleted(code);
    }
  }

  /// `Retour arrière` sur une case vide : revenir en arrière et effacer.
  ///
  /// Sans cela, le curseur reste bloqué sur une case déjà vide et le livreur
  /// doit viser la précédente au doigt.
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;
    if (_controllers[index].text.isNotEmpty || index == 0) return KeyEventResult.ignored;

    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    widget.onChanged?.call(value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bordure = widget.hasError ? theme.colorScheme.error : theme.colorScheme.outline;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // `Focus` en simple observateur — il ne prend jamais le curseur,
            // il ne fait que voir remonter les touches du champ qu'il
            // enveloppe. Un `KeyboardListener` avec son propre nœud de focus
            // disputerait le curseur au `TextField`.
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (_, event) => _onKey(index, event),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                autofocus: index == 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                // Le code n'est pas un mot : ni correction, ni suggestion, ni
                // majuscule automatique.
                autocorrect: false,
                enableSuggestions: false,
                // Une case ne contient qu'un chiffre — mais le collage arrive
                // par `onChanged` avant que la limite ne s'applique, ce qui est
                // exactement ce qui permet de le répartir.
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bordure.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: widget.hasError ? theme.colorScheme.error : theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bordure.withValues(alpha: 0.15)),
                  ),
                ),
                // Tout sélectionner au toucher : taper sur une case déjà
                // remplie la remplace, au lieu d'insérer un second chiffre à
                // côté du premier.
                onTap: () => _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                ),
                onChanged: (saisie) => _onChanged(index, saisie),
              ),
            ),
          ),
        );
      }),
    );
  }
}
