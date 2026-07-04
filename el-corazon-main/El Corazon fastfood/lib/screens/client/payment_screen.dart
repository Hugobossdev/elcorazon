import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
// import 'package:elcora_fast/services/wallet_service.dart'; // Portefeuille désactivé temporairement
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/config/paydunya_config.dart';

/// Écran de traitement des paiements
class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String customerName;
  final String customerEmail;
  final String customerPhone;

  const PaymentScreen({
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    super.key,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  PaymentStatus _paymentStatus = PaymentStatus.none;
  String? _transactionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    setState(() {
      _isProcessing = true;
      _paymentStatus = PaymentStatus.pending;
    });

    try {
      final payDunyaService =
          Provider.of<PayDunyaService>(context, listen: false);

      // Initialize PayDunya if not already done
      if (!payDunyaService.isInitialized) {
        await payDunyaService.initialize(
          masterKey: PayDunyaConfig.masterKey,
          privateKey: PayDunyaConfig.privateKey,
          token: PayDunyaConfig.token,
        );
      }

      PaymentResult result;

      switch (widget.paymentMethod) {
        case PaymentMethod.mobileMoney:
          // Déterminer l'opérateur mobile money basé sur le numéro de téléphone
          final operator = _detectMobileMoneyOperator(widget.customerPhone);
          result = await payDunyaService.processMobileMoneyPayment(
            orderId: widget.orderId,
            amount: widget.amount,
            phoneNumber: widget.customerPhone,
            operator: operator,
            customerName: widget.customerName,
            customerEmail: widget.customerEmail,
          );
          break;
        case PaymentMethod.creditCard:
        case PaymentMethod.debitCard:
          result = await payDunyaService.processCardPayment(
            orderId: widget.orderId,
            amount: widget.amount,
            cardNumber: '4111111111111111', // Test card number
            cardHolderName: widget.customerName,
            expiryMonth: '12',
            expiryYear: '2025',
            cvv: '123',
            customerName: widget.customerName,
            customerEmail: widget.customerEmail,
          );
          break;
        case PaymentMethod.wallet:
          // Portefeuille électronique désactivé temporairement
          result = PaymentResult(
            success: false,
            orderId: widget.orderId,
            error: 'Le portefeuille électronique est temporairement indisponible',
          );
          break;
        case PaymentMethod.cash:
          // Cash payment - simulate success
          await Future.delayed(const Duration(seconds: 2));
          result = PaymentResult(
            success: true,
            orderId: widget.orderId,
            invoiceToken: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
          );
          break;
      }

      setState(() {
        _isProcessing = false;
        _paymentStatus =
            result.success ? PaymentStatus.completed : PaymentStatus.error;
        _transactionId = result.invoiceToken;
        _errorMessage = result.error;
      });

      if (result.success) {
        // Navigate back to order tracking after successful payment
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && context.mounted) {
            Navigator.of(context).pop(true); // Return success
          }
        });
      } else {
        // Afficher un message d'erreur si le paiement a échoué
        if (mounted && context.mounted && result.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Échec du paiement: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _paymentStatus = PaymentStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  /// Détecte l'opérateur mobile money basé sur le numéro de téléphone
  String _detectMobileMoneyOperator(String phoneNumber) {
    // Enlever les espaces et caractères spéciaux
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Détection basée sur les préfixes courants en Côte d'Ivoire
    if (cleaned.startsWith('07') || cleaned.startsWith('05')) {
      return 'mtn'; // MTN Mobile Money
    } else if (cleaned.startsWith('09') || cleaned.startsWith('01')) {
      return 'orange'; // Orange Money
    } else if (cleaned.startsWith('01') || cleaned.startsWith('05')) {
      return 'moov'; // Moov Money
    }

    // Par défaut, utiliser MTN
    return 'mtn';
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
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentIcon() {
    IconData iconData;
    Color iconColor;

    switch (_paymentStatus) {
      case PaymentStatus.completed:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case PaymentStatus.error:
        iconData = Icons.error;
        iconColor = Colors.red;
        break;
      case PaymentStatus.pending:
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
      child: Icon(
        iconData,
        size: 50,
        color: iconColor,
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Column(
      children: [
        Text(
          'Commande #${widget.orderId.substring(0, 8).toUpperCase()}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Montant à payer',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          PriceFormatter.format(widget.amount),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.paymentMethod.emoji),
            const SizedBox(width: 8),
            Text(
              widget.paymentMethod.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentStatus() {
    if (_isProcessing) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Traitement du paiement...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      );
    }

    switch (_paymentStatus) {
      case PaymentStatus.completed:
        return Column(
          children: [
            Text(
              'Paiement effectué avec succès! 🎉',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            if (_transactionId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Transaction: $_transactionId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        );
      case PaymentStatus.error:
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red[700],
                    ),
                textAlign: TextAlign.center,
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
        if (_paymentStatus == PaymentStatus.error) ...[
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Réessayer',
              onPressed: _initializePayment,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: _paymentStatus == PaymentStatus.completed
                ? 'Continuer'
                : 'Annuler',
            onPressed: () => Navigator.of(context)
                .pop(_paymentStatus == PaymentStatus.completed),
          ),
        ),
      ],
    );
  }
}
