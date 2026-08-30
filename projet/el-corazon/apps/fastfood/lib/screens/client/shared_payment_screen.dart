import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
// `ErrorWidget` existe aussi dans Flutter — c'est le carré rouge des
// exceptions de rendu. Le préfixe lève l'ambiguïté.
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/presentation/paiement_partage.dart';

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
  final List<ConviveDuPartage> participants;

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Partager l’addition',
        actions: [
          GlassIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            filled: false,
            onPressed: _isLoading ? () {} : _loadSession,
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
      return etats.ErrorWidget(
        message: _loadError ?? 'Partage indisponible',
        onRetry: _loadSession,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        DesignConstants.spacingL,
        DesignConstants.edgeMargin,
        DesignConstants.spacingL,
      ),
      children: [
        _buildSummary(session),
        const SizedBox(height: DesignConstants.spacingL),
        const SectionHeader(
          title: 'Les parts',
          subtitle: 'Chacun règle la sienne, de son côté',
        ),
        const SizedBox(height: DesignConstants.spacingM),
        for (final part in session.shares) _buildParticipantCard(part),
      ],
    );
  }

  /// Le total, ce qui est réglé, ce qui reste — et une barre pour le voir.
  ///
  /// La maquette pose ce bloc en verre teinté au-dessus de tout le reste. Le
  /// bandeau rose pâle qu'il remplace empilait trois phrases dont deux
  /// contenaient chacune deux montants séparés par une puce : il fallait les
  /// lire pour comprendre où en était la collecte, alors que c'est la
  /// première chose qu'on veut savoir.
  Widget _buildSummary(eccore.SplitPayment session) {
    final total = session.totalAmount.toMajorUnits();
    final regle = session.paidAmount.toMajorUnits();
    final reste = total - regle;
    final reglees = session.shares.where((p) => p.isPaid).length;

    final avancement = session.totalAmount.amountMinor > 0
        ? session.paidAmount.amountMinor / session.totalAmount.amountMinor
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.actionGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignConstants.borderRadiusLarge,
        boxShadow: DesignConstants.shadowLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total de l’addition',
            style: AppTypography.bodyMd(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              PriceFormatter.format(total),
              maxLines: 1,
              style: AppTypography.displayLg(color: Colors.white),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: avancement.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: _chiffre(
                  'Déjà réglé',
                  PriceFormatter.format(regle),
                ),
              ),
              Expanded(
                child: _chiffre('Reste dû', PriceFormatter.format(reste)),
              ),
              Expanded(
                child: _chiffre(
                  'Parts',
                  '$reglees/${session.shares.length}',
                ),
              ),
            ],
          ),
          if (reste <= 0) ...[
            const SizedBox(height: DesignConstants.spacingM),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: DesignConstants.spacingS),
                Expanded(
                  child: Text(
                    'L’addition est entièrement réglée.',
                    style: AppTypography.bodyMd(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chiffre(String libelle, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          libelle,
          style: AppTypography.labelLg(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valeur,
            maxLines: 1,
            style: AppTypography.titleLg(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Une part : qui, combien, et les deux gestes possibles.
  ///
  /// « Copier le lien » et « Payer » ne s'affichent que sur une part non
  /// réglée — payer deux fois la même part n'a pas de sens, et le serveur le
  /// refuserait de toute façon.
  Widget _buildParticipantCard(eccore.SplitShare participant) {
    final theme = Theme.of(context);
    final regle = participant.isPaid;
    final teinte = regle ? AppColors.success : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: teinte.withValues(alpha: 0.15),
                  child: Icon(
                    regle ? Icons.check_rounded : Icons.person_rounded,
                    color: teinte,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DesignConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        participant.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        PriceFormatter.format(
                          participant.amount.toMajorUnits(),
                        ),
                        style: AppTypography.priceDisplay(
                          color: theme.colorScheme.primary,
                        ).copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DesignConstants.spacingS),
                StatusChip(
                  label: regle ? 'Réglée' : 'En attente',
                  icon: regle
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  background: teinte.withValues(alpha: 0.12),
                  foreground: teinte,
                ),
              ],
            ),
            if (!regle) ...[
              const SizedBox(height: DesignConstants.spacingM),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Copier le lien',
                      icon: Icons.link_rounded,
                      emphasis: ActionEmphasis.outlined,
                      height: 44,
                      onPressed: () => _copyShareLink(participant),
                    ),
                  ),
                  const SizedBox(width: DesignConstants.spacingS + 4),
                  Expanded(
                    child: ActionButton(
                      label: 'Payer',
                      icon: Icons.payment_rounded,
                      height: 44,
                      onPressed: _isProcessing
                          ? null
                          : () => _payShare(participant),
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
