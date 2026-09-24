import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';

export 'package:admin/presentation/retours.dart';

/// Ce que les quatre onglets de fidélisation partagent : la liste, sa carte,
/// et la façon d'annoncer un résultat.
///
/// Les onglets étaient quatre copies d'un même gabarit, chacune avec son
/// défaut propre (clés mal lues, dates écrasées, champs fantômes). Le gabarit
/// commun porte désormais les règles que toutes doivent tenir : l'échec de
/// lecture s'affiche, les gestes d'écriture n'apparaissent qu'avec la
/// permission, et une bascule refusée le dit.
class OngletDeCatalogue<T> extends StatelessWidget {
  const OngletDeCatalogue({
    required this.elements,
    required this.echec,
    required this.libelleCreation,
    required this.peutEcrire,
    required this.vide,
    required this.onCreer,
    required this.carte,
    this.entete,
    super.key,
  });

  final List<T> elements;
  final Echec? echec;
  final String libelleCreation;
  final bool peutEcrire;
  final String vide;
  final VoidCallback onCreer;
  final Widget Function(T element) carte;

  /// Une explication propre à l'onglet, sous le bouton de création.
  final Widget? entete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (echec != null) BandeauEchec(echec: echec!),
        if (peutEcrire)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onCreer,
                icon: const Icon(Icons.add),
                label: Text(libelleCreation),
              ),
            ),
          ),
        if (entete != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: entete),
        Expanded(
          child: elements.isEmpty
              ? Center(
                  child: Text(
                    // Un catalogue illisible n'est pas un catalogue vide.
                    echec == null ? vide : 'Catalogue non chargé',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: elements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => carte(elements[index]),
                ),
        ),
      ],
    );
  }
}

class CarteDeCatalogue extends StatelessWidget {
  const CarteDeCatalogue({
    required this.icone,
    required this.titre,
    required this.description,
    required this.pastilles,
    required this.actif,
    required this.peutEcrire,
    required this.onModifier,
    required this.onBasculer,
    super.key,
  });

  final String icone;
  final String titre;
  final String description;
  final List<String> pastilles;
  final bool actif;
  final bool peutEcrire;
  final VoidCallback onModifier;
  final Future<void> Function() onBasculer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(icone.isEmpty ? '•' : icone, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) Text(description),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final pastille in pastilles) Chip(label: Text(pastille)),
                Chip(
                  label: Text(actif ? 'Actif' : 'Inactif'),
                  backgroundColor: actif ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
                ),
              ],
            ),
          ],
        ),
        trailing: peutEcrire
            ? PopupMenuButton<String>(
                onSelected: (choix) {
                  if (choix == 'modifier') onModifier();
                  if (choix == 'basculer') unawaited(basculerAvecRetour(context, onBasculer));
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                  PopupMenuItem(value: 'basculer', child: Text(actif ? 'Désactiver' : 'Activer')),
                ],
              )
            : null,
      ),
    );
  }
}
