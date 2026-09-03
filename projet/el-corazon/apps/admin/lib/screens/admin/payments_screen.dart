import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/price_formatter.dart';

/// Les encaissements — `/payments/transactions/` (Phase 6).
///
/// Pourquoi cet écran existe
/// -------------------------
///
/// `PaymentsService` était écrit, câblé, cloisonné par le serveur… et
/// **injoignable**. Un seul fichier le lisait — l'écran des commandes qu'aucune
/// entrée de navigation n'ouvre — et pour un seul geste, le remboursement. Il
/// n'existait aucun endroit où consulter ce qui avait été encaissé : ni la
/// liste, ni un montant, ni une référence de transaction, ni une date.
/// L'exploitation devait ouvrir le tableau de bord du prestataire pour savoir
/// si une commande avait été payée.
///
/// **Consultation seule, et pas par prudence : par construction.** Le statut
/// d'une transaction n'avance que sur webhook signé du prestataire
/// (`apps/payments/services.py`) ; aucune route ne permet à un client de
/// l'écrire, et il n'y a donc rien à interdire ici. Le seul geste offert est le
/// remboursement, qui crée un objet distinct, exige `orders.refund`, et laisse
/// l'encaissement d'origine intact — un paiement a eu lieu, l'écraser ferait
/// disparaître ce fait.
///
/// Le périmètre est celui du serveur : un opérateur ne voit que les
/// encaissements des établissements auxquels son compte est rattaché.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _recherche = TextEditingController();

  /// Statut filtré **côté serveur** : `TransactionViewSet` accepte `status` en
  /// `exact`. Le faire ici obligerait à charger toutes les pages pour n'en
  /// garder qu'une part.
  String? _statut;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PaymentsService>().initialize());
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _recharger() => context.read<PaymentsService>().refresh(status: _statut);

  /// Filtre d'affichage sur la référence du prestataire.
  ///
  /// Volontairement local, contrairement au statut : le serveur n'expose pas de
  /// recherche sur `provider_reference`, et prétendre chercher dans tout
  /// l'historique alors qu'on ne parcourt que la page chargée serait pire que
  /// de ne rien proposer. Le champ dit donc ce qu'il fait.
  List<eccore.Transaction> _filtrees(List<eccore.Transaction> toutes) {
    final terme = _recherche.text.trim().toLowerCase();
    if (terme.isEmpty) return toutes;
    return toutes
        .where(
          (t) =>
              t.providerReference.toLowerCase().contains(terme) ||
              t.provider.toLowerCase().contains(terme),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: Consumer<PaymentsService>(
        builder: (context, paiements, child) {
          final transactions = _filtrees(paiements.transactions);

          return Column(
            children: [
              _barre(context, paiements),
              if (paiements.error != null) _bandeauErreur(paiements),
              _totaux(context, transactions),
              Expanded(
                child: paiements.isLoading && paiements.transactions.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : transactions.isEmpty
                        ? _vide(context)
                        : RefreshIndicator(
                            onRefresh: _recharger,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: transactions.length,
                              itemBuilder: (context, index) => _LigneTransaction(
                                transaction: transactions[index],
                              ),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _barre(BuildContext context, PaymentsService paiements) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _recherche,
              decoration: InputDecoration(
                hintText: 'Filtrer par référence ou prestataire…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _statut,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<String?>(child: Text('Tous')),
                DropdownMenuItem(value: 'completed', child: Text('Encaissés')),
                DropdownMenuItem(value: 'pending', child: Text('En attente')),
                DropdownMenuItem(value: 'processing', child: Text('En cours')),
                DropdownMenuItem(value: 'failed', child: Text('Échoués')),
                DropdownMenuItem(value: 'refunded', child: Text('Remboursés')),
              ],
              onChanged: (valeur) {
                setState(() => _statut = valeur);
                unawaited(_recharger());
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: paiements.isLoading ? null : _recharger,
          ),
        ],
      ),
    );
  }

  Widget _bandeauErreur(PaymentsService paiements) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              paiements.error!,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
            ),
          ),
          TextButton(onPressed: _recharger, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  /// Ce que porte la sélection affichée.
  ///
  /// Seuls les encaissements **aboutis** sont additionnés : mêler à ce total
  /// des transactions en attente ou échouées annoncerait de l'argent qui n'est
  /// pas rentré.
  Widget _totaux(BuildContext context, List<eccore.Transaction> transactions) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final encaisses = transactions.where((t) => t.status == 'completed').toList();
    final total = encaisses.fold<int>(
      0,
      (somme, t) => somme + t.amount.amountMinor,
    );

    return Container(
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
          _Compteur(
            libelle: 'Transactions affichées',
            valeur: '${transactions.length}',
            couleur: scheme.primary,
          ),
          _Compteur(
            libelle: 'Encaissées',
            valeur: '${encaisses.length}',
            couleur: sem.success,
          ),
          _Compteur(
            libelle: 'Total encaissé',
            valeur: PriceFormatter.format(total.toDouble()),
            couleur: sem.success,
          ),
        ],
      ),
    );
  }

  Widget _vide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _recherche.text.isNotEmpty
                  ? 'Aucune transaction ne correspond à ce filtre.'
                  : 'Aucune transaction sur ce périmètre.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les commandes réglées en espèces n’en produisent pas : rien '
              'n’est encaissé avant la remise au livreur.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.libelle,
    required this.valeur,
    required this.couleur,
  });

  final String libelle;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valeur,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: couleur,
          ),
        ),
        Text(
          libelle,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Une transaction : ce que le cahier des charges demande d'afficher —
/// transaction, commande, montant, statut, référence, date — et rien de plus.
class _LigneTransaction extends StatelessWidget {
  const _LigneTransaction({required this.transaction});

  final eccore.Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final couleur = switch (transaction.status) {
      'completed' => sem.success,
      'failed' || 'cancelled' => sem.danger,
      'refunded' => scheme.tertiary,
      _ => sem.warning,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    libelleStatutPaiement(transaction.status),
                    style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  transaction.provider,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  PriceFormatter.format(transaction.amount.toMajorUnits()),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: couleur,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Champ(
              label: 'Référence',
              // Copiable : c'est la valeur qu'on recolle dans le tableau de
              // bord du prestataire pour instruire un litige.
              valeur: transaction.providerReference.isEmpty
                  ? '—'
                  : transaction.providerReference,
              copiable: transaction.providerReference.isNotEmpty,
            ),
            _Champ(
              label: 'Date',
              valeur: _horodatage(transaction.completedAt ?? transaction.createdAt),
            ),
            if (transaction.failureReason.isNotEmpty)
              _Champ(label: 'Motif d’échec', valeur: transaction.failureReason),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Voir la commande'),
                onPressed: () => _ouvrirLaCommande(context),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Commande introuvable : elle est hors du périmètre de ce compte.',
          ),
        ),
      );
      return;
    }
    afficherDetailsCommande(context, commande);
  }
}

class _Champ extends StatelessWidget {
  const _Champ({
    required this.label,
    required this.valeur,
    this.copiable = false,
  });

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Référence copiée.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

String _horodatage(DateTime moment) {
  final local = moment.toLocal();
  String deuxChiffres(int valeur) => valeur.toString().padLeft(2, '0');
  return '${deuxChiffres(local.day)}/${deuxChiffres(local.month)}/${local.year}'
      ' à ${deuxChiffres(local.hour)}:${deuxChiffres(local.minute)}';
}
