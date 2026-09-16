import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/ui/ui.dart';

/// Les pertes et corrections qui attendent une seconde personne.
///
/// ## Le quatre-yeux, dit avant d'être refusé
///
/// Le serveur refuse qu'une personne tranche la demande qu'elle a déclarée, et
/// il le refuse quoi qu'il arrive — permission ou non, et jusque dans la base.
/// L'écran ne l'applique pas : il **l'annonce**, en retirant le bouton et en
/// disant pourquoi, pour que personne ne découvre la règle par un refus.
///
/// Un refus exige un motif : la personne qui a déclaré doit savoir quoi
/// recompter.
class ValidationsScreen extends StatefulWidget {
  const ValidationsScreen({required this.restaurant, super.key});

  final eccore.ManagedRestaurant restaurant;

  @override
  State<ValidationsScreen> createState() => _ValidationsScreenState();
}

class _ValidationsScreenState extends State<ValidationsScreen> {
  eccore.ManagedInventoryRepository get _depot =>
      eccore.ManagedInventoryRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.AdjustmentRequest> _demandes = const [];
  bool _chargement = true;
  bool _enAttenteSeulement = true;
  String? _erreur;
  final Set<String> _enCours = {};

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  @override
  void didUpdateWidget(ValidationsScreen ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.restaurant.slug != widget.restaurant.slug) unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final demandes = await _depot.adjustmentRequests(
        restaurantSlug: widget.restaurant.slug,
        status: _enAttenteSeulement ? 'pending' : null,
      );
      if (mounted) setState(() => _demandes = demandes);
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _trancher(eccore.AdjustmentRequest demande, {required bool valider}) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _Note(valider: valider, demande: demande),
    );
    if (note == null || !mounted) return;

    setState(() => _enCours.add(demande.id));
    final messager = ScaffoldMessenger.of(context);
    // Lue avant l'attente : le contexte ne se consulte plus une fois l'appel
    // revenu, l'écran ayant pu être quitté entre-temps.
    final danger = AdminColorTokens.semantic(Theme.of(context).colorScheme).danger;
    try {
      if (valider) {
        await _depot.approve(demande.id, note: note);
      } else {
        await _depot.reject(demande.id, note: note);
      }
      messager.showSnackBar(
        SnackBar(
          content: Text(
            valider
                ? '${libelleMouvement(demande.kind)} validée : ${demande.quantity.label} de '
                    '${demande.ingredientName}, écrite au journal.'
                : 'Demande refusée. Rien n’a bougé au stock.',
          ),
        ),
      );
      await _charger();
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(messageErreur(erreur)),
          backgroundColor: danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _enCours.remove(demande.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AdminAuthService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Validations — ${widget.restaurant.name}', style: theme.textTheme.titleLarge),
              FilterChip(
                label: const Text('En attente seulement'),
                selected: _enAttenteSeulement,
                onSelected: (valeur) {
                  setState(() => _enAttenteSeulement = valeur);
                  unawaited(_charger());
                },
              ),
              IconButton(
                tooltip: 'Relire',
                onPressed: _chargement ? null : _charger,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _corps(theme, auth)),
        ],
      ),
    );
  }

  Widget _corps(ThemeData theme, AdminAuthService auth) {
    if (_chargement && _demandes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erreur!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_demandes.isEmpty) {
      return Center(
        child: Text(
          _enAttenteSeulement
              ? 'Aucune perte ni correction n’attend de validation.'
              : 'Aucune demande de correction pour cette cuisine.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _demandes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, rang) {
        final demande = _demandes[rang];
        final droit = peutTrancher(
          demande: demande,
          compteId: auth.currentAdmin?.id,
          aLaPermission: auth.can('inventory.approve'),
        );
        final occupe = _enCours.contains(demande.id);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${libelleMouvement(demande.kind)} — ${demande.ingredientName} '
                  '(${demande.quantity.label})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (demande.estimatedValue != null)
                      'Valeur estimée ${demande.estimatedValue!.format()}'
                    else
                      'Valeur inconnue',
                    'déclarée par ${demande.requestedByName.isEmpty ? '—' : demande.requestedByName}',
                    libelleStatutDemande(demande.status),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text('« ${demande.reason} »', style: theme.textTheme.bodyMedium),
                if (demande.decisionNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Décision de ${demande.decidedByName} : ${demande.decisionNote}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (droit.autorise)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: occupe ? null : () => _trancher(demande, valider: true),
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                      ),
                      OutlinedButton.icon(
                        onPressed: occupe ? null : () => _trancher(demande, valider: false),
                        icon: const Icon(Icons.close),
                        label: const Text('Refuser'),
                      ),
                    ],
                  )
                else if (demande.isPending && droit.raison != null)
                  Text(droit.raison!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// La note d'une décision — facultative pour valider, obligatoire pour refuser.
class _Note extends StatefulWidget {
  const _Note({required this.valider, required this.demande});

  final bool valider;
  final eccore.AdjustmentRequest demande;

  @override
  State<_Note> createState() => _NoteState();
}

class _NoteState extends State<_Note> {
  final _note = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirmer() {
    final texte = _note.text.trim();
    if (!widget.valider && texte.isEmpty) {
      setState(() => _erreur = 'Dites pourquoi : la personne qui a déclaré doit savoir quoi recompter.');
      return;
    }
    Navigator.of(context).pop(texte);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.valider ? 'Valider la correction' : 'Refuser la correction'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.valider
                  ? '${widget.demande.quantity.label} de ${widget.demande.ingredientName} : '
                      '${widget.demande.quantity.isNegative ? 'sortie' : 'entrée'} du stock, au journal.'
                  : 'Rien ne bougera au stock.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              autofocus: true,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: widget.valider ? 'Note — facultative' : 'Motif du refus',
                errorText: _erreur,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _confirmer,
          child: Text(widget.valider ? 'Valider' : 'Refuser'),
        ),
      ],
    );
  }
}
