import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/paydunya_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/order.dart';
import '../delivery/driver_profile_screen.dart';
import '../delivery/settings_screen.dart';

class DriverPaymentScreen extends StatefulWidget {
  final Order order;
  final double amount;

  const DriverPaymentScreen({
    super.key,
    required this.order,
    required this.amount,
  });

  @override
  State<DriverPaymentScreen> createState() => _DriverPaymentScreenState();
}

class _DriverPaymentScreenState extends State<DriverPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();

  String _selectedPaymentMethod = 'mobile_money';
  String _selectedOperator = 'mtn';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      final payDunyaService =
          Provider.of<PayDunyaService>(context, listen: false);
      if (!payDunyaService.isInitialized) {
        await payDunyaService.initialize(
          masterKey: 'test_master_key',
          privateKey: 'test_private_key',
          token: 'test_token',
          isSandbox: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Provider.of<ErrorHandlerService>(context, listen: false)
            .logError('Erreur initialisation paiement', details: e);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderSummary(),
              const SizedBox(height: 24),
              _buildPaymentMethodSelector(),
              const SizedBox(height: 24),
              if (_selectedPaymentMethod == 'mobile_money')
                _buildMobileMoneyForm()
              else
                _buildCardForm(),
              const SizedBox(height: 24),
              _buildPaymentButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé de la commande',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Commande #${widget.order.id.substring(0, 8).toUpperCase()}'),
                Text(
                  '${widget.amount.toStringAsFixed(2)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Frais de livraison'),
                Text('0.00 FCFA'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${widget.amount.toStringAsFixed(2)} FCFA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthode de paiement',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Mobile Money'),
                subtitle: const Text('MTN, Orange, Moov'),
                value: 'mobile_money',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Carte bancaire'),
                subtitle: const Text('Visa, Mastercard'),
                value: 'card',
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileMoneyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations Mobile Money',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedOperator,
          decoration: const InputDecoration(
            labelText: 'Opérateur',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
            DropdownMenuItem(value: 'orange', child: Text('Orange Money')),
            DropdownMenuItem(value: 'moov', child: Text('Moov Money')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedOperator = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '+225 XX XX XX XX',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre numéro';
            }
            if (value.length < 10) {
              return 'Numéro invalide';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations de la carte',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cardNumberController,
          decoration: const InputDecoration(
            labelText: 'Numéro de carte',
            hintText: '1234 5678 9012 3456',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.credit_card),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le numéro de carte';
            }
            if (value.replaceAll(' ', '').length < 16) {
              return 'Numéro de carte invalide';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cardHolderController,
          decoration: const InputDecoration(
            labelText: 'Nom du titulaire',
            hintText: 'Jean Dupont',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le nom du titulaire';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryMonthController,
                decoration: const InputDecoration(
                  labelText: 'Mois',
                  hintText: 'MM',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mois requis';
                  }
                  final month = int.tryParse(value);
                  if (month == null || month < 1 || month > 12) {
                    return 'Mois invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _expiryYearController,
                decoration: const InputDecoration(
                  labelText: 'Année',
                  hintText: 'YYYY',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Année requise';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < DateTime.now().year) {
                    return 'Année invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'CVV requis';
                  }
                  if (value.length < 3) {
                    return 'CVV invalide';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Traitement en cours...'),
                ],
              )
            : Text(
                'Payer ${widget.amount.toStringAsFixed(2)} FCFA',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      Provider.of<PerformanceService>(context, listen: false)
          .startTimer('process_payment');

      final payDunyaService =
          Provider.of<PayDunyaService>(context, listen: false);
      final errorHandler =
          Provider.of<ErrorHandlerService>(context, listen: false);

      if (_selectedPaymentMethod == 'mobile_money') {
        await _processMobileMoneyPayment(payDunyaService, errorHandler);
      } else {
        await _processCardPayment(payDunyaService, errorHandler);
      }

      Provider.of<PerformanceService>(context, listen: false)
          .stopTimer('process_payment');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement effectué avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur paiement', details: e);

      if (mounted) {
        Provider.of<ErrorHandlerService>(context, listen: false)
            .showErrorSnackBar(
                context, 'Erreur lors du paiement: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processMobileMoneyPayment(
      PayDunyaService payDunyaService, ErrorHandlerService errorHandler) async {
    final result = await payDunyaService.processMobileMoneyPayment(
      orderId: widget.order.id,
      amount: widget.amount,
      phoneNumber: _phoneController.text,
      operator: _selectedOperator,
      customerName: 'Livreur ${widget.order.id.substring(0, 8)}',
      customerEmail: 'driver@fasteat.ci',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Erreur paiement mobile money');
    }
  }

  Future<void> _processCardPayment(
      PayDunyaService payDunyaService, ErrorHandlerService errorHandler) async {
    final result = await payDunyaService.processCardPayment(
      orderId: widget.order.id,
      amount: widget.amount,
      cardNumber: _cardNumberController.text,
      cardHolderName: _cardHolderController.text,
      expiryMonth: _expiryMonthController.text,
      expiryYear: _expiryYearController.text,
      cvv: _cvvController.text,
      customerName: 'Livreur ${widget.order.id.substring(0, 8)}',
      customerEmail: 'driver@fasteat.ci',
    );

    if (!result.success) {
      throw Exception(result.error ?? 'Erreur paiement carte');
    }
  }
}
