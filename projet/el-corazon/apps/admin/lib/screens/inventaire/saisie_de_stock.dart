import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/ui/ui.dart';

/// Ce qu'un formulaire d'écriture de stock a recueilli.
class SaisieDeStock {
  const SaisieDeStock({
    required this.quantite,
    required this.cle,
    this.prix,
    this.reference = '',
    this.motif = '',
  });

  final eccore.Quantity quantite;
  final eccore.Money? prix;
  final String reference;
  final String motif;

  /// La clé de la tentative — la même à chaque réessai du même formulaire.
  final String cle;
}

/// Le formulaire commun à la réception, à la perte et au comptage.
///
/// ## L'envoi se fait **dans** le dialogue
///
/// Et non après sa fermeture. Deux raisons, qui tiennent ensemble :
///
/// * la **clé de tentative** vit aussi longtemps que le formulaire. Un envoi
///   perdu, puis « Réessayer », repart avec la même clé, et le serveur rend la
///   réception déjà écrite au lieu d'en créditer une seconde ;
/// * un **refus** — dimension incohérente, stock insuffisant, permission
///   manquante — s'affiche sous les champs, qui restent remplis. Fermer le
///   dialogue pour montrer l'erreur ferait tout ressaisir.
class DialogueDeSaisie extends StatefulWidget {
  const DialogueDeSaisie({
    required this.titre,
    required this.dimension,
    required this.libelleQuantite,
    required this.envoyer,
    this.explication,
    this.avecPrix = false,
    this.devise = '',
    this.avecReference = false,
    this.motifObligatoire = false,
    this.pourUneLivraison = false,
    super.key,
  });

  final String titre;
  final String? explication;
  final String dimension;
  final String libelleQuantite;
  final bool avecPrix;
  final String devise;
  final bool avecReference;
  final bool motifObligatoire;
  final bool pourUneLivraison;

  /// Fait l'écriture et rend la phrase à afficher à la personne. Lève en cas
  /// de refus : le message du serveur est alors montré sous les champs.
  final Future<String> Function(SaisieDeStock saisie) envoyer;

  @override
  State<DialogueDeSaisie> createState() => _DialogueDeSaisieState();
}

class _DialogueDeSaisieState extends State<DialogueDeSaisie> {
  final _cle = CleDeTentative();
  final _quantite = TextEditingController();
  final _prix = TextEditingController();
  final _reference = TextEditingController();
  final _motif = TextEditingController();
  late String _unite = unitesDeSaisie(
    widget.dimension,
    pourUneLivraison: widget.pourUneLivraison,
  ).first;

  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _quantite.dispose();
    _prix.dispose();
    _reference.dispose();
    _motif.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final eccore.Quantity quantite;
    eccore.Money? prix;
    try {
      quantite = eccore.Quantity.saisie(_quantite.text, _unite);
      if (widget.avecPrix) prix = prixDuLot(_prix.text, devise: widget.devise);
    } on FormatException catch (erreur) {
      setState(() => _erreur = erreur.message);
      return;
    }
    if (widget.motifObligatoire && _motif.text.trim().isEmpty) {
      setState(() => _erreur = 'Le motif est obligatoire : il dit pourquoi le stock a bougé.');
      return;
    }

    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      final message = await widget.envoyer(
        SaisieDeStock(
          quantite: quantite,
          prix: prix,
          reference: _reference.text.trim(),
          motif: _motif.text.trim(),
          cle: _cle.valeur,
        ),
      );
      if (mounted) Navigator.of(context).pop(message);
    } catch (erreur) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = messageErreur(erreur);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unites = unitesDeSaisie(widget.dimension, pourUneLivraison: widget.pourUneLivraison);

    return AlertDialog(
      title: Text(widget.titre),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.explication != null) ...[
                Text(widget.explication!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantite,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: widget.libelleQuantite),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _unite,
                    items: [
                      for (final unite in unites)
                        DropdownMenuItem(value: unite, child: Text(libelleUnite(unite))),
                    ],
                    onChanged: _envoi ? null : (unite) => setState(() => _unite = unite!),
                  ),
                ],
              ),
              if (widget.avecPrix) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _prix,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Prix du lot (${widget.devise}) — facultatif',
                    helperText: 'Le montant de la facture. Le coût au kilogramme en est déduit.',
                  ),
                ),
              ],
              if (widget.avecReference) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reference,
                  maxLength: 64,
                  decoration: const InputDecoration(labelText: 'Bon de livraison — facultatif'),
                ),
              ],
              if (widget.motifObligatoire) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _motif,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Motif'),
                ),
              ],
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _erreur!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AdminColorTokens.semantic(theme.colorScheme).danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _valider,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_erreur != null ? 'Réessayer' : 'Enregistrer'),
        ),
      ],
    );
  }
}
