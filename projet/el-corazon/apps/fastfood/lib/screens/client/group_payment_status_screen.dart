import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elcora_fast/presentation/paiement_partage.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

class GroupPaymentStatusScreen extends StatefulWidget {
  final String orderId;
  final String groupId;

  const GroupPaymentStatusScreen({
    required this.orderId,
    required this.groupId,
    super.key,
  });

  @override
  State<GroupPaymentStatusScreen> createState() =>
      _GroupPaymentStatusScreenState();
}

class _GroupPaymentStatusScreenState extends State<GroupPaymentStatusScreen> {
  final eccore.PaymentRepository _payments =
      eccore.PaymentRepository(apiClient: apiClient);
  eccore.SplitPayment? _session;
  bool _isLoading = true;
  String? _loadError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final split = await _payments.getSplit(widget.orderId);
      if (mounted) {
        setState(() {
          _session = split;
          _isLoading = false;
          _loadError = null;
        });
      }
    } on eccore.ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.status == 404
              ? 'Aucun partage ouvert sur cette commande'
              : e.detail;
        });
      }
    }
  }

  /// Sondage périodique plutôt qu'un abonnement : une part n'est soldée que
  /// par le webhook signé du prestataire, côté serveur — il n'y a pas d'écriture
  /// client à écouter, et le backend n'expose pas de canal temps réel sur les
  /// paiements.
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadSession();
      }
    });
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statut des Paiements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSession,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadError!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSession,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _session == null
                  ? const Center(
                      child: Text('Aucune session de paiement trouvée'),
                    )
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final session = _session!;
    final paidCount = session.shares
        .where((p) => p.isPaid)
        .length;
    final totalCount = session.shares.length;
    final remaining = session.totalAmount.toMajorUnits() - session.paidAmount.toMajorUnits();

    return Column(
      children: [
        // Résumé global
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Résumé des Paiements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    'Total',
                    PriceFormatter.format(session.totalAmount.toMajorUnits()),
                    Colors.white,
                  ),
                  _buildSummaryItem(
                    'Payé',
                    PriceFormatter.format(session.paidAmount.toMajorUnits()),
                    AppColors.success,
                  ),
                  _buildSummaryItem(
                    'Restant',
                    PriceFormatter.format(remaining),
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: session.totalAmount.amountMinor > 0
                          ? session.paidAmount.amountMinor /
                              session.totalAmount.amountMinor
                          : 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$paidCount/$totalCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Liste des participants
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: session.shares.length,
            itemBuilder: (context, index) {
              final participant = session.shares[index];
              return _buildParticipantCard(participant);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCard(eccore.SplitShare participant) {
    final etat = EtatPart.depuisServeur(participant.status);
    final statusColor = etat.couleur;
    final statusIcon = etat.icone;
    final statusText = etat.libelle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  child: Text(
                    participant.displayName.isNotEmpty
                        ? participant.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              participant.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Montant à payer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PriceFormatter.format(participant.amount.toMajorUnits()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (participant.isPaid)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Payé',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PriceFormatter.format(participant.amount.toMajorUnits()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (participant.phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    participant.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
