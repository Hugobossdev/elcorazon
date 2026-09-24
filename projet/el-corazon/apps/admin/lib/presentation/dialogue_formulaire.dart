import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/echec.dart';

/// Construit le corps d'un formulaire. [echec] porte le dernier refus du
/// serveur : `echec?.pourLeChamp('points_cost')` se pose en `errorText` sous
/// le champ concerné.
typedef CorpsDeFormulaire = Widget Function(BuildContext context, Echec? echec);

/// Dialogue de saisie qui **attend** le serveur avant de se fermer.
///
/// ## Le défaut qu'il remplace
///
/// Les formulaires du back-office appelaient le service puis fermaient le
/// dialogue aussitôt, sans attendre : sur un refus, la saisie était perdue et
/// l'erreur n'était affichée nulle part (la gamification entière fonctionnait
/// ainsi, et ses créations revenaient toutes en 400 sans que personne le
/// sache). D'autres fermaient d'abord, puis affichaient le résultat avec le
/// contexte du dialogue déjà détruit — donc jamais.
///
/// Ici :
///
/// 1. la validation locale passe d'abord (elle reprend les règles du serveur,
///    pour éviter l'aller-retour évident) ;
/// 2. [enregistrer] est **attendu**, bouton désactivé et indicateur affiché ;
/// 3. un refus garde le dialogue ouvert, la saisie intacte, la raison du
///    serveur en bandeau et sous chaque champ fautif ;
/// 4. le dialogue ne se ferme qu'après confirmation du serveur, en rendant
///    `true` — c'est à l'appelant d'annoncer le succès.
class DialogueDeFormulaire extends StatefulWidget {
  const DialogueDeFormulaire({
    required this.titre,
    required this.corps,
    required this.enregistrer,
    this.libelleAction = 'Enregistrer',
    this.largeur = 560,
    super.key,
  });

  final String titre;
  final CorpsDeFormulaire corps;

  /// L'écriture. Lève `ApiException` sur un refus.
  final Future<void> Function() enregistrer;

  final String libelleAction;
  final double largeur;

  /// Ouvre le dialogue ; rend `true` si le serveur a confirmé l'écriture.
  static Future<bool> ouvrir(
    BuildContext context, {
    required String titre,
    required CorpsDeFormulaire corps,
    required Future<void> Function() enregistrer,
    String libelleAction = 'Enregistrer',
  }) async {
    final confirme = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogueDeFormulaire(
        titre: titre,
        corps: corps,
        enregistrer: enregistrer,
        libelleAction: libelleAction,
      ),
    );
    return confirme ?? false;
  }

  @override
  State<DialogueDeFormulaire> createState() => _DialogueDeFormulaireState();
}

class _DialogueDeFormulaireState extends State<DialogueDeFormulaire> {
  final _formulaire = GlobalKey<FormState>();
  bool _enCours = false;
  Echec? _echec;

  Future<void> _soumettre() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    setState(() {
      _enCours = true;
      _echec = null;
    });
    try {
      await widget.enregistrer();
      if (mounted) Navigator.of(context).pop(true);
    } on eccore.ApiException catch (e) {
      if (mounted) setState(() => _echec = Echec.de(e));
    } on eccore.SessionExpiredException catch (e) {
      if (mounted) setState(() => _echec = Echec.de(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.of(context).size.height * 0.85;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.largeur, maxHeight: hauteur),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titre,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer sans enregistrer',
                    onPressed: _enCours ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            if (_echec != null) BandeauEchec(echec: _echec!),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(key: _formulaire, child: widget.corps(context, _echec)),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _enCours ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _enCours ? null : () => unawaited(_soumettre()),
                    child: _enCours
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.libelleAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Validateurs qui reprennent ceux du serveur — pour éviter l'aller-retour
/// évident, jamais pour les remplacer.
abstract final class Valider {
  static String? requis(String? valeur, {String message = 'Champ requis'}) =>
      (valeur == null || valeur.trim().isEmpty) ? message : null;

  /// Entier ≥ [minimum].
  static String? entier(String? valeur, {int minimum = 0, String? message}) {
    final nombre = int.tryParse((valeur ?? '').trim());
    if (nombre == null) return 'Nombre entier attendu';
    if (nombre < minimum) return message ?? 'Au moins $minimum';
    return null;
  }

  /// Montant en unité majeure, > 0 si [strictementPositif].
  static String? montant(String? valeur, {bool strictementPositif = true}) {
    final nombre = double.tryParse((valeur ?? '').trim().replaceAll(',', '.'));
    if (nombre == null) return 'Montant attendu';
    if (strictementPositif && nombre <= 0) return 'Le montant doit être positif';
    if (nombre < 0) return 'Le montant ne peut pas être négatif';
    return null;
  }

  /// Champ facultatif : vide accepté, sinon entier ≥ [minimum].
  static String? entierFacultatif(String? valeur, {int minimum = 1}) =>
      (valeur == null || valeur.trim().isEmpty) ? null : entier(valeur, minimum: minimum);

  /// Champ facultatif : vide accepté, sinon montant > 0.
  static String? montantFacultatif(String? valeur) =>
      (valeur == null || valeur.trim().isEmpty) ? null : montant(valeur);
}

/// Lit un montant saisi (virgule ou point).
double? lireMontant(String texte) => double.tryParse(texte.trim().replaceAll(',', '.'));

/// Un montant majeur tel qu'on le saisit : sans décimale inutile.
String montantEnSaisie(double montant) =>
    montant == montant.roundToDouble() ? montant.toStringAsFixed(0) : montant.toStringAsFixed(2);
