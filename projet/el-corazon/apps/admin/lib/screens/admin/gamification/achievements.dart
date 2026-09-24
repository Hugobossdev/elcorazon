import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/screens/admin/gamification/communs.dart';
import 'package:admin/services/gamification_service.dart';

/// Succès — l'onglet et son formulaire.
///
/// Le formulaire proposait quatre critères (« Total dépensé », « Série de
/// jours », « Commandes par catégorie »…) dont le serveur n'en accepte que
/// deux : trois sur quatre revenaient en 400, dans un dialogue déjà fermé. Il
/// portait aussi un champ « badge à débloquer » qui n'allait nulle part. Les
/// critères viennent désormais de [eccore.AchievementCondition], comparé aux
/// `TextChoices` du serveur en CI.
class AchievementsTab extends StatelessWidget {
  const AchievementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final peutEcrire = service.peutEcrire(CatalogueDeFidelisation.succes);

    return OngletDeCatalogue<eccore.ManagedAchievement>(
      elements: service.succes,
      echec: service.echecDe(CatalogueDeFidelisation.succes),
      libelleCreation: 'Nouveau succès',
      peutEcrire: peutEcrire,
      vide: 'Aucun succès',
      onCreer: () => ouvrirFormulaireSucces(context),
      carte: (succes) => CarteDeCatalogue(
        icone: succes.icon,
        titre: succes.name,
        description: succes.description,
        pastilles: [
          '${eccore.AchievementCondition.libelle(succes.conditionType)} ≥ ${succes.conditionValue}',
          '+${succes.pointsReward} pts',
        ],
        actif: succes.isActive,
        peutEcrire: peutEcrire,
        onModifier: () => ouvrirFormulaireSucces(context, succes: succes),
        onBasculer: () => context.read<GamificationService>().basculerSucces(succes),
      ),
    );
  }
}

Future<void> ouvrirFormulaireSucces(
  BuildContext context, {
  eccore.ManagedAchievement? succes,
}) async {
  final service = context.read<GamificationService>();
  final nom = TextEditingController(text: succes?.name);
  final description = TextEditingController(text: succes?.description);
  final icone = TextEditingController(text: succes?.icon ?? '🏆');
  final seuil = TextEditingController(text: succes == null ? '' : '${succes.conditionValue}');
  final points = TextEditingController(text: '${succes?.pointsReward ?? 0}');
  var critere = succes?.conditionType ?? eccore.AchievementCondition.ordersCount;
  var actif = succes?.isActive ?? true;

  final enregistre = await DialogueDeFormulaire.ouvrir(
    context,
    titre: succes == null ? 'Nouveau succès' : 'Modifier le succès',
    libelleAction: succes == null ? 'Créer' : 'Enregistrer',
    enregistrer: () => service.enregistrerSucces(
      id: succes?.id,
      name: nom.text.trim(),
      description: description.text.trim(),
      icon: icone.text.trim(),
      conditionType: critere,
      conditionValue: int.parse(seuil.text.trim()),
      pointsReward: int.parse(points.text.trim()),
      isActive: actif,
    ),
    corps: (context, echec) => StatefulBuilder(
      builder: (context, majEtat) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: nom,
            decoration: InputDecoration(
              labelText: 'Nom *',
              errorText: echec?.pourLeChamp('name'),
            ),
            validator: Valider.requis,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: icone,
            decoration: InputDecoration(labelText: 'Icône (emoji)', errorText: echec?.pourLeChamp('icon')),
            maxLength: 32,
          ),
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
            controller: seuil,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Seuil à atteindre *',
              helperText: eccore.AchievementCondition.uniteDuSeuil(critere),
              errorText: echec?.pourLeChamp('condition_value'),
            ),
            // Un seuil à zéro est atteint d'avance : le serveur le refuse.
            validator: (v) => Valider.entier(v, minimum: 1, message: 'Un seuil d’au moins 1'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: points,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Points offerts',
              errorText: echec?.pourLeChamp('points_reward'),
            ),
            validator: (v) => Valider.entier(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            subtitle: const Text('Un succès inactif ne se débloque plus, sans rien retirer.'),
            value: actif,
            onChanged: (valeur) => majEtat(() => actif = valeur),
          ),
        ],
      ),
    ),
  );

  if (enregistre && context.mounted) {
    annoncer(context, succes == null ? 'Succès créé.' : 'Succès enregistré.');
  }
}
