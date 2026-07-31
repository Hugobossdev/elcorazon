import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/group_payment.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/services/app_service.dart';
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
  GroupPaymentSession? _session;
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
          _session = GroupPaymentSession.fromRemote(split);
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

  String _getStatusText(GroupPaymentParticipantStatus status) {
    switch (status) {
      case GroupPaymentParticipantStatus.paid:
        return 'Payé';
      case GroupPaymentParticipantStatus.processing:
        return 'En traitement';
      case GroupPaymentParticipantStatus.failed:
        return 'Échoué';
      case GroupPaymentParticipantStatus.cancelled:
        return 'Annulé';
      case GroupPaymentParticipantStatus.pending:
        return 'En attente';
    }
  }

  IconData _getStatusIcon(GroupPaymentParticipantStatus status) {
    switch (status) {
      case GroupPaymentParticipantStatus.paid:
        return Icons.check_circle;
      case GroupPaymentParticipantStatus.processing:
        return Icons.hourglass_empty;
      case GroupPaymentParticipantStatus.failed:
        return Icons.error;
      case GroupPaymentParticipantStatus.cancelled:
        return Icons.cancel;
      case GroupPaymentParticipantStatus.pending:
        return Icons.pending;
    }
  }

  Color _getStatusColor(GroupPaymentParticipantStatus status) {
    switch (status) {
      case GroupPaymentParticipantStatus.paid:
        return AppColors.success;
      case GroupPaymentParticipantStatus.processing:
        return AppColors.primary;
      case GroupPaymentParticipantStatus.failed:
        return AppColors.error;
      case GroupPaymentParticipantStatus.cancelled:
        return Colors.grey;
      case GroupPaymentParticipantStatus.pending:
        return Colors.orange;
    }
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
    final paidCount = session.participants
        .where((p) => p.status == GroupPaymentParticipantStatus.paid)
        .length;
    final totalCount = session.participants.length;
    final remaining = session.totalAmount - session.paidAmount;

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
                    PriceFormatter.format(session.totalAmount),
                    Colors.white,
                  ),
                  _buildSummaryItem(
                    'Payé',
                    PriceFormatter.format(session.paidAmount),
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
                      value: session.totalAmount > 0
                          ? session.paidAmount / session.totalAmount
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
            itemCount: session.participants.length,
            itemBuilder: (context, index) {
              final participant = session.participants[index];
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

  Widget _buildParticipantCard(GroupPaymentParticipant participant) {
    final statusColor = _getStatusColor(participant.status);
    final statusIcon = _getStatusIcon(participant.status);
    final statusText = _getStatusText(participant.status);

    final isCurrentUser = _isCurrentUser(participant.userId);

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
                  backgroundColor: isCurrentUser
                      ? AppColors.primary
                      : statusColor.withValues(alpha: 0.2),
                  child: Text(
                    participant.name.isNotEmpty
                        ? participant.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : statusColor,
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
                              participant.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Vous',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (participant.email != null &&
                          participant.email!.isNotEmpty)
                        Text(
                          participant.email!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
                      PriceFormatter.format(participant.amount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (participant.status == GroupPaymentParticipantStatus.paid)
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
                        PriceFormatter.format(participant.paidAmount),
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
            if (participant.phone != null && participant.phone!.isNotEmpty) ...[
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
                    participant.phone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (participant.operator != null &&
                      participant.operator!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        participant.operator!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (participant.transactionId != null &&
                participant.transactionId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.receipt,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Transaction: ${participant.transactionId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
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

  bool _isCurrentUser(String? userId) {
    if (userId == null) return false;
    final appService = context.read<AppService>();
    final currentUser = appService.currentUser;
    return currentUser != null && currentUser.id == userId;
  }
}
