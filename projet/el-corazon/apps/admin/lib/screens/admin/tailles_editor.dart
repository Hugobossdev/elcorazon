import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/utils/price_formatter.dart';

/// Les tailles d'un plat — Petite, Moyenne, Grande (lot 2).
///
/// ## Une taille n'est pas une option
///
/// Son prix **remplace** celui du plat (décision du 2026-09-25) : une Grande
/// à 3 500 se facture 3 500, pas 2 000 + 3 500. Les options s'ajoutent ensuite
/// par-dessus. Dès qu'un plat a une taille active, le client doit en choisir
/// une — le serveur refuse sinon la ligne.
///
/// ## Écrit tout de suite, pas à l'enregistrement du plat
///
/// Chaque geste part au serveur (`/catalog/manage/variants/`) et n'est
/// affiché qu'une fois confirmé : c'est lui qui refuse un doublon de nom ou
/// une devise étrangère, et qui journalise (`variant.*`). Retenir les tailles
/// jusqu'au bouton « Enregistrer » du plat laisserait croire à une saisie
/// acquise que le serveur n'a jamais vue.
class TaillesEditor extends StatefulWidget {
  const TaillesEditor({
    required this.menuItemId,
    required this.devise,
    required this.depot,
    super.key,
  });

  /// Vide pour un plat pas encore créé : une taille se rattache à un plat qui
  /// existe au serveur.
  final String menuItemId;

  /// Devise du plat — celle que le serveur exige pour chaque taille.
  final String devise;
  final eccore.ManagedCatalogRepository depot;

  @override
  State<TaillesEditor> createState() => _TaillesEditorState();
}

class _TaillesEditorState extends State<TaillesEditor> {
  List<eccore.TailleGeree> _tailles = const [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (widget.menuItemId.isEmpty) {
      _chargement = false;
    } else {
      unawaited(_charger());
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final tailles = [...await widget.depot.tailles(widget.menuItemId)]
        ..sort(
          (a, b) => a.sortOrder != b.sortOrder
              ? a.sortOrder.compareTo(b.sortOrder)
              : a.name.compareTo(b.name),
        );
      if (mounted) setState(() => _tailles = tailles);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _editer([eccore.TailleGeree? taille]) async {
    final nom = TextEditingController(text: taille?.name ?? '');
    final prix = TextEditingController(
      text: taille == null ? '' : montantPourSaisie(taille.price.toMajorUnits(), widget.devise),
    );
    final sku = TextEditingController(text: taille?.sku ?? '');

    final confirme = await DialogueDeFormulaire.ouvrir(
      context,
      titre: taille == null ? 'Nouvelle taille' : 'Modifier « ${taille.name} »',
      corps: (context, echec) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nom,
            decoration: InputDecoration(
              labelText: 'Nom',
              hintText: 'Petite, Moyenne, Grande…',
              errorText: echec?.pourLeChamp('name'),
            ),
            validator: Valider.requis,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: prix,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Prix (${widget.devise})',
              helperText: 'Remplace le prix du plat ; les options s’y ajoutent.',
              errorText: echec?.pourLeChamp('price'),
            ),
            validator: (valeur) => Valider.montantEn(widget.devise, valeur),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: sku,
            decoration: InputDecoration(
              labelText: 'Référence (facultatif)',
              errorText: echec?.pourLeChamp('sku'),
            ),
          ),
        ],
      ),
      enregistrer: () async {
        final montant = eccore.Money.fromMajorUnits(lireMontant(prix.text)!, widget.devise);
        if (taille == null) {
          await widget.depot.creerTaille(
            menuItemId: widget.menuItemId,
            nom: nom.text.trim(),
            prix: montant,
            sku: sku.text.trim(),
            ordre: _tailles.length,
          );
        } else {
          await widget.depot.modifierTaille(
            taille.id,
            nom: nom.text.trim(),
            prix: montant,
            sku: sku.text.trim(),
          );
        }
      },
    );
    nom.dispose();
    prix.dispose();
    sku.dispose();
    if (confirme) await _charger();
  }

  /// Un interrupteur écrit au serveur, puis la liste relue : ce qu'on voit
  /// est ce que le serveur a retenu.
  Future<void> _basculer(
    eccore.TailleGeree taille, {
    bool? disponible,
    bool? active,
  }) async {
    try {
      await widget.depot.modifierTaille(taille.id, disponible: disponible, active: active);
      await _charger();
    } catch (e) {
      _signaler(messageErreur(e));
    }
  }

  Future<void> _supprimer(eccore.TailleGeree taille) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${taille.name} » ?'),
        content: const Text(
          'Les commandes passées la gardent. Un panier qui la contient ne '
          'pourra plus être commandé. Pour la retirer seulement de la carte, '
          'désactivez-la plutôt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (oui != true) return;
    try {
      await widget.depot.supprimerTaille(taille.id);
      await _charger();
    } catch (e) {
      _signaler(messageErreur(e));
    }
  }

  void _signaler(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Tailles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (widget.menuItemId.isNotEmpty)
              TextButton.icon(
                onPressed: _chargement ? null : () => unawaited(_editer()),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter une taille'),
              ),
          ],
        ),
        Text(
          'Le prix d’une taille remplace celui du plat. Dès qu’une taille est '
          'active, le client doit en choisir une.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (widget.menuItemId.isEmpty)
          const Text('Enregistrez d’abord le plat pour lui ajouter des tailles.')
        else if (_chargement)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_erreur != null)
          Row(
            children: [
              Expanded(child: Text(_erreur!, style: TextStyle(color: theme.colorScheme.error))),
              TextButton(onPressed: () => unawaited(_charger()), child: const Text('Réessayer')),
            ],
          )
        else if (_tailles.isEmpty)
          const Text('Aucune taille : le plat se vend à son prix.')
        else
          for (final taille in _tailles)
            Card(
              child: ListTile(
                title: Text(
                  taille.name,
                  style: taille.isActive
                      ? null
                      : const TextStyle(decoration: TextDecoration.lineThrough),
                ),
                subtitle: Text(
                  [
                    taille.price.format(),
                    if (!taille.isActive) 'retirée de la carte',
                    if (taille.isActive && !taille.isAvailable) 'épuisée',
                    if (taille.sku.isNotEmpty) taille.sku,
                  ].join(' · '),
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tooltip(
                      message: taille.isAvailable ? 'Marquer épuisée' : 'Remettre en vente',
                      child: Switch(
                        value: taille.isAvailable,
                        onChanged: taille.isActive
                            ? (v) => unawaited(_basculer(taille, disponible: v))
                            : null,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (choix) => unawaited(
                        switch (choix) {
                          'modifier' => _editer(taille),
                          'activation' => _basculer(taille, active: !taille.isActive),
                          _ => _supprimer(taille),
                        },
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                        PopupMenuItem(
                          value: 'activation',
                          child: Text(taille.isActive ? 'Retirer de la carte' : 'Remettre à la carte'),
                        ),
                        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
