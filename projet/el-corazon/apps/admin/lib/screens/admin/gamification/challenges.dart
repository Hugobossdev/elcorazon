import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/screens/admin/gamification/communs.dart';
import 'package:admin/services/gamification_service.dart';

/// Défis — l'onglet et son formulaire.
///
/// Trois défauts, vérifiés en réel le 21 septembre 2026 :
///
/// * la « nature » du défi proposait `orders_count`, `total_spent`,
///   `streak_days` — des **critères**, là où le serveur attend une nature
///   (`daily`, `weekly`, `monthly`, `special`). Toute création revenait en 400 ;
///   la base ne contenait d'ailleurs aucun défi ;
/// * la modification lisait `start_date`/`end_date` au lieu de
///   `starts_at`/`ends_at` : les dates repartaient à « maintenant → +7 jours »,
///   et **enregistrer écrasait la fenêtre du défi** ;
/// * un champ « remise » était saisi et jeté.
///
/// La nature et le critère sont désormais deux champs distincts, chacun tiré
/// de son vocabulaire serveur ([eccore.ChallengeKind],
/// [eccore.AchievementCondition]).
/// Où en est un défi, à [maintenant] : « À venir », « En cours » ou
/// « Terminé ».
///
/// L'ancienne règle lisait `end_date` — clé qu'aucune réponse ne portait — si
/// bien qu'aucun défi ne s'affichait jamais terminé ; son test passait, parce
/// qu'il fabriquait lui-même la clé fautive. Le modèle typé ne le permet plus :
/// `ends_at` est obligatoire côté serveur.
String etatDuDefi(eccore.ManagedChallenge defi, {DateTime? maintenant}) {
  final instant = maintenant ?? DateTime.now();
  if (instant.isBefore(defi.startsAt)) return 'À venir';
  if (!instant.isBefore(defi.endsAt)) return 'Terminé';
  return 'En cours';
}

class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final peutEcrire = service.peutEcrire(CatalogueDeFidelisation.defis);

    return OngletDeCatalogue<eccore.ManagedChallenge>(
      elements: service.defis,
      echec: service.echecDe(CatalogueDeFidelisation.defis),
      libelleCreation: 'Nouveau défi',
      peutEcrire: peutEcrire,
      vide: 'Aucun défi',
      onCreer: () => ouvrirFormulaireDefi(context),
      carte: (defi) => CarteDeCatalogue(
        icone: '🎯',
        titre: defi.title,
        description: defi.description,
        pastilles: [
          eccore.ChallengeKind.libelle(defi.challengeType),
          '${eccore.AchievementCondition.libelle(defi.conditionType)} ≥ ${defi.targetValue}',
          '+${defi.rewardPoints} pts',
          'Du ${dateCourte(defi.startsAt)} au ${dateCourte(defi.endsAt)}',
          etatDuDefi(defi),
        ],
        actif: defi.isActive,
        peutEcrire: peutEcrire,
        onModifier: () => ouvrirFormulaireDefi(context, defi: defi),
        onBasculer: () => context.read<GamificationService>().basculerDefi(defi),
      ),
    );
  }
}

Future<void> ouvrirFormulaireDefi(BuildContext context, {eccore.ManagedChallenge? defi}) async {
  final service = context.read<GamificationService>();
  final titre = TextEditingController(text: defi?.title);
  final description = TextEditingController(text: defi?.description);
  final cible = TextEditingController(text: defi == null ? '' : '${defi.targetValue}');
  final points = TextEditingController(text: '${defi?.rewardPoints ?? 0}');
  var nature = defi?.challengeType ?? eccore.ChallengeKind.weekly;
  var critere = defi?.conditionType ?? eccore.AchievementCondition.ordersCount;
  // Les dates du défi **existant** : c'est ce que la modification perdait.
  final maintenant = DateTime.now();
  var debut = defi?.startsAt.toLocal() ??
      DateTime(maintenant.year, maintenant.month, maintenant.day + 1);
  var fin = defi?.endsAt.toLocal() ?? debut.add(eccore.ChallengeKind.dureeProposee(nature));
  var actif = defi?.isActive ?? true;

  Future<DateTime?> choisir(BuildContext context, DateTime initial) async {
    final jour = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(maintenant.year + 3),
    );
    if (jour == null || !context.mounted) return null;
    final heure = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (heure == null) return null;
    return DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  }

  final enregistre = await DialogueDeFormulaire.ouvrir(
    context,
    titre: defi == null ? 'Nouveau défi' : 'Modifier le défi',
    libelleAction: defi == null ? 'Créer' : 'Enregistrer',
    enregistrer: () => service.enregistrerDefi(
      id: defi?.id,
      title: titre.text.trim(),
      description: description.text.trim(),
      challengeType: nature,
      conditionType: critere,
      targetValue: int.parse(cible.text.trim()),
      rewardPoints: int.parse(points.text.trim()),
      startsAt: debut,
      endsAt: fin,
      isActive: actif,
    ),
    corps: (context, echec) => StatefulBuilder(
      builder: (context, majEtat) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: titre,
            decoration: InputDecoration(labelText: 'Titre *', errorText: echec?.pourLeChamp('title')),
            validator: Valider.requis,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: nature,
            decoration: InputDecoration(
              labelText: 'Nature du défi *',
              helperText: 'La cadence annoncée au client. La fenêtre réelle est celle des dates.',
              helperMaxLines: 2,
              errorText: echec?.pourLeChamp('challenge_type'),
            ),
            items: [
              for (final valeur in eccore.ChallengeKind.values)
                DropdownMenuItem(value: valeur, child: Text(eccore.ChallengeKind.libelle(valeur))),
            ],
            onChanged: (valeur) => majEtat(() {
              nature = valeur ?? nature;
              // Proposition seulement, et seulement à la création : modifier la
              // nature d'un défi existant ne doit pas déplacer sa fenêtre.
              if (defi == null) fin = debut.add(eccore.ChallengeKind.dureeProposee(nature));
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: critere,
            decoration: InputDecoration(
              labelText: 'Ce qui est compté *',
              errorText: echec?.pourLeChamp('condition_type'),
            ),
            items: [
              for (final valeur in eccore.AchievementCondition.values)
                DropdownMenuItem(
                  value: valeur,
                  child: Text(eccore.AchievementCondition.libelle(valeur)),
                ),
            ],
            onChanged: (valeur) => majEtat(() => critere = valeur ?? critere),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cible,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cible *',
              helperText: eccore.AchievementCondition.uniteDuSeuil(critere),
              errorText: echec?.pourLeChamp('target_value'),
            ),
            validator: (v) => Valider.entier(v, minimum: 1, message: 'Une cible d’au moins 1'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: points,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Points offerts',
              errorText: echec?.pourLeChamp('reward_points'),
            ),
            validator: (v) => Valider.entier(v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Début : ${dateCourte(debut)}'),
                  onPressed: () async {
                    final choisie = await choisir(context, debut);
                    if (choisie != null) majEtat(() => debut = choisie);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text('Fin : ${dateCourte(fin)}'),
                  onPressed: () async {
                    final choisie = await choisir(context, fin);
                    if (choisie != null) majEtat(() => fin = choisie);
                  },
                ),
              ),
            ],
          ),
          // Même règle que le serveur (`ends_at` > `starts_at`), dite avant
          // l'envoi. Un `FormField` pour que la validation du formulaire la
          // bloque.
          FormField<void>(
            validator: (_) => fin.isAfter(debut) ? null : 'La fin doit suivre le début.',
            builder: (etat) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                etat.errorText ?? echec?.pourLeChamp('ends_at') ?? '',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: actif,
            onChanged: (valeur) => majEtat(() => actif = valeur),
          ),
        ],
      ),
    ),
  );

  if (enregistre && context.mounted) {
    annoncer(context, defi == null ? 'Défi créé.' : 'Défi enregistré.');
  }
}
