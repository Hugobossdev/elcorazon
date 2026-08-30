import 'dart:async';
import 'package:flutter/material.dart';
import 'package:elcora_fast/presentation/paiement_partage.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
// `ErrorWidget` existe aussi dans Flutter — c'est le carré rouge des
// exceptions de rendu. Le préfixe lève l'ambiguïté sans renommer le nôtre,
// que d'autres écrans importent déjà sans conflit.
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Paiement partagé',
        actions: [
          GlassIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            filled: false,
            onPressed: _loadSession,
          ),
        ],
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return etats.ErrorWidget(message: _loadError!, onRetry: _loadSession);
    }

    if (_session == null) {
      return const etats.EmptyStateWidget(
        title: 'Aucun partage en cours',
        message: 'Cette commande n’a pas de paiement partagé ouvert.',
        icon: Icons.groups_outlined,
      );
    }

    return _buildContent();
  }

  Widget _buildContent() {
    final session = _session!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        DesignConstants.spacingL,
        DesignConstants.edgeMargin,
        DesignConstants.spacingL,
      ),
      children: [
        _synthese(session),
        const SizedBox(height: DesignConstants.spacingL),
        SectionHeader(
          title: 'Participants',
          subtitle: '${session.shares.length} part'
              '${session.shares.length > 1 ? 's' : ''} au total',
        ),
        const SizedBox(height: DesignConstants.spacingM),
        for (final part in session.shares) _buildParticipantCard(part),
      ],
    );
  }

  /// Anneau de progression, et les trois montants qui comptent.
  ///
  /// L'anneau dit d'un coup d'œil **où en est la collecte** — c'est ce que la
  /// maquette place en tête, et c'est la seule question qu'on se pose en
  /// ouvrant cet écran. La barre horizontale qu'il remplace disait la même
  /// chose, mais noyée sous trois colonnes de chiffres qui la précédaient.
  Widget _synthese(eccore.SplitPayment session) {
    final theme = Theme.of(context);

    final total = session.totalAmount.toMajorUnits();
    final paye = session.paidAmount.toMajorUnits();
    final restant = total - paye;

    final soldees = session.shares.where((p) => p.isPaid).length;
    final parts = session.shares.length;

    final avancement = session.totalAmount.amountMinor > 0
        ? session.paidAmount.amountMinor / session.totalAmount.amountMinor
        : 0.0;

    return SectionCard(
      padding: const EdgeInsets.all(DesignConstants.spacingL),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: avancement.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$soldees/$parts',
                      style: AppTypography.headlineMd(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'réglées',
                      style: AppTypography.labelLg(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          Row(
            children: [
              Expanded(
                child: _montant(
                  'Total',
                  PriceFormatter.format(total),
                  theme.colorScheme.onSurface,
                ),
              ),
              Expanded(
                child: _montant(
                  'Réglé',
                  PriceFormatter.format(paye),
                  AppColors.success,
                ),
              ),
              Expanded(
                child: _montant(
                  'Restant',
                  PriceFormatter.format(restant),
                  restant > 0
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _montant(String libelle, String valeur, Color couleur) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          libelle,
          style: AppTypography.labelLg(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valeur,
            maxLines: 1,
            style: AppTypography.titleLg(color: couleur),
          ),
        ),
      ],
    );
  }

  /// Une part : qui, combien, où elle en est.
  ///
  /// La version précédente affichait deux fois le même montant sur les parts
  /// réglées — « Montant à payer » à gauche, « Payé » à droite, la même
  /// somme — alors qu'une part est soldée en entier ou pas du tout. La
  /// duplication ne disait rien que la puce d'état ne dise déjà.
  Widget _buildParticipantCard(eccore.SplitShare participant) {
    final theme = Theme.of(context);
    final etat = EtatPart.depuisServeur(participant.status);
    final initiale = participant.displayName.isNotEmpty
        ? participant.displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      child: SectionCard(
        // Un liseré sur ce qui reste dû : c'est là-dessus qu'il faut relancer,
        // et la maquette souligne de la même façon les parts en attente.
        borderColor: participant.isPaid
            ? null
            : theme.colorScheme.tertiary.withValues(alpha: 0.4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: etat.couleur.withValues(alpha: 0.15),
              child: Text(
                initiale,
                style: AppTypography.titleLg(color: etat.couleur),
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
                    PriceFormatter.format(participant.amount.toMajorUnits()),
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (participant.phone.isNotEmpty)
                    Text(
                      participant.phone,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: DesignConstants.spacingS),
            StatusChip(
              label: etat.libelle,
              icon: etat.icone,
              background: etat.couleur.withValues(alpha: 0.12),
              foreground: etat.couleur,
            ),
          ],
        ),
      ),
    );
  }
}
