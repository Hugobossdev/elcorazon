import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/screens/admin/gamification/communs.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/gamification_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/utils/price_formatter.dart';

/// Récompenses — l'onglet et son formulaire.
///
/// Relevé le 21 septembre 2026 : l'onglet lisait `title`, `cost` et
/// `reward_type`, clés que personne ne produisait (le serveur rend `name`,
/// `points_cost`, `kind`). Les trois récompenses en base s'affichaient sans
/// titre, « 0 pts », et leur modification repartait avec un titre vide et un
/// coût nul. Le formulaire ne proposait pas d'établissement — toute récompense
/// naissait « nationale », que le serveur refuse à un gérant — ni de durée de
/// validité, et ignorait l'interrupteur « Actif » à la création.
class RewardsTab extends StatelessWidget {
  const RewardsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final perimetre = context.watch<RestaurantScopeService>();
    final peutEcrire = service.peutEcrire(CatalogueDeFidelisation.recompenses);

    return OngletDeCatalogue<eccore.ManagedReward>(
      elements: service.recompenses,
      echec: service.echecDe(CatalogueDeFidelisation.recompenses),
      libelleCreation: 'Nouvelle récompense',
      peutEcrire: peutEcrire,
      vide: 'Aucune récompense',
      onCreer: () => ouvrirFormulaireRecompense(context),
      carte: (recompense) {
        final portee = recompense.isNational
            ? 'Nationale'
            : (perimetre.parId(recompense.restaurantId)?.name ?? 'Établissement hors périmètre');
        return CarteDeCatalogue(
          icone: recompense.kind == eccore.RewardKind.freeDelivery ? '🛵' : '🎁',
          titre: recompense.name,
          description: recompense.description,
          pastilles: [
            '${recompense.pointsCost} pts',
            eccore.RewardKind.libelle(recompense.kind),
            if (recompense.kind == eccore.RewardKind.discount) formatMontant(recompense.discount),
            'Valable ${recompense.validityDays} j',
            portee,
          ],
          actif: recompense.isActive,
          // Une récompense nationale ne se modifie qu'au siège : le bouton
          // n'est pas offert à qui le serveur la refusera.
          peutEcrire: peutEcrire && (!recompense.isNational || context.estSiege),
          onModifier: () => ouvrirFormulaireRecompense(context, recompense: recompense),
          onBasculer: () => context.read<GamificationService>().basculerRecompense(recompense),
        );
      },
    );
  }
}

/// Qui paie la récompense : un établissement du périmètre, ou toute
/// l'enseigne (siège seulement).
const String _nationale = '__nationale__';

Future<void> ouvrirFormulaireRecompense(
  BuildContext context, {
  eccore.ManagedReward? recompense,
}) async {
  final service = context.read<GamificationService>();
  final perimetre = context.read<RestaurantScopeService>();
  // Lu une fois : le formulaire est hors de `build`, `context.estSiege` y
  // écouterait une session qu'il n'a pas à suivre.
  final siege = context.read<AdminAuthService>().estSiege;

  final nom = TextEditingController(text: recompense?.name);
  final description = TextEditingController(text: recompense?.description);
  final cout = TextEditingController(text: recompense == null ? '' : '${recompense.pointsCost}');
  final remise = TextEditingController(
    text: recompense == null || recompense.kind != eccore.RewardKind.discount
        ? ''
        : montantEnSaisie(recompense.discount.toMajorUnits()),
  );
  final validite = TextEditingController(text: '${recompense?.validityDays ?? 30}');
  var nature = recompense?.kind ?? eccore.RewardKind.discount;
  var actif = recompense?.isActive ?? true;
  // L'établissement par défaut : celui de la récompense, sinon celui qui est
  // sélectionné. Un gérant n'a pas l'option nationale.
  var porteur = recompense == null
      ? (perimetre.current?.id ?? (siege ? _nationale : null))
      : (recompense.restaurantId ?? _nationale);
  // La devise d'une récompense nationale se choisit : XOF et XAF sont deux
  // monnaies, et un code libellé dans l'une est refusé dans l'autre.
  var deviseNationale = recompense?.isNational ?? false
      ? recompense!.discount.currency
      : (perimetre.devises.firstOrNull ?? '');

  String devise() =>
      porteur == _nationale ? deviseNationale : (perimetre.parId(porteur)?.currency ?? deviseNationale);

  final enregistre = await DialogueDeFormulaire.ouvrir(
    context,
    titre: recompense == null ? 'Nouvelle récompense' : 'Modifier la récompense',
    libelleAction: recompense == null ? 'Créer' : 'Enregistrer',
    enregistrer: () => service.enregistrerRecompense(
      id: recompense?.id,
      name: nom.text.trim(),
      description: description.text.trim(),
      kind: nature,
      pointsCost: int.parse(cout.text.trim()),
      validityDays: int.parse(validite.text.trim()),
      isActive: actif,
      discount: nature == eccore.RewardKind.discount
          ? eccore.Money.fromMajorUnits(lireMontant(remise.text)!, devise())
          : null,
      restaurantId: recompense != null || porteur == _nationale ? null : porteur,
    ),
    corps: (context, echec) => StatefulBuilder(
      builder: (context, majEtat) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: nom,
            decoration: InputDecoration(labelText: 'Nom *', errorText: echec?.pourLeChamp('name')),
            validator: Valider.requis,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (recompense == null)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: porteur,
              decoration: InputDecoration(
                labelText: 'Établissement *',
                helperText: siege
                    ? 'Une récompense nationale s’échange dans tous les établissements.'
                    : 'Une récompense nationale relève du siège.',
                errorText: echec?.pourLeChamp('restaurant'),
              ),
              items: [
                if (siege) const DropdownMenuItem(value: _nationale, child: Text('Nationale — tous')),
                for (final etablissement in perimetre.restaurants)
                  DropdownMenuItem(
                    value: etablissement.id,
                    child: Text('${etablissement.name} (${etablissement.currency})'),
                  ),
              ],
              validator: (valeur) => valeur == null ? 'Choisissez qui offre la récompense' : null,
              onChanged: (valeur) => majEtat(() => porteur = valeur),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Établissement'),
              child: Text(
                porteur == _nationale
                    ? 'Nationale — tous les établissements'
                    : (perimetre.parId(porteur)?.name ?? 'Établissement hors périmètre'),
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cout,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Coût en points *',
              errorText: echec?.pourLeChamp('points_cost'),
            ),
            // À zéro point, l'échange ne débite rien : le serveur le refuse.
            validator: (v) => Valider.entier(v, minimum: 1, message: 'Au moins 1 point'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: nature,
            decoration: InputDecoration(
              labelText: 'Nature *',
              errorText: echec?.pourLeChamp('kind'),
            ),
            items: [
              for (final valeur in eccore.RewardKind.values)
                DropdownMenuItem(value: valeur, child: Text(eccore.RewardKind.libelle(valeur))),
            ],
            onChanged: (valeur) => majEtat(() => nature = valeur ?? nature),
          ),
          if (nature == eccore.RewardKind.discount) ...[
            const SizedBox(height: 12),
            if (porteur == _nationale && recompense == null && perimetre.devises.length > 1)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: deviseNationale,
                decoration: const InputDecoration(labelText: 'Devise de la remise *'),
                items: [
                  for (final code in perimetre.devises)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (valeur) => majEtat(() => deviseNationale = valeur ?? deviseNationale),
              ),
            TextFormField(
              controller: remise,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant de la remise (${devise()}) *',
                helperText: 'Un montant, pas un pourcentage.',
                errorText: echec?.pourLeChamp('discount'),
              ),
              validator: (v) => Valider.montantEn(devise(), v),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: validite,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Validité du code obtenu (jours) *',
              errorText: echec?.pourLeChamp('validity_days'),
            ),
            validator: (v) => Valider.entier(v, minimum: 1, message: 'Au moins 1 jour'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text('Une récompense inactive disparaît du catalogue client.'),
            value: actif,
            onChanged: (valeur) => majEtat(() => actif = valeur),
          ),
        ],
      ),
    ),
  );

  if (enregistre && context.mounted) {
    annoncer(context, recompense == null ? 'Récompense créée.' : 'Récompense enregistrée.');
  }
}
