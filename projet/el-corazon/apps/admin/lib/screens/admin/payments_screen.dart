import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/barre_pagination.dart';
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/price_formatter.dart';

/// Les encaissements — `/payments/transactions/`.
///
/// **Consultation seule, et par construction** : le statut d'une transaction
/// n'avance que sur webhook signé du prestataire (`apps/payments/services.py`).
/// Le seul geste offert est le remboursement, depuis la fiche de la commande,
/// qui exige `orders.refund` et laisse l'encaissement d'origine intact.
///
/// ## Ce qui a changé (22 septembre 2026)
///
/// * la liste est **paginée par le serveur** : elle téléchargeait tout
///   l'historique des encaissements du périmètre, sans borne de date ;
/// * la recherche part au serveur (référence du prestataire **et** de la
///   commande) : elle ne portait que sur ce qui avait été chargé ;
/// * période, établissement, devise et statut « Annulé » s'y filtrent ;
/// * les totaux viennent du serveur, **une ligne par devise** : l'écran
///   additionnait des XOF et des XAF sous un même « FCFA ».
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _recherche = TextEditingController();
  Timer? _frappe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PaymentsService>().initialize());
    });
  }

  @override
  void dispose() {
    _frappe?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _appliquer(FiltresEncaissements filtres) =>
      unawaited(context.read<PaymentsService>().appliquer(filtres));

  void _surFrappe(String valeur) {
    _frappe?.cancel();
    _frappe = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final service = context.read<PaymentsService>();
      _appliquer(service.filtres.copyWith(recherche: valeur));
    });
  }

  Future<void> _choisirPeriode(FiltresEncaissements filtres) async {
    final maintenant = DateTime.now();
    final choisie = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: maintenant,
      initialDateRange: filtres.depuis == null || filtres.jusqua == null
          ? null
          : DateTimeRange(start: filtres.depuis!, end: filtres.jusqua!),
    );
    if (choisie == null) return;
    _appliquer(
      filtres.copyWith(
        depuis: DateTime(choisie.start.year, choisie.start.month, choisie.start.day),
        // La borne haute inclut la journée entière : sans cela, les
        // encaissements du dernier jour choisi tombaient hors sélection.
        jusqua: DateTime(choisie.end.year, choisie.end.month, choisie.end.day, 23, 59, 59),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PaymentsService>();
    final perimetre = context.watch<RestaurantScopeService>();
    final filtres = service.filtres;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _recherche,
                    onChanged: _surFrappe,
                    decoration: const InputDecoration(
                      labelText: 'Référence',
                      helperText: 'Prestataire ou commande — cherchée par le serveur.',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: filtres.statut,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('Tous')),
                      // La liste vient du serveur (`PaymentStatus`) : « Annulé »
                      // y manquait, et ces transactions n'apparaissaient sous
                      // aucun filtre.
                      for (final statut in eccore.PaymentStatus.values)
                        DropdownMenuItem(
                          value: statut,
                          child: Text(eccore.PaymentStatus.libelle(statut)),
                        ),
                    ],
                    onChanged: (valeur) => _appliquer(
                      filtres.copyWith(statut: valeur, effacerStatut: valeur == null),
                    ),
                  ),
                ),
                if (perimetre.hasChoice)
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: filtres.restaurantSlug,
                      decoration: const InputDecoration(
                        labelText: 'Établissement',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(child: Text('Tout mon périmètre')),
                        for (final etablissement in perimetre.restaurants)
                          DropdownMenuItem(
                            value: etablissement.slug,
                            child: Text(etablissement.name),
                          ),
                      ],
                      onChanged: (valeur) => _appliquer(
                        filtres.copyWith(
                          restaurantSlug: valeur,
                          effacerRestaurant: valeur == null,
                        ),
                      ),
                    ),
                  ),
                if (perimetre.devises.length > 1)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: filtres.devise,
                      decoration: const InputDecoration(
                        labelText: 'Devise',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(child: Text('Toutes')),
                        for (final devise in perimetre.devises)
                          DropdownMenuItem(value: devise, child: Text(devise)),
                      ],
                      onChanged: (valeur) => _appliquer(
                        filtres.copyWith(devise: valeur, effacerDevise: valeur == null),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded),
                  onPressed: () => unawaited(_choisirPeriode(filtres)),
                  label: Text(
                    filtres.depuis == null
                        ? 'Toute la période'
                        : 'Du ${dateCourte(filtres.depuis!)} au ${dateCourte(filtres.jusqua!)}',
                  ),
                ),
                if (filtres.depuis != null)
                  TextButton(
                    onPressed: () => _appliquer(filtres.copyWith(effacerPeriode: true)),
                    child: const Text('Toute la période'),
                  ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recharger',
                  onPressed: service.isLoading ? null : () => unawaited(service.refresh()),
                ),
              ],
            ),
          ),
          if (service.echec != null)
            BandeauEchec(echec: service.echec!, onReessayer: () => unawaited(service.refresh())),
          _Totaux(totaux: service.totaux, total: service.total),
          Expanded(
            child: service.isLoading && service.transactions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : service.transactions.isEmpty
                    ? const Center(child: Text('Aucun encaissement pour cette sélection.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: service.transactions.length,
                        itemBuilder: (context, index) =>
                            _LigneTransaction(transaction: service.transactions[index]),
                      ),
          ),
          BarrePagination(
            numeroDePage: service.numeroDePage,
            nombreDePages: service.nombreDePages,
            total: service.total,
            enCours: service.isLoading,
            onPrecedente: service.aPagePrecedente ? () => unawaited(service.pagePrecedente()) : null,
            onSuivante: service.aPageSuivante ? () => unawaited(service.pageSuivante()) : null,
          ),
        ],
      ),
    );
  }
}

/// Ce que porte la sélection — **une ligne par devise**, comptée par le
/// serveur sur toute la sélection et non sur la page affichée.
class _Totaux extends StatelessWidget {
  const _Totaux({required this.totaux, required this.total});

  final eccore.TransactionSummary? totaux;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final resume = totaux;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _Compteur(libelle: 'Transactions', valeur: '$total', couleur: scheme.primary),
          if (resume != null)
            _Compteur(
              libelle: 'Encaissées',
              valeur: '${resume.compteDe(eccore.PaymentStatus.completed)}',
              couleur: sem.success,
            ),
          if (resume != null && resume.collected.isEmpty)
            _Compteur(libelle: 'Encaissé', valeur: 'Aucun', couleur: sem.success),
          for (final ligne in resume?.collected ?? const <({eccore.Money amount, int transactions})>[])
            _Compteur(
              libelle: 'Encaissé (${ligne.amount.currency})',
              valeur: formatMontant(ligne.amount),
              couleur: sem.success,
            ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.libelle, required this.valeur, required this.couleur});

  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valeur,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: couleur),
        ),
        Text(
          libelle,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LigneTransaction extends StatelessWidget {
  const _LigneTransaction({required this.transaction});

  final eccore.Transaction transaction;

  Color _couleur(ColorScheme scheme) {
    final sem = AdminColorTokens.semantic(scheme);
    return switch (transaction.status) {
      eccore.PaymentStatus.completed => sem.success,
      eccore.PaymentStatus.failed => sem.danger,
      eccore.PaymentStatus.cancelled => scheme.outline,
      eccore.PaymentStatus.refunded => scheme.tertiary,
      _ => sem.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                    formatMontant(transaction.amount),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(eccore.PaymentStatus.libelle(transaction.status)),
                  backgroundColor: _couleur(scheme).withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Champ(label: 'Prestataire', valeur: transaction.provider),
            _Champ(label: 'Référence', valeur: transaction.providerReference, copiable: true),
            _Champ(
              label: 'Date',
              valeur: dateCourte(transaction.completedAt ?? transaction.createdAt),
            ),
            if (transaction.failureReason.isNotEmpty)
              _Champ(label: 'Motif d’échec', valeur: transaction.failureReason),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Voir la commande'),
                onPressed: () => unawaited(_ouvrirLaCommande(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre la fiche de la commande réglée par cette transaction.
  ///
  /// La transaction ne porte que l'identifiant de la commande : la fiche se
  /// charge donc depuis le serveur, ce qui rend au passage ses lignes — que la
  /// forme de liste ne contient pas.
  Future<void> _ouvrirLaCommande(BuildContext context) async {
    final commandes = context.read<OrderManagementService>();
    final commande = await commandes.loadDetail(transaction.orderId);

    if (!context.mounted) return;
    if (commande == null) {
      annoncer(
        context,
        'Commande introuvable : elle est hors du périmètre de ce compte.',
      );
      return;
    }
    afficherDetailsCommande(context, commande);
  }
}

class _Champ extends StatelessWidget {
  const _Champ({required this.label, required this.valeur, this.copiable = false});

  final String label;
  final String valeur;
  final bool copiable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (copiable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copier la référence',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: valeur));
                if (!context.mounted) return;
                annoncer(context, 'Référence copiée.');
              },
            ),
        ],
      ),
    );
  }
}
