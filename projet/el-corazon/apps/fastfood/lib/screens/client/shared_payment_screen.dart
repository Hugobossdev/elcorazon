import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/models/payment_participant.dart';

/// Paiement partagé d'une commande — `/payments/{order}/split/` (Phase 6).
///
/// La réécriture change la nature de l'écran, parce qu'elle change celle du
/// paiement. L'implémentation Supabase encaissait **depuis l'app** : elle
/// appelait PayDunya pour chaque convive avec le numéro et l'opérateur saisis
/// par l'organisateur, puis écrivait elle-même « payé » dans la table des
/// participants. Un client qui mentait à cette écriture soldait une part que
/// personne n'avait réglée.
///
/// Ici, l'app n'encaisse plus et ne solde plus rien :
/// * elle ouvre le partage — le serveur répartit le total, sans perdre d'unité
///   mineure ;
/// * chaque part porte un **lien** ; le convive le suit et paie chez le
///   prestataire, avec ou sans compte ;
/// * une part passe à « réglée » quand le webhook signé du prestataire l'a dit,
///   jamais sur la foi de l'écran.
///
/// D'où la disparition des champs téléphone et opérateur : ils appartiennent à
/// la page de paiement du prestataire, qui les collecte auprès du payeur — et
/// non à l'organisateur, qui les saisissait pour les autres.
class SharedPaymentScreen extends StatefulWidget {
  final String groupId;
  final String orderId;
  final double totalAmount;
  final List<PaymentParticipant> participants;

  const SharedPaymentScreen({
    required this.groupId,
    required this.orderId,
    required this.totalAmount,
    required this.participants,
    super.key,
  });

  @override
  State<SharedPaymentScreen> createState() => _SharedPaymentScreenState();
}

class _SharedPaymentScreenState extends State<SharedPaymentScreen> {
  final eccore.PaymentRepository _payments =
      eccore.PaymentRepository(apiClient: apiClient);

  eccore.SplitPayment? _session;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  /// Récupère le partage de la commande, ou l'ouvre s'il n'existe pas encore.
  ///
  /// Aucun montant n'est envoyé par convive : omis pour tout le monde, le
  /// serveur répartit le total à parts égales sans laisser un franc orphelin —
  /// ce qu'une division faite ici produirait à chaque partage impair.
  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      eccore.SplitPayment split;
      try {
        split = await _payments.getSplit(widget.orderId);
      } on eccore.ApiException catch (e) {
        if (e.status != 404) rethrow;
        split = await _payments.createSplit(
          orderId: widget.orderId,
          participants: widget.participants
              .map(
                (participant) => eccore.SplitParticipantInput(
                  displayName: participant.name,
                  userId: participant.userId.isEmpty ? null : participant.userId,
                  phone: participant.phoneNumber,
                ),
              )
              .toList(),
        );
      }

      if (!mounted) return;
      setState(() {
        _session = split;
        _isLoading = false;
      });
    } on eccore.ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.detail;
      });
    }
  }

  /// Ouvre le règlement d'une part et suit le lien du prestataire.
  ///
  /// Ne solde rien : au retour, la part reste « en attente » tant que le webhook
  /// n'a pas confirmé. L'écran se contente de relire l'état.
  Future<void> _payShare(eccore.SplitShare participant) async {
    if (participant.shareToken.isEmpty) {
      _showError("Cette part n'a pas de lien de paiement");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final checkout = await _payments.payShare(participant.shareToken);

      if (checkout.checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(checkout.checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (checkout.instructions.isNotEmpty && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Régler la part de ${participant.displayName}'),
            content: Text(checkout.instructions),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }

      await _loadSession();
    } on eccore.ApiException catch (e) {
      _showError(e.detail);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Copie le jeton d'une part — c'est ainsi qu'un convive **sans compte** règle
  /// la sienne : le lien lui suffit, et ne donne accès qu'à cette part, ni à la
  /// commande ni aux autres participants.
  void _copyShareLink(eccore.SplitShare participant) {
    if (participant.shareToken.isEmpty) return;

    Clipboard.setData(ClipboardData(text: participant.shareToken));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lien de paiement de ${participant.displayName} copié'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement partagé'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSession,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final session = _session;
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _loadError ?? 'Partage indisponible',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSession,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummary(session),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: session.shares.length,
            itemBuilder: (context, index) =>
                _buildParticipantCard(session.shares[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(eccore.SplitPayment session) {
    final reste =
        session.totalAmount.toMajorUnits() - session.paidAmount.toMajorUnits();
    final reglees = session.shares
        .where((p) => p.isPaid)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total : ${PriceFormatter.format(session.totalAmount.toMajorUnits())}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Déjà réglé : ${PriceFormatter.format(session.paidAmount.toMajorUnits())} • '
            'Reste : ${PriceFormatter.format(reste)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$reglees part(s) réglée(s) sur ${session.shares.length}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(eccore.SplitShare participant) {
    final paid = participant.isPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: paid ? AppColors.success : AppColors.primary,
                  child: Icon(
                    paid ? Icons.check : Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        PriceFormatter.format(participant.amount.toMajorUnits()),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(paid ? 'Réglée' : 'En attente'),
                  backgroundColor:
                      (paid ? AppColors.success : AppColors.primary)
                          .withValues(alpha: 0.12),
                ),
              ],
            ),
            if (!paid) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyShareLink(participant),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Copier le lien'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isProcessing ? null : () => _payShare(participant),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Payer'),
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
