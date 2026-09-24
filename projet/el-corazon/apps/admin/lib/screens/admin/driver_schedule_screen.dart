import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/services/driver_schedule_service.dart';

/// Le planning d'un livreur — **indicatif**, jamais opposable.
///
/// L'éligibilité reste, côté serveur, « en ligne, dossier validé, compte
/// actif » (L1). Un créneau ne s'y ajoute pas : refuser une course à 18 h 05 à
/// quelqu'un de présent laisserait la commande sans porteur. Ce planning dit
/// qui l'exploitation **attend**, et lui permet de constater les écarts.
///
/// ## Ce que l'écran montrait mal (23 septembre 2026)
///
/// * **Un seul créneau par jour.** Sept lignes, une par jour, chacune prenant
///   le premier créneau trouvé : un livreur en service du midi *et* du soir
///   n'en montrait qu'un, et modifier l'heure affichée écrasait ce créneau-là
///   en laissant l'autre intact et invisible.
/// * **Les refus étaient muets.** Chaque geste appelait `saveSchedule` sans en
///   lire le résultat : un créneau refusé — parce qu'il en recouvre un autre,
///   ou faute du droit `couriers.write` — revenait à sa valeur d'avant sans
///   un mot, et l'exploitation recommençait.
/// * **« Horaires mis à jour avec succès » s'affichait avant le serveur.**
///   L'uniformisation lançait sept écritures sans les attendre, puis annonçait
///   le succès ; les sept pouvaient échouer.
/// * **Rien ne se supprimait.** La route existe (`DELETE /delivery/shifts/`),
///   le service l'appelait, aucun bouton ne s'en servait.
class DriverScheduleScreen extends StatefulWidget {
  const DriverScheduleScreen({required this.driver, super.key});

  final eccore.CourierProfile driver;

  @override
  State<DriverScheduleScreen> createState() => _DriverScheduleScreenState();
}

class _DriverScheduleScreenState extends State<DriverScheduleScreen> {
  /// Le geste en cours, pour n'en laisser partir qu'un à la fois : deux
  /// écritures concurrentes sur le même planning se contredisent, et le
  /// serveur refuserait la seconde sur un état que l'écran n'a pas encore lu.
  bool _enEcriture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_charger());
    });
  }

  Future<void> _charger() =>
      context.read<DriverScheduleService>().loadDriverSchedules(widget.driver.id);

  /// Exécute une écriture et **dit** ce qu'il en advient.
  ///
  /// Le succès n'est annoncé qu'après la réponse du serveur ; un refus reste à
  /// l'écran avec la phrase du serveur — « Ce livreur est déjà planifié de
  /// 09:00 à 17:00 ce jour-là », qui indique quoi corriger.
  Future<void> _ecrire(Future<void> Function() geste, {required String succes}) async {
    if (_enEcriture) return;
    setState(() => _enEcriture = true);
    try {
      await geste();
      if (mounted) annoncer(context, succes);
    } on eccore.ApiException catch (e) {
      if (mounted) annoncerEchec(context, Echec.de(e));
    } finally {
      if (mounted) setState(() => _enEcriture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planning = context.watch<DriverScheduleService>();
    final peutEcrire = context.peut('couriers.write');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning du livreur'),
        actions: [
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: planning.isLoading ? null : () => unawaited(_charger()),
          ),
        ],
      ),
      body: Column(
        children: [
          _EnTeteLivreur(driver: widget.driver),
          if (planning.echec != null)
            BandeauEchec(echec: planning.echec!, onReessayer: () => unawaited(_charger())),
          if (!peutEcrire)
            const _Note(
              icone: Icons.lock_outline_rounded,
              texte: 'Lecture seule : modifier un planning demande le droit '
                  '« Gérer les livreurs » (couriers.write).',
            ),
          const _Note(
            icone: Icons.info_outline,
            // Sans cette phrase, un planning vide passe pour une interdiction
            // de travailler — et un créneau pour une garantie de présence.
            texte: 'Le planning est indicatif : il ne conditionne pas les '
                'courses. Un livreur en ligne et validé reçoit des propositions, '
                'créneau ou pas.',
          ),
          if (planning.isLoading && planning.getDriverSchedules(widget.driver.id).isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final jour = index + 1;
                  return _CarteDuJour(
                    jour: jour,
                    libelle: planning.getDayName(jour),
                    creneaux: planning.creneauxDuJour(widget.driver.id, jour),
                    modifiable: peutEcrire && !_enEcriture,
                    theme: theme,
                    onAjouter: () => unawaited(_ajouter(jour)),
                    onModifier: (creneau) => unawaited(_modifierLesHeures(creneau)),
                    onBasculer: (creneau, present) => unawaited(
                      _ecrire(
                        () => context
                            .read<DriverScheduleService>()
                            .saveSchedule(creneau.copyWith(isAvailable: present)),
                        succes: present
                            ? 'Créneau rétabli'
                            : 'Absence marquée sur ce créneau',
                      ),
                    ),
                    onSupprimer: (creneau) => unawaited(_supprimer(creneau)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ajouter(int jour) async {
    final heures = await _demanderLesHeures(
      titre: 'Ajouter un créneau',
      debut: const TimeOfDay(hour: 9, minute: 0),
      fin: const TimeOfDay(hour: 17, minute: 0),
    );
    if (heures == null || !mounted) return;

    await _ecrire(
      () => context.read<DriverScheduleService>().saveSchedule(
            DriverSchedule(
              driverId: widget.driver.id,
              dayOfWeek: jour,
              startTime: heures.$1,
              endTime: heures.$2,
            ),
          ),
      succes: 'Créneau ajouté',
    );
  }

  Future<void> _modifierLesHeures(DriverSchedule creneau) async {
    final heures = await _demanderLesHeures(
      titre: 'Modifier le créneau',
      debut: creneau.startTime,
      fin: creneau.endTime,
    );
    if (heures == null || !mounted) return;

    await _ecrire(
      () => context.read<DriverScheduleService>().saveSchedule(
            creneau.copyWith(startTime: heures.$1, endTime: heures.$2),
          ),
      succes: 'Créneau modifié',
    );
  }

  Future<void> _supprimer(DriverSchedule creneau) async {
    // Une absence ponctuelle se **marque** ; supprimer efface la ligne du
    // planning, et ce n'est pas la même chose. Le dialogue le rappelle.
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce créneau ?'),
        content: Text(
          'Le créneau ${creneau.startTime.format(context)} – '
          '${creneau.endTime.format(context)} disparaîtra du planning.\n\n'
          'Pour une absence ponctuelle, décochez plutôt « Présent » : '
          'le créneau reste lisible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    await _ecrire(
      () => context
          .read<DriverScheduleService>()
          .deleteSchedule(creneau.id!, widget.driver.id),
      succes: 'Créneau retiré',
    );
  }

  /// Demande un début et une fin. Rend `null` si l'un des deux est abandonné —
  /// enregistrer une moitié de créneau n'aurait pas de sens.
  Future<(TimeOfDay, TimeOfDay)?> _demanderLesHeures({
    required String titre,
    required TimeOfDay debut,
    required TimeOfDay fin,
  }) async {
    final nouveauDebut = await showTimePicker(
      context: context,
      initialTime: debut,
      helpText: '$titre — début de service',
    );
    if (nouveauDebut == null || !mounted) return null;

    final nouvelleFin = await showTimePicker(
      context: context,
      initialTime: fin,
      helpText: '$titre — fin de service',
    );
    if (nouvelleFin == null) return null;
    return (nouveauDebut, nouvelleFin);
  }
}

class _EnTeteLivreur extends StatelessWidget {
  const _EnTeteLivreur({required this.driver});

  final eccore.CourierProfile driver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: scheme.primaryContainer,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.primary,
            child: Text(
              driver.fullName.isEmpty ? '?' : driver.fullName.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  driver.email,
                  style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // « En service » / « Hors service » disait l'état du **dossier**
                // — un livreur validé mais déconnecté s'y lisait « en service ».
                // Le statut, lui, est celui que le reste du back-office montre.
                Row(
                  children: [
                    Icon(driver.statut.icone, size: 14, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(
                      '${driver.statut.libelle} • '
                      '${driver.estValide ? 'dossier validé' : 'dossier non validé'}',
                      style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un jour de la semaine et **tous** ses créneaux.
class _CarteDuJour extends StatelessWidget {
  const _CarteDuJour({
    required this.jour,
    required this.libelle,
    required this.creneaux,
    required this.modifiable,
    required this.theme,
    required this.onAjouter,
    required this.onModifier,
    required this.onBasculer,
    required this.onSupprimer,
  });

  final int jour;
  final String libelle;
  final List<DriverSchedule> creneaux;
  final bool modifiable;
  final ThemeData theme;
  final VoidCallback onAjouter;
  final void Function(DriverSchedule creneau) onModifier;
  final void Function(DriverSchedule creneau, bool present) onBasculer;
  final void Function(DriverSchedule creneau) onSupprimer;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    libelle,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: modifiable ? onAjouter : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (creneaux.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aucun créneau planifié.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              )
            else
              for (final creneau in creneaux)
                _LigneCreneau(
                  creneau: creneau,
                  modifiable: modifiable,
                  onModifier: () => onModifier(creneau),
                  onBasculer: (present) => onBasculer(creneau, present),
                  onSupprimer: () => onSupprimer(creneau),
                ),
          ],
        ),
      ),
    );
  }
}

class _LigneCreneau extends StatelessWidget {
  const _LigneCreneau({
    required this.creneau,
    required this.modifiable,
    required this.onModifier,
    required this.onBasculer,
    required this.onSupprimer,
  });

  final DriverSchedule creneau;
  final bool modifiable;
  final VoidCallback onModifier;
  final ValueChanged<bool> onBasculer;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final present = creneau.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: modifiable ? onModifier : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      present ? Icons.schedule : Icons.event_busy,
                      size: 18,
                      color: present ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${creneau.startTime.format(context)} – '
                      '${creneau.endTime.format(context)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: present ? null : scheme.outline,
                        decoration: present ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    if (!present) ...[
                      const SizedBox(width: 10),
                      Text(
                        'absent',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: present ? 'Marquer une absence' : 'Rétablir le créneau',
            child: Switch.adaptive(
              value: present,
              onChanged: modifiable ? onBasculer : null,
            ),
          ),
          IconButton(
            tooltip: 'Retirer ce créneau',
            icon: const Icon(Icons.delete_outline),
            onPressed: modifiable ? onSupprimer : null,
          ),
        ],
      ),
    );
  }
}
