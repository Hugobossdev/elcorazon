import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/presentation/etape_reglement.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPaymentIcon(),
                    const SizedBox(height: 24),
                    _buildPaymentInfo(),
                    const SizedBox(height: 32),
                    _buildPaymentStatus(),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentIcon() {
    IconData iconData;
    Color iconColor;

    switch (_etape) {
      case EtapeReglement.reglee:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case EtapeReglement.echouee:
        iconData = Icons.error;
        iconColor = Colors.red;
        break;
      case EtapeReglement.enAttente:
        iconData = Icons.payment;
        iconColor = Theme.of(context).colorScheme.primary;
        break;
      default:
        iconData = Icons.payment;
        iconColor = Colors.grey;
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 50, color: iconColor),
    );
  }

  Widget _buildPaymentInfo() {
    final order = _order;
    return Column(
      children: [
        Text(
          'Commande #${widget.orderId.substring(0, 8).toUpperCase()}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Montant à payer',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          PriceFormatter.format(order?.total ?? 0),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        if (order != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(order.paymentMethod.emoji),
              const SizedBox(width: 8),
              Text(order.paymentMethod.displayName, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentStatus() {
    if (_isProcessing) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Ouverture du paiement...', style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
    }

    if (_isCashOnDelivery && _etape == EtapeReglement.reglee) {
      return Text(
        'À régler à la livraison 💵',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.center,
      );
    }

    switch (_etape) {
      case EtapeReglement.reglee:
        return Text(
          'Paiement effectué avec succès ! 🎉',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        );
      case EtapeReglement.echouee:
        return Column(
          children: [
            Text(
              'Erreur de paiement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      case EtapeReglement.enAttente:
        final checkout = _checkout;
        final waitingTooLong = _pollDeadline != null && DateTime.now().isAfter(_pollDeadline!);
        return Column(
          children: [
            if (!waitingTooLong) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(
              waitingTooLong
                  ? 'Toujours en attente de confirmation.'
                  : 'En attente de confirmation du paiement...',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (checkout != null && checkout.instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                checkout.instructions,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            if (checkout != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _openCheckoutUrl,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir la page de paiement'),
              ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_etape == EtapeReglement.echouee) ...[
          SizedBox(
            width: double.infinity,
            child: CustomButton(text: 'Réessayer', onPressed: _initializePayment),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: _etape == EtapeReglement.reglee ? 'Continuer' : 'Continuer vers le suivi',
            onPressed: () => Navigator.of(context).pop(_etape == EtapeReglement.reglee),
          ),
        ),
      ],
    );
  }
}
