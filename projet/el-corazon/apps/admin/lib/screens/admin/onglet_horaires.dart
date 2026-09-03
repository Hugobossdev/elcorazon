import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/services/opening_hours_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/ui/ui.dart';

/// Les horaires d'ouverture — la semaine, telle qu'elle est **en base**.
///
/// Pourquoi cet onglet a été refait
/// --------------------------------
///
/// Il affichait une heure d'ouverture, une heure de fermeture et sept
/// interrupteurs de jours, enregistrés dans les `SharedPreferences` du poste.
/// Aucun code ne les relisait — pas même cet écran au chargement suivant — et
/// rien n'était envoyé au serveur. Le bandeau annonçait « Paramètres
/// sauvegardés avec succès » ; l'établissement continuait de prendre des
/// commandes le dimanche qu'on venait de fermer.
///
/// La route existait pourtant depuis le début : `/restaurants/manage/hours/`,
/// avec sa permission et son cloisonnement.
///
/// Deux différences de modèle, qui viennent du serveur :
///
/// * **une plage, pas une journée.** Midi et soir sont deux lignes du même
///   jour. Le couple ouverture/fermeture ne savait pas les représenter et
///   obligeait à se déclarer ouvert entre les deux services ;
/// * **fermer un jour, c'est n'y laisser aucune plage.** Pas d'interrupteur,
///   donc pas de désaccord possible entre un drapeau « fermé » et des horaires
///   qui disent le contraire.
class OngletHoraires extends StatefulWidget {
  const OngletHoraires({super.key});

  @override
  State<OngletHoraires> createState() => _OngletHorairesState();
}

class _OngletHorairesState extends State<OngletHoraires> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<OpeningHoursService>().initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer2<OpeningHoursService, RestaurantScopeService>(
      builder: (context, horaires, perimetre, child) {
        if (horaires.isLoading && horaires.plages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: horaires.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Horaires d’ouverture',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                perimetre.current == null
                    ? RestaurantScopeService.sansPerimetre
                    : 'Ces horaires sont ceux que le serveur applique pour '
                        '${perimetre.current!.name}. Une modification est '
                        'visible immédiatement dans l’application client.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (horaires.error != null) ...[
                const SizedBox(height: 16),
                _Erreur(message: horaires.error!, onReessayer: horaires.refresh),
              ],
              const SizedBox(height: 24),
              for (var jour = 0; jour < 7; jour++)
                _CarteDuJour(jour: jour, horaires: horaires),
              const SizedBox(height: 24),
              Text(
                'Une plage qui franchit minuit se saisit telle quelle — '
                '22:00 → 02:00 — et vaut pour la nuit qui suit le jour choisi.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.message, required this.onReessayer});

  final String message;
  final Future<void> Function() onReessayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _CarteDuJour extends StatelessWidget {
  const _CarteDuJour({required this.jour, required this.horaires});

  /// Convention du serveur : lundi = 0.
  final int jour;
  final OpeningHoursService horaires;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final plages = horaires.plagesDuJour(jour);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  OpeningHoursService.nomsDesJours[jour],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (plages.isEmpty ? sem.danger : sem.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    plages.isEmpty ? 'Fermé' : 'Ouvert',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: plages.isEmpty ? sem.danger : sem.success,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Plage'),
                  onPressed: () => _ajouter(context),
                ),
              ],
            ),
            if (plages.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aucune plage : l’établissement est fermé ce jour-là.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final plage in plages) _LignePlage(plage: plage, horaires: horaires),
          ],
        ),
      ),
    );
  }

  Future<void> _ajouter(BuildContext context) async {
    final saisie = await _demanderPlage(
      context,
      // Le service du midi est le cas le plus courant ; ce sont des valeurs de
      // départ, pas une règle.
      ouverture: const TimeOfDay(hour: 11, minute: 0),
      fermeture: const TimeOfDay(hour: 22, minute: 0),
    );
    if (saisie == null || !context.mounted) return;

    final ajoutee = await horaires.ajouter(
      jour: jour,
      ouvertureMinutes: saisie.ouvertureMinutes,
      fermetureMinutes: saisie.fermetureMinutes,
    );
    if (!context.mounted) return;
    _annoncer(context, ajoutee, 'Plage ajoutée.', horaires.error);
  }
}

class _LignePlage extends StatelessWidget {
  const _LignePlage({required this.plage, required this.horaires});

  final eccore.OpeningHours plage;
  final OpeningHoursService horaires;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${plage.opensAt} → ${plage.closesAt}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (plage.crossesMidnight) ...[
            const SizedBox(width: 8),
            Text(
              '(le lendemain)',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modifier cette plage',
            onPressed: () => _modifier(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Retirer cette plage',
            onPressed: () => _supprimer(context),
          ),
        ],
      ),
    );
  }

  Future<void> _modifier(BuildContext context) async {
    final saisie = await _demanderPlage(
      context,
      ouverture: _versTimeOfDay(plage.opensAtMinutes),
      fermeture: _versTimeOfDay(plage.closesAtMinutes),
    );
    if (saisie == null || !context.mounted) return;

    final modifiee = await horaires.modifier(
      plageId: plage.id,
      ouvertureMinutes: saisie.ouvertureMinutes,
      fermetureMinutes: saisie.fermetureMinutes,
    );
    if (!context.mounted) return;
    _annoncer(context, modifiee, 'Plage modifiée.', horaires.error);
  }

  Future<void> _supprimer(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette plage ?'),
        content: Text(
          'L’établissement ne prendra plus de commande entre '
          '${plage.opensAt} et ${plage.closesAt} ce jour-là.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;

    final retiree = await horaires.supprimer(plage.id);
    if (!context.mounted) return;
    _annoncer(context, retiree, 'Plage retirée.', horaires.error);
  }
}

/// Ce que l'opérateur a saisi.
class _Plage {
  const _Plage({required this.ouvertureMinutes, required this.fermetureMinutes});

  final int ouvertureMinutes;
  final int fermetureMinutes;
}

/// Demande une ouverture puis une fermeture, avec les sélecteurs du système.
///
/// Rend `null` dès qu'une des deux étapes est abandonnée : une plage à moitié
/// saisie n'a pas de sens, et compléter l'autre bout par une valeur par défaut
/// enregistrerait un horaire que personne n'a choisi.
Future<_Plage?> _demanderPlage(
  BuildContext context, {
  required TimeOfDay ouverture,
  required TimeOfDay fermeture,
}) async {
  final debut = await showTimePicker(
    context: context,
    initialTime: ouverture,
    helpText: 'Heure d’ouverture',
  );
  if (debut == null || !context.mounted) return null;

  final fin = await showTimePicker(
    context: context,
    initialTime: fermeture,
    helpText: 'Heure de fermeture',
  );
  if (fin == null) return null;

  return _Plage(
    ouvertureMinutes: debut.hour * 60 + debut.minute,
    fermetureMinutes: fin.hour * 60 + fin.minute,
  );
}

TimeOfDay _versTimeOfDay(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

/// Le message d'issue.
///
/// En cas de refus, celui du serveur est affiché **tel quel** : il dit ce qui
/// cloche — plage vide, doublon exact, établissement hors périmètre — là où un
/// « une erreur est survenue » enverrait chercher au mauvais endroit.
void _annoncer(BuildContext context, bool succes, String message, String? erreur) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(succes ? message : erreur ?? 'Modification refusée.'),
      backgroundColor:
          succes ? scheme.inverseSurface : AdminColorTokens.semantic(scheme).danger,
    ),
  );
}
