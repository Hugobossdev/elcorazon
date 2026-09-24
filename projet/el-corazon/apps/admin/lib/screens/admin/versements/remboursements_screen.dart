import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/versements/communs.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/versements_service.dart';

/// Les remboursements demandés, et leur clôture.
///
/// Un remboursement se demandait depuis la fiche d'une commande, puis restait
/// « en attente » : seule l'action « Constater le virement » de
/// l'administration Django pouvait le clore — un second outil, que l'opérateur
/// qui venait de le demander n'avait pas. La transaction d'origine ne passait
/// donc jamais « remboursée », et la commande restait « déjà réglée ».
class RemboursementsScreen extends StatefulWidget {
  const RemboursementsScreen({super.key});

  @override
  State<RemboursementsScreen> createState() => _RemboursementsScreenState();
}

class _RemboursementsScreenState extends State<RemboursementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<VersementsService>().chargerRemboursements());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<VersementsService>();
    final peutRembourser = context.watch<AdminAuthService>().can('orders.refund');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const AvertissementConstat(
            texte: 'Cet écran ne rembourse rien. PayDunya n’a pas d’API de remboursement : '
                'le virement part de son tableau de bord. Revenez ensuite « Constater » '
                'qu’il a été fait.',
          ),
          BarreDeFiltre(
            filtre: service.filtreRemboursements,
            total: service.totalRemboursements,
            onChanged: (filtre) => unawaited(service.chargerRemboursements(filtre: filtre)),
            onRecharger: () => unawaited(service.chargerRemboursements()),
          ),
          Expanded(
            child: EtatDeListe(
              chargement: service.chargementRemboursements,
              erreur: service.erreurRemboursements,
              vide: service.remboursements.isEmpty,
              messageVide: service.filtreRemboursements == FiltreVersements.aTraiter
                  ? 'Aucun remboursement en attente de versement.'
                  : 'Aucun remboursement dans votre périmètre.',
              onReessayer: () => unawaited(service.chargerRemboursements()),
              liste: RefreshIndicator(
                onRefresh: service.chargerRemboursements,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: service.remboursements.length,
                  itemBuilder: (context, index) => _CarteRemboursement(
                    remboursement: service.remboursements[index],
                    peutRembourser: peutRembourser,
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

class _CarteRemboursement extends StatelessWidget {
  const _CarteRemboursement({required this.remboursement, required this.peutRembourser});

  final eccore.ManagedRefund remboursement;
  final bool peutRembourser;

  Future<void> _constater(BuildContext context) async {
    final service = context.read<VersementsService>();
    final messager = ScaffoldMessenger.of(context);
    final reference = await demanderTexte(
      context,
      titre: 'Constater le remboursement',
      explication: '${remboursement.amount.format()} rendus à ${remboursement.customerName} '
          '(commande ${remboursement.orderReference}). La référence du virement est '
          'facultative : un remboursement rendu au comptoir n’en a pas.',
      libelle: 'Référence du virement (facultative)',
      action: 'Constater',
      obligatoire: false,
    );
    if (reference == null) return;
    final refus = await service.constaterRemboursement(remboursement.id, reference: reference);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Remboursement constaté.')));
  }

  /// Abandonne une demande qui ne sera pas versée.
  ///
  /// Sans ce geste, une demande saisie par erreur restait en attente pour
  /// toujours **et** consommait le plafond du remboursable : la commande ne
  /// pouvait plus être remboursée du bon montant.
  Future<void> _abandonner(BuildContext context) async {
    final service = context.read<VersementsService>();
    final messager = ScaffoldMessenger.of(context);
    final motif = await demanderTexte(
      context,
      titre: 'Abandonner ce remboursement',
      explication: 'Rien ne sera versé à ${remboursement.customerName} '
          '(commande ${remboursement.orderReference}). Le montant redevient remboursable, '
          'et le motif reste au dossier : c’est lui qu’on cherchera si le client réclame.',
      libelle: 'Motif de l’abandon',
      action: 'Abandonner',
    );
    if (motif == null) return;
    final refus = await service.abandonnerRemboursement(remboursement.id, motif: motif);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Remboursement abandonné.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enCours = context.watch<VersementsService>().enCours(remboursement.id);

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
                    remboursement.amount.format(),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                PastilleStatut(statut: remboursement.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Commande ${remboursement.orderReference}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(remboursement.customerName),
                if (remboursement.customerPhone != null && remboursement.customerPhone!.isNotEmpty)
                  NumeroCopiable(numero: remboursement.customerPhone!),
                Text('Payé par ${remboursement.provider}', style: TextStyle(color: theme.hintColor)),
                Text(remboursement.restaurantName, style: TextStyle(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Motif : ${remboursement.reason} · demandé par ${remboursement.requestedByName} '
              'le ${dateCourte(remboursement.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (remboursement.completedAt != null)
              Text(
                'Constaté le ${dateCourte(remboursement.completedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            if (remboursement.aVerser && peutRembourser) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: enCours ? null : () => unawaited(_constater(context)),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Constater le remboursement'),
                  ),
                  OutlinedButton.icon(
                    onPressed: enCours ? null : () => unawaited(_abandonner(context)),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Abandonner'),
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
