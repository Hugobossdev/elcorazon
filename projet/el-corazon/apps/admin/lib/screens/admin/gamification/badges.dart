import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/screens/admin/gamification/communs.dart';
import 'package:admin/services/gamification_service.dart';

/// Badges — l'onglet et son formulaire.
///
/// Un badge s'obtient sur les points gagnés **à vie** : c'est la seule règle
/// que le serveur connaît (`Badge.points_required`). Le formulaire proposait
/// un « critère » (points, commandes, dépenses) qui n'était envoyé nulle part
/// — l'opérateur croyait créer un badge « 10 commandes », le serveur en
/// créait un « 10 points ».
class BadgesTab extends StatelessWidget {
  const BadgesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final peutEcrire = service.peutEcrire(CatalogueDeFidelisation.badges);

    return OngletDeCatalogue<eccore.ManagedBadge>(
      elements: service.badges,
      echec: service.echecDe(CatalogueDeFidelisation.badges),
      libelleCreation: 'Nouveau badge',
      peutEcrire: peutEcrire,
      vide: 'Aucun badge',
      onCreer: () => ouvrirFormulaireBadge(context),
      carte: (badge) => CarteDeCatalogue(
        icone: badge.icon,
        titre: badge.title,
        description: badge.description,
        pastilles: ['${badge.pointsRequired} pts gagnés à vie'],
        actif: badge.isActive,
        peutEcrire: peutEcrire,
        onModifier: () => ouvrirFormulaireBadge(context, badge: badge),
        onBasculer: () => context.read<GamificationService>().basculerBadge(badge),
      ),
    );
  }
}

Future<void> ouvrirFormulaireBadge(BuildContext context, {eccore.ManagedBadge? badge}) async {
  final service = context.read<GamificationService>();
  final titre = TextEditingController(text: badge?.title);
  final description = TextEditingController(text: badge?.description);
  final icone = TextEditingController(text: badge?.icon ?? '🏅');
  final points = TextEditingController(text: badge == null ? '' : '${badge.pointsRequired}');
  var actif = badge?.isActive ?? true;

  final enregistre = await DialogueDeFormulaire.ouvrir(
    context,
    titre: badge == null ? 'Nouveau badge' : 'Modifier le badge',
    libelleAction: badge == null ? 'Créer' : 'Enregistrer',
    enregistrer: () => service.enregistrerBadge(
      id: badge?.id,
      title: titre.text.trim(),
      description: description.text.trim(),
      icon: icone.text.trim(),
      pointsRequired: int.parse(points.text.trim()),
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
          TextFormField(
            controller: icone,
            decoration: InputDecoration(labelText: 'Icône (emoji)', errorText: echec?.pourLeChamp('icon')),
            maxLength: 32,
          ),
          TextFormField(
            controller: points,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Points gagnés à vie requis *',
              helperText: 'Sur les points gagnés depuis l’inscription, pas sur le solde : '
                  'un badge ne se perd pas en dépensant ses points.',
              helperMaxLines: 2,
              errorText: echec?.pourLeChamp('points_required'),
            ),
            validator: (v) => Valider.entier(v, minimum: 1, message: 'Au moins 1 point'),
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
    annoncer(context, badge == null ? 'Badge créé.' : 'Badge enregistré.');
  }
}
