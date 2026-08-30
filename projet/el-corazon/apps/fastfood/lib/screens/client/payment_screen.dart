import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/presentation/etape_reglement.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';

/// Écran de paiement — Phase 6 : ouvre une demande de paiement Django
/// (`POST /payments/{order}/initiate/`) pour une commande **déjà créée**, et
/// n'affiche jamais un succès qu'elle n'aurait pas elle-même lu depuis le
/// serveur — seul un webhook signé du prestataire fait avancer une
/// transaction (`apps/payments/services.py`). La commande, elle, existe déjà
/// avant cet écran : le quitter sans paiement confirmé ne l'annule pas.
class PaymentScreen extends StatefulWidget {
  final String orderId;

  const PaymentScreen({required this.orderId, super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _pollInterval = Duration(seconds: 3);
  static const _pollTimeout = Duration(minutes: 2);

  final _paymentRepository = eccore.PaymentRepository(apiClient: apiClient);

  bool _isProcessing = true;
  EtapeReglement _etape = EtapeReglement.aucune;
  Order? _order;
  eccore.CheckoutInstruction? _checkout;
  String? _errorMessage;
  Timer? _pollTimer;
  DateTime? _pollDeadline;

  bool get _isCashOnDelivery => _order?.paymentMethod == PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    _pollTimer?.cancel();
    setState(() {
      _isProcessing = true;
      _etape = EtapeReglement.enAttente;
      _errorMessage = null;
    });

    try {
      final order = await DjangoOrderRepository().getOrderById(widget.orderId);
      if (order == null) {
        setState(() {
          _isProcessing = false;
          _etape = EtapeReglement.echouee;
          _errorMessage = 'Commande introuvable.';
        });
        return;
      }
      _order = order;

      final checkout = await _paymentRepository.initiate(widget.orderId);
      _checkout = checkout;

      if (order.paymentMethod == PaymentMethod.cash) {
        // Réglé physiquement à la livraison — la transaction est ouverte
        // (traçabilité comptable) mais rien à attendre ici.
        setState(() {
          _isProcessing = false;
          _etape = EtapeReglement.reglee;
        });
        return;
      }

      setState(() => _isProcessing = false);
      _pollDeadline = DateTime.now().add(_pollTimeout);
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTransaction());
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _etape = EtapeReglement.echouee;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pollTransaction() async {
    final checkout = _checkout;
    if (checkout == null) return;

    if (DateTime.now().isAfter(_pollDeadline!)) {
      _pollTimer?.cancel();
      return; // Reste en `pending` — l'utilisateur peut continuer manuellement.
    }

    try {
      final transactions = await _paymentRepository.getTransactions(orderId: widget.orderId);
      final match = transactions.where(
        (t) => t.providerReference == checkout.transaction.providerReference,
      );
      if (match.isEmpty) return;
      final current = match.first;

      if (current.isCompleted) {
        _pollTimer?.cancel();
        setState(() => _etape = EtapeReglement.reglee);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && context.mounted) Navigator.of(context).pop(true);
        });
      } else if (current.isFailed) {
        _pollTimer?.cancel();
        setState(() {
          _etape = EtapeReglement.echouee;
          _errorMessage = current.failureReason.isNotEmpty
              ? current.failureReason
              : 'Le paiement a échoué.';
        });
      }
    } catch (e) {
      eccore.Journal.trace('PaymentScreen: erreur pendant le sondage - $e');
    }
  }

  Future<void> _openCheckoutUrl() async {
    final url = _checkout?.checkoutUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir : $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Paiement sécurisé',
        // Le cadenas n'est pas décoratif : il est le seul signe visible que la
        // transaction ne se règle pas dans cette page mais chez le
        // prestataire, et il tient la place de l'action symétrique du retour.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: DesignConstants.spacingS),
            child: Icon(
              Icons.lock_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingL,
          DesignConstants.edgeMargin,
          DesignConstants.spacingL,
        ),
        children: [
          _montantDu(theme),
          const SizedBox(height: DesignConstants.spacingXL),
          _moyenRetenu(theme),
          const SizedBox(height: DesignConstants.spacingL),
          _buildPaymentStatus(),
        ],
      ),
      bottomNavigationBar: GlassBottomBar(child: _buildActionButtons()),
    );
  }

  /// Le montant, en grand, et la référence de commande sous lui.
  ///
  /// La devise est composée en `headline-md` et alignée en haut du nombre :
  /// c'est ce que fait la maquette, et cela évite qu'un « CFA » à la même
  /// taille que le montant ne prenne autant de place que lui.
  Widget _montantDu(ThemeData theme) {
    final montant = _order?.total ?? 0;
    final reference = widget.orderId.length >= 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

    return Column(
      children: [
        Text(
          'Montant à régler',
          style: AppTypography.bodyMd(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignConstants.spacingS),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            PriceFormatter.format(montant),
            maxLines: 1,
            style: AppTypography.displayLg(color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        StatusChip(label: 'COMMANDE $reference', icon: Icons.receipt_long_rounded),
      ],
    );
  }

  /// Le moyen de paiement retenu à la commande.
  ///
  /// Il n'est pas modifiable ici, et c'est volontaire : la transaction est
  /// déjà ouverte côté serveur pour ce moyen-là. En changer suppose de
  /// revenir au règlement, ce que le bouton de retour permet.
  Widget _moyenRetenu(ThemeData theme) {
    final order = _order;
    if (order == null) return const SizedBox.shrink();

    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: DesignConstants.borderRadiusMedium,
            ),
            child: Text(
              order.paymentMethod.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.paymentMethod.displayName,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  order.paymentMethod.description,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Encart d'attention — instructions du prestataire, échec, confirmation.
  ///
  /// Un seul composant pour les trois, parce qu'ils occupent la même place et
  /// disent la même chose sous des couleurs différentes : voilà où en est le
  /// paiement. Les faire diverger ferait sauter la mise en page à chaque
  /// changement d'état.
  Widget _encart({
    required IconData icone,
    required String titre,
    required Color fond,
    required Color teinte,
    String? texte,
    Widget? complement,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingM),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: DesignConstants.borderRadiusLarge,
        border: Border.all(color: teinte.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: teinte, shape: BoxShape.circle),
            child: Icon(icone, size: 18, color: theme.colorScheme.surface),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titre,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (texte != null && texte.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    texte,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (complement != null) ...[
                  const SizedBox(height: DesignConstants.spacingS),
                  complement,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    final theme = Theme.of(context);

    if (_isProcessing) {
      return _encart(
        icone: Icons.hourglass_top_rounded,
        titre: 'Ouverture du paiement…',
        texte: 'Nous préparons votre transaction.',
        fond: theme.colorScheme.surfaceContainerLow,
        teinte: theme.colorScheme.outline,
      );
    }

    if (_isCashOnDelivery && _etape == EtapeReglement.reglee) {
      return _encart(
        icone: Icons.payments_rounded,
        titre: 'À régler à la livraison',
        texte: 'Préparez l’appoint : le livreur encaissera à la remise.',
        fond: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        teinte: theme.colorScheme.secondary,
      );
    }

    switch (_etape) {
      case EtapeReglement.reglee:
        return _encart(
          icone: Icons.check_rounded,
          titre: 'Paiement confirmé',
          texte: 'Votre commande est en préparation.',
          fond: AppColors.success.withValues(alpha: 0.1),
          teinte: AppColors.success,
        );

      case EtapeReglement.echouee:
        return _encart(
          icone: Icons.priority_high_rounded,
          titre: 'Paiement non abouti',
          texte: _errorMessage,
          fond: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          teinte: theme.colorScheme.error,
        );

      case EtapeReglement.enAttente:
        final checkout = _checkout;
        final tropLong =
            _pollDeadline != null && DateTime.now().isAfter(_pollDeadline!);

        return _encart(
          icone: Icons.notifications_active_rounded,
          titre: tropLong
              ? 'Toujours en attente'
              : 'Confirmez sur votre téléphone',
          texte: checkout != null && checkout.instructions.isNotEmpty
              ? checkout.instructions
              : 'Validez la demande reçue de votre opérateur pour finaliser.',
          fond: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
          teinte: theme.colorScheme.secondary,
          complement: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tropLong)
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: DesignConstants.spacingS),
                    Text(
                      'Vérification en cours…',
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (checkout != null)
                TextButton.icon(
                  onPressed: _openCheckoutUrl,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir la page de paiement'),
                ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    final regle = _etape == EtapeReglement.reglee;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_etape == EtapeReglement.echouee) ...[
          ActionButton(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: _initializePayment,
          ),
          const SizedBox(height: DesignConstants.spacingS + 4),
        ],
        ActionButton(
          label: regle ? 'Continuer' : 'Continuer vers le suivi',
          emphasis: regle ? ActionEmphasis.gradient : ActionEmphasis.outlined,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.of(context).pop(regle),
        ),
      ],
    );
  }
}
