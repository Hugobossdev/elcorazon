import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/versements/communs.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/versements_service.dart';

/// Les demandes de retrait des livreurs, et leur constat.
///
/// ## Ce que l'écran comble
///
/// Un livreur qui demandait un retrait voyait ses gains débités à l'instant,
/// puis sa demande rester « en attente » pour toujours : aucun écran ne la
/// montrait, aucune route ne permettait de la solder ou de la refuser. L'argent
/// n'était plus dans l'application et n'était pas chez lui.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne verse rien. Le virement part de l'application du prestataire ; on
/// revient ici **ensuite** en noter la référence. Refuser rend les gains au
/// livreur, qui lit le motif.
class RetraitsLivreursScreen extends StatefulWidget {
  const RetraitsLivreursScreen({super.key});

  @override
  State<RetraitsLivreursScreen> createState() => _RetraitsLivreursScreenState();
}

class _RetraitsLivreursScreenState extends State<RetraitsLivreursScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<VersementsService>().chargerRetraits());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<VersementsService>();
    final peutVerser = context.watch<AdminAuthService>().can('payouts.settle');
    final aVerser = service.aVerserParDevise;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const AvertissementConstat(
            texte: 'Cet écran ne verse rien. Faites le virement depuis l’application '
                'du prestataire, puis revenez « Constater » avec sa référence. '
                '« Refuser » rend le montant aux gains du livreur.',
          ),
          BarreDeFiltre(
            filtre: service.filtreRetraits,
            total: service.totalRetraits,
            resume: aVerser.isEmpty
                ? null
                : 'À verser : ${aVerser.entries.map((e) => eccore.Money(amountMinor: e.value, currency: e.key).format()).join(' + ')}',
            onChanged: (filtre) => unawaited(service.chargerRetraits(filtre: filtre)),
            onRecharger: () => unawaited(service.chargerRetraits()),
          ),
          Expanded(
            child: EtatDeListe(
              chargement: service.chargementRetraits,
              erreur: service.erreurRetraits,
              vide: service.retraits.isEmpty,
              messageVide: service.filtreRetraits == FiltreVersements.aTraiter
                  ? 'Aucune demande de retrait en attente.'
                  : 'Aucun retrait dans votre périmètre.',
              onReessayer: () => unawaited(service.chargerRetraits()),
              liste: RefreshIndicator(
                onRefresh: service.chargerRetraits,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: service.retraits.length,
                  itemBuilder: (context, index) => _CarteRetrait(
                    retrait: service.retraits[index],
                    peutVerser: peutVerser,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteRetrait extends StatelessWidget {
  const _CarteRetrait({required this.retrait, required this.peutVerser});

  final eccore.ManagedWithdrawal retrait;
  final bool peutVerser;

  Future<void> _constater(BuildContext context) async {
    final service = context.read<VersementsService>();
    final messager = ScaffoldMessenger.of(context);
    final reference = await demanderTexte(
      context,
      titre: 'Constater le versement',
      explication: 'Vous avez versé ${retrait.amount.format()} à ${retrait.courierName}. '
          'Notez la référence du virement : c’est la preuve qu’on cherchera si le '
          'livreur affirme n’avoir rien reçu.',
      libelle: 'Référence du virement',
      action: 'Constater',
    );
    if (reference == null) return;
    final refus = await service.constaterRetrait(retrait.id, reference: reference);
    messager.showSnackBar(
      SnackBar(content: Text(refus ?? 'Versement constaté — ${retrait.courierName} est prévenu.')),
    );
  }

  Future<void> _refuser(BuildContext context) async {
    final service = context.read<VersementsService>();
    final messager = ScaffoldMessenger.of(context);
    final motif = await demanderTexte(
      context,
      titre: 'Refuser le versement',
      explication: '${retrait.amount.format()} seront rendus aux gains de '
          '${retrait.courierName}, qui lira ce motif.',
      libelle: 'Motif',
      action: 'Refuser',
      destructif: true,
    );
    if (motif == null) return;
    final refus = await service.refuserRetrait(retrait.id, motif: motif);
    messager.showSnackBar(
      SnackBar(content: Text(refus ?? 'Versement refusé — gains rendus au livreur.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enCours = context.watch<VersementsService>().enCours(retrait.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    retrait.amount.format(),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                PastilleStatut(statut: retrait.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(retrait.courierName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (retrait.courierPhone != null && retrait.courierPhone!.isNotEmpty)
                  NumeroCopiable(numero: retrait.courierPhone!)
                else
                  Text('Aucun numéro au dossier', style: TextStyle(color: theme.colorScheme.error)),
                Text(retrait.restaurantName, style: TextStyle(color: theme.hintColor)),
                Text(
                  'Demandé le ${dateCourte(retrait.createdAt)}',
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
            if (!retrait.aInstruire) ...[
              const SizedBox(height: 8),
              Text(
                retrait.status == eccore.StatutVersement.verse
                    ? 'Référence ${retrait.providerReference}'
                        '${retrait.processedByName == null ? '' : ' · constaté par ${retrait.processedByName}'}'
                        '${retrait.completedAt == null ? '' : ' le ${dateCourte(retrait.completedAt!)}'}'
                    : 'Motif : ${retrait.failureReason}'
                        '${retrait.processedByName == null ? '' : ' · refusé par ${retrait.processedByName}'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (retrait.aInstruire && peutVerser) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: enCours ? null : () => unawaited(_constater(context)),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Constater le versement'),
                  ),
                  OutlinedButton.icon(
                    onPressed: enCours ? null : () => unawaited(_refuser(context)),
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Refuser'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
