import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/versements/communs.dart';
import 'package:admin/services/journal_audit_service.dart';

/// Le journal des décisions : barèmes, zones, emplacements, et les droits —
/// permissions d'un rôle, rôles et périmètre d'un compte, blocage d'un client.
///
/// Il était écrit sans être lisible. Le cahier des charges demande l'« audit
/// des actions » sous la gestion des rôles, et l'état des fonctionnalités le
/// disait fait : il n'existait ni route, ni écran.
class JournalAuditScreen extends StatefulWidget {
  const JournalAuditScreen({super.key});

  @override
  State<JournalAuditScreen> createState() => _JournalAuditScreenState();
}

class _JournalAuditScreenState extends State<JournalAuditScreen> {
  final _recherche = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<JournalAuditService>().charger());
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalAuditService>();
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _recherche,
              decoration: const InputDecoration(
                hintText: 'Chercher une cible ou un auteur…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (texte) => unawaited(journal.charger(recherche: texte)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Tout'),
                  selected: journal.famille == null,
                  onSelected: (_) => unawaited(journal.charger(effacerFamille: true)),
                ),
                for (final entree in eccore.FamilleAudit.familles.entries)
                  ChoiceChip(
                    label: Text(entree.value),
                    selected: journal.famille == entree.key,
                    onSelected: (_) => unawaited(journal.charger(famille: entree.key)),
                  ),
                Text('${journal.total} entrée(s)', style: TextStyle(color: theme.hintColor)),
              ],
            ),
          ),
          Expanded(
            child: EtatDeListe(
              chargement: journal.chargement,
              erreur: journal.erreur,
              vide: journal.entrees.isEmpty,
              messageVide: 'Aucune décision consignée pour ce filtre.',
              onReessayer: () => unawaited(journal.charger()),
              liste: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: journal.entrees.length + (journal.aUneSuite ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == journal.entrees.length) {
                    return Center(
                      child: TextButton(
                        onPressed: journal.chargement
                            ? null
                            : () => unawaited(journal.chargerLaSuite()),
                        child: const Text('Remonter plus loin'),
                      ),
                    );
                  }
                  return _Entree(entree: journal.entrees[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entree extends StatelessWidget {
  const _Entree({required this.entree});

  final eccore.AuditRecord entree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modifiees = entree.clesModifiees;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  eccore.FamilleAudit.libelle(entree.action),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('· ${entree.targetLabel}'),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${entree.actorName ?? 'Sans auteur (opération technique)'} · '
              '${dateCourte(entree.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            for (final cle in modifiees)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$cle : ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(
                        text: valeurLisible(entree.before[cle]),
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const TextSpan(text: '  →  '),
                      TextSpan(text: valeurLisible(entree.after[cle])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
