import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/payment_screen.dart';
import 'package:elcora_fast/screens/client/address_selector_screen.dart';
import 'package:elcora_fast/navigation/app_router.dart';

/// Écran de finalisation de commande
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPayment = PaymentMethod.mobileMoney;
  bool _isLoading = false;
  bool _isCalculatingDeliveryFee = false;
  Address? _selectedAddress;
  double? _estimatedDistance;
  int? _estimatedDeliveryTime;

  final AddressService _addressService = AddressService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
    _initializeDeliveryFeeService();
  }

  Future<void> _initializeDeliveryFeeService() async {
    try {
      await _deliveryFeeService.initialize();
    } catch (e) {
      debugPrint('Erreur initialisation DeliveryFeeService: $e');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAddress() async {
    try {
      // Initialiser le service si nécessaire
      if (!_addressService.isInitialized) {
        await _addressService.initialize();
      }

      // Charger l'adresse par défaut de l'utilisateur
      final defaultAddress = _addressService.defaultAddress;

      if (defaultAddress != null) {
        _selectedAddress = defaultAddress;
        _addressController.text = defaultAddress.fullAddress;
        // Calculer les frais de livraison automatiquement
        await _calculateDeliveryFeeForAddress(defaultAddress);
      } else if (_addressService.addresses.isNotEmpty) {
        final firstAddress = _addressService.addresses.first;
        _selectedAddress = firstAddress;
        _addressController.text = firstAddress.fullAddress;
        await _calculateDeliveryFeeForAddress(firstAddress);
      } else {
        _addressController.text = '';
      }
    } catch (e) {
      debugPrint('Erreur chargement adresse: $e');
      _addressController.text = '';
    }
  }

  Future<void> _calculateDeliveryFeeForAddress(Address? address) async {
    if (address == null) return;

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final cartService = context.read<CartService>();

      // Calculer les frais de livraison
      await cartService.calculateAndSetDeliveryFee(address: address);

      // Obtenir les informations supplémentaires (distance, temps)
      final deliveryInfo = await _deliveryFeeService.getDeliveryInfo(
        deliveryAddress: address.fullAddress,
        deliveryLatitude: address.latitude,
        deliveryLongitude: address.longitude,
      );

      setState(() {
        _estimatedDistance = deliveryInfo['distance'] as double?;
        _estimatedDeliveryTime = deliveryInfo['estimatedTime'] as int?;
      });
    } catch (e) {
      debugPrint('Erreur calcul frais livraison: $e');
    } finally {
      setState(() {
        _isCalculatingDeliveryFee = false;
      });
    }
  }

  Future<void> _selectAddress() async {
    final selected = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (context) => AddressSelectorScreen(
          currentAddress: _selectedAddress,
          onAddressSelected: (Address address) {
            Navigator.of(context).pop(address);
          },
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedAddress = selected;
        _addressController.text = selected.fullAddress;
      });
      await _calculateDeliveryFeeForAddress(selected);
    }
  }

  Future<void> _onAddressChanged(String addressText) async {
    if (addressText.trim().isEmpty) {
      setState(() {
        _selectedAddress = null;
        _estimatedDistance = null;
        _estimatedDeliveryTime = null;
      });
      // Réinitialiser les frais au prix par défaut
      final cartService = context.read<CartService>();
      cartService.setDeliveryFee(1000.0);
      return;
    }

    // Si l'adresse a changé manuellement, essayer de calculer les frais
    if (_selectedAddress == null ||
        _selectedAddress!.fullAddress != addressText) {
      try {
        final cartService = context.read<CartService>();
        await cartService.calculateAndSetDeliveryFee(
          deliveryAddress: addressText,
        );

        // Obtenir les informations supplémentaires
        final deliveryInfo = await _deliveryFeeService.getDeliveryInfo(
          deliveryAddress: addressText,
        );

        setState(() {
          _estimatedDistance = deliveryInfo['distance'] as double?;
          _estimatedDeliveryTime = deliveryInfo['estimatedTime'] as int?;
        });
      } catch (e) {
        debugPrint('Erreur calcul frais pour adresse texte: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Consumer<NotificationDatabaseService>(
            builder: (context, notificationService, child) {
              final unreadCount = notificationService.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        AppRouter.notifications,
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<AppService, CartService>(
        builder: (context, appService, cartService, child) {
          final cartItems = cartService.items;
          final cartTotal = cartService.total;

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderSummary(
                          context,
                          cartItems,
                          cartTotal,
                          cartService,
                        ),
                        const SizedBox(height: 24),
                        _buildDeliverySection(context),
                        const SizedBox(height: 24),
                        _buildPaymentSection(context),
                        const SizedBox(height: 24),
                        _buildNotesSection(context),
                      ],
                    ),
                  ),
                ),
                _buildCheckoutButton(context, appService, cartService),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Votre panier est vide',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Ajoutez des plats à votre panier avant de commander',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 30),
          CustomButton(text: 'Voir le menu', onPressed: () => context.goBack()),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    List<CartItem> cartItems,
    double cartTotal,
    CartService cartService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé de la commande',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...cartItems.map((item) => _buildOrderItem(context, item)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sous-total (${cartService.itemCount} article${cartService.itemCount > 1 ? 's' : ''})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  PriceFormatter.format(cartService.subtotal),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Livraison',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  PriceFormatter.format(cartService.deliveryFee),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (cartService.discount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remise${cartService.promoCode != null ? ' (${cartService.promoCode})' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                  ),
                  Text(
                    '-${PriceFormatter.format(cartService.discount)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ],
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
                  PriceFormatter.format(cartService.total),
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

  Widget _buildOrderItem(BuildContext context, CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 40,
              height: 40,
              color: Colors.grey[200],
              child: item.imageUrl?.isNotEmpty == true
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.fastfood,
                          color: Colors.grey[400],
                          size: 20,
                        );
                      },
                    )
                  : Icon(Icons.fastfood, color: Colors.grey[400], size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Quantité: ${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                Text(
                  PriceFormatter.format(item.totalPrice),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Adresse de livraison',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse complète',
                      hintText: 'Ex: 123 Rue de la Paix, 75001 Paris',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: _onAddressChanged,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez entrer ou sélectionner une adresse';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.location_on),
                  onPressed: _selectAddress,
                  tooltip: 'Sélectionner une adresse',
                ),
              ],
            ),
            if (_isCalculatingDeliveryFee) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                'Calcul des frais de livraison...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            if (_estimatedDistance != null && !_isCalculatingDeliveryFee) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.straighten,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Distance: ${_estimatedDistance!.toStringAsFixed(1)} km',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_estimatedDeliveryTime != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Temps estimé: $_estimatedDeliveryTime min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Méthode de paiement',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...PaymentMethod.values.map((method) {
              return RadioListTile<PaymentMethod>(
                title: Row(
                  children: [
                    Text(method.emoji),
                    const SizedBox(width: 8),
                    Text(method.displayName),
                  ],
                ),
                subtitle: Text(method.description),
                value: method,
                groupValue: _selectedPayment,
                onChanged: (value) {
                  setState(() {
                    _selectedPayment = value!;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Instructions spéciales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Instructions pour le livreur (optionnel)',
                hintText: 'Ex: Sonner à la porte, laisser devant la porte...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    AppService appService,
    CartService cartService,
  ) {
    final total = cartService.total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total à payer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  PriceFormatter.format(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isLoading ? 'Traitement...' : 'Confirmer la commande',
                onPressed: _isLoading
                    ? null
                    : () => _placeOrder(context, appService, cartService),
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    AppService appService,
    CartService cartService,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate order ID first
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Navigate to payment screen
      final paymentSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            orderId: orderId,
            amount: cartService.total,
            paymentMethod: _selectedPayment,
            customerName: appService.currentUser?.name ?? 'Client',
            customerEmail: appService.currentUser?.email ?? '',
            customerPhone: appService.currentUser?.phone ?? '',
          ),
        ),
      );

      if (paymentSuccess == true && mounted) {
        // S'assurer qu'on a une adresse valide
        Address? addressToUse = _selectedAddress;

        // Si aucune adresse sélectionnée mais qu'une adresse a été saisie manuellement,
        // créer une adresse temporaire avec les informations disponibles
        if (addressToUse == null && _addressController.text.trim().isNotEmpty) {
          // Essayer d'extraire la ville et le code postal depuis le texte
          final addressText = _addressController.text.trim();
          // Format attendu: "adresse, ville code_postal" ou similaire
          final parts = addressText.split(',').map((p) => p.trim()).toList();
          String city = '';
          String postalCode = '';

          if (parts.length > 1) {
            // Si on a plusieurs parties, la dernière devrait contenir ville et code postal
            final lastPart = parts.last;
            // Chercher un code postal (5 chiffres)
            final postalCodeMatch = RegExp(r'\b\d{5}\b').firstMatch(lastPart);
            if (postalCodeMatch != null) {
              postalCode = postalCodeMatch.group(0)!;
              city = lastPart.replaceAll(postalCode, '').trim();
            } else {
              city = lastPart;
            }
          }

          // Si on n'a toujours pas de ville ou code postal, utiliser des valeurs par défaut
          if (city.isEmpty) {
            city = 'Abidjan'; // Ville par défaut pour la Côte d'Ivoire
          }
          if (postalCode.isEmpty) {
            postalCode = '01'; // Code postal par défaut simplifié
          }

          addressToUse = Address(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
            userId: appService.currentUser?.id ?? '',
            name: 'Livraison',
            address: parts.isNotEmpty ? parts.first : addressText,
            city: city,
            postalCode: postalCode,
            type: AddressType.other,
            isDefault: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        // Process the order after successful payment
        final finalOrderId = await appService.placeOrderFromCartService(
          addressToUse,
          _selectedPayment,
          cartService.items,
          cartService.subtotal,
          cartService.deliveryFee,
          cartService.discount,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

        if (finalOrderId.isNotEmpty && mounted) {
          // Vider le panier après une commande réussie
          cartService.clear();

          // Naviguer vers l'écran de suivi de commande
          await context.navigateToDeliveryTracking(finalOrderId);

          // Afficher un message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commande #$finalOrderId passée avec succès! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (mounted) {
        // Payment was cancelled or failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement annulé'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la commande: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
