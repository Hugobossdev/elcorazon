import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/presentation/adresse.dart';
import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/auth_style_card.dart';
import 'package:elcora_fast/widgets/auth_style_text_field.dart';
import 'package:elcora_fast/widgets/auth_style_button.dart';
import 'package:elcora_fast/widgets/delivery_fee_breakdown_card.dart';
import 'package:elcora_fast/widgets/zone_not_serviceable_dialog.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/payment_screen.dart';
import 'package:elcora_fast/screens/client/address_selector_screen.dart';

/// Écran de finalisation de commande
class CheckoutScreen extends StatefulWidget {
  final String? existingOrderId;
  final List<CartItem>? preloadedItems;
  final double? preloadedTotal;

  const CheckoutScreen({
    super.key,
    this.existingOrderId,
    this.preloadedItems,
    this.preloadedTotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPayment = PaymentMethod
      .cash; // Par défaut: cash (mobile money, credit card et debit card désactivés)
  bool _isLoading = false;
  bool _isCalculatingDeliveryFee = false;
  eccore.Address? _selectedAddress;
  // La distance et le délai estimé ne sont plus recopiés ici : ils vivent sur
  // `_deliveryBreakdown`, d'où l'écran les lit déjà.
  DeliveryFeeBreakdown? _deliveryBreakdown;

  final AddressService _addressService = AddressService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
    // S'assurer que le wallet n'est pas sélectionné (fonctionnalité désactivée)
    if (_selectedPayment == PaymentMethod.wallet) {
      _selectedPayment = PaymentMethod.cash;
    }
    // S'assurer que mobile money, credit card et debit card ne sont pas sélectionnés (désactivés)
    if (_selectedPayment == PaymentMethod.mobileMoney ||
        _selectedPayment == PaymentMethod.creditCard ||
        _selectedPayment == PaymentMethod.debitCard) {
      _selectedPayment = PaymentMethod.cash;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Pré-remplit l'adresse de livraison.
  ///
  /// Le carnet est ouvert par la session (`AppService`), pas par cet écran :
  /// il appelait `initialize()`, qui ne lisait que le cache local et ne
  /// contactait jamais le serveur. On reprend le choix déjà mémorisé — celui
  /// que le client a fait à sa commande précédente — avant de retomber sur
  /// l'adresse par défaut.
  Future<void> _loadUserAddress() async {
    try {
      final address = _addressService.selectedAddress ??
          _addressService.defaultAddress ??
          _addressService.addresses.firstOrNull;

      if (address == null) {
        _addressController.text = '';
        return;
      }

      _selectedAddress = address;
      _addressController.text = address.uneLigne;
      await _calculateDeliveryFeeForAddress(address);
    } catch (e) {
      eccore.Journal.trace('Erreur chargement adresse: $e');
      _addressController.text = '';
    }
  }

  /// Demande au serveur le chiffrage de la commande pour cette adresse.
  ///
  /// L'écran calculait auparavant lui-même les frais, puis les poussait dans
  /// le panier. Il les **lit** désormais : `CartService.refreshQuote` appelle
  /// `POST /orders/preview/`, qui emprunte le chemin de calcul de la création
  /// de commande. Ce qui s'affiche ici est donc, au centime près, ce qui sera
  /// facturé.
  Future<void> _calculateDeliveryFeeForAddress(eccore.Address? address) async {
    if (address == null) return;

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final cartService = context.read<CartService>();
      await cartService.refreshQuote(address: address);

      final breakdown = await _deliveryFeeService.breakdownForAddress(
        address: address,
        promoCode: cartService.promoCode ?? '',
      );

      if (mounted) {
        setState(() {
          _deliveryBreakdown = breakdown;
        });

        if (!breakdown.isInServiceableZone && mounted) {
          await ZoneNotServiceableDialog.show(
            context,
            onChooseAnotherAddress: _selectAddress,
          );
        }
      }
    } catch (e) {
      // Le serveur a refusé de chiffrer — adresse hors zone, minimum de
      // commande non atteint, article devenu indisponible. Aucun montant de
      // secours n'est fabriqué : le bouton de commande reste inactif tant
      // qu'aucun devis n'est arrivé.
      eccore.Journal.trace('Devis de commande indisponible : $e');
      if (mounted) {
        setState(() {
          _deliveryBreakdown = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is eccore.ApiException
                  ? e.detail
                  : 'Impossible de chiffrer la commande pour le moment.',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDeliveryFee = false;
        });
      }
    }
  }

  // Plus de rattrapage de coordonnées ici : une `eccore.Address` en porte toujours,
  // par construction. Cet écran géocodait l'adresse choisie quand elle n'en
  // avait pas — un rattrapage qui n'existait que parce que le carnet laissait
  // créer des adresses sans point, et qui n'a plus d'objet.

  Future<void> _selectAddress() async {
    final selected = await Navigator.of(context).push<eccore.Address>(
      MaterialPageRoute(
        builder: (context) => AddressSelectorScreen(
          currentAddress: _selectedAddress,
          onAddressSelected: (eccore.Address address) {
            Navigator.of(context).pop(address);
          },
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedAddress = selected;
        _addressController.text = selected.uneLigne;
      });
      await _calculateDeliveryFeeForAddress(selected);
    }
  }

  // NOTE: V2 adresses: plus de saisie libre dans le checkout.
  // L'utilisateur doit sélectionner une eccore.Address (avec lat/lng).

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande'),
        // UX: checkout = focus (notifications ailleurs)
      ),
      body: Consumer2<AppService, CartService>(
        builder: (context, appService, cartService, child) {
          final isGroupOrder = widget.existingOrderId != null;
          final cartItems =
              isGroupOrder ? (widget.preloadedItems ?? []) : cartService.items;
          final subtotal = isGroupOrder
              ? (widget.preloadedTotal ?? 0.0)
              : cartService.subtotal;
          final deliveryFee = cartService.deliveryFee;
          final discount = isGroupOrder ? 0.0 : cartService.discount;
          // Le total vient du devis serveur dès qu'il existe. La ligne
          // précédente le recomposait ici (`sous-total + frais − remise`), ce
          // qui donnait un troisième chiffre, différent de celui du panier et
          // de celui de la commande.
          final total = isGroupOrder
              ? (subtotal + deliveryFee - discount)
              : cartService.total;

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
                        _buildStepHeader(context, '1. Récapitulatif'),
                        const SizedBox(height: 8),
                        _buildOrderSummary(
                          context,
                          cartItems,
                          subtotal,
                          deliveryFee,
                          discount,
                          total,
                          cartService.itemCount,
                          cartService.promoCode,
                        ),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '2. Livraison'),
                        const SizedBox(height: 8),
                        _buildDeliverySection(context),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '3. Paiement'),
                        const SizedBox(height: 8),
                        _buildPaymentSection(context),
                        const SizedBox(height: 24),
                        _buildStepHeader(context, '4. Notes'),
                        const SizedBox(height: 8),
                        _buildNotesSection(context),
                      ],
                    ),
                  ),
                ),
                _buildCheckoutButton(context, appService, cartService, total),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
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
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    int itemCount,
    String? promoCode,
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
                  'Sous-total (${cartItems.length} article${cartItems.length > 1 ? 's' : ''})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  PriceFormatter.format(subtotal),
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
                  PriceFormatter.format(deliveryFee),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (discount > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Remise${promoCode != null ? ' ($promoCode)' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                  ),
                  Text(
                    '-${PriceFormatter.format(discount)}',
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
                  PriceFormatter.format(total),
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
    return AuthStyleCard(
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
              const Spacer(),
              TextButton.icon(
                onPressed: _selectAddress,
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Changer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthStyleTextField(
            controller: _addressController,
            label: 'Adresse sélectionnée',
            hintText: 'Sélectionnez une adresse',
            icon: Icons.location_on,
            maxLines: 3,
            enabled: false,
            validator: (_) =>
                _selectedAddress == null ? 'Veuillez sélectionner une adresse' : null,
          ),
          if (_isCalculatingDeliveryFee) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Calcul des frais de livraison...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],
          // Afficher le breakdown détaillé si disponible
          if (_deliveryBreakdown != null && !_isCalculatingDeliveryFee) ...[
            const SizedBox(height: 16),
            DeliveryFeeBreakdownCard(
              breakdown: _deliveryBreakdown!,
              showTitle: false,
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    return AuthStyleCard(
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values
                .where(
              (method) => method != PaymentMethod.wallet,
            ) // Portefeuille désactivé temporairement
                .map((method) {
              final selected = _selectedPayment == method;
              // Désactiver mobile money, credit card et debit card
              final isDisabled = method == PaymentMethod.mobileMoney ||
                  method == PaymentMethod.creditCard ||
                  method == PaymentMethod.debitCard;
              return Opacity(
                opacity: isDisabled ? 0.5 : 1.0,
                child: ChoiceChip(
                  label: Text('${method.emoji} ${method.displayName}'),
                  selected: selected && !isDisabled,
                  onSelected: isDisabled
                      ? null
                      : (_) => setState(() => _selectedPayment = method),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedPayment.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return AuthStyleCard(
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
          AuthStyleTextField(
            controller: _notesController,
            label: 'Instructions pour le livreur (optionnel)',
            hintText: 'Ex: Sonner à la porte, laisser devant la porte...',
            icon: Icons.note,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    AppService appService,
    CartService cartService,
    double total,
  ) {
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
            AuthStyleButton(
              text: _isLoading ? 'Traitement...' : 'Confirmer la commande',
              onPressed: _isLoading
                  ? null
                  : () => _placeOrder(context, appService, cartService, total),
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.check_circle_outline,
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
    double total,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Le géocodage de rattrapage qui se trouvait ici — deux passes, dont une
    // qui affichait « Géocodage de l'adresse en cours… » au moment de payer —
    // n'a plus d'objet : une adresse du carnet porte toujours son point, et
    // elle existe toujours côté serveur.
    setState(() {
      _isLoading = true;
    });

    try {
      final addressToUse = _selectedAddress;

      if (addressToUse == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choisissez une adresse de livraison.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Créer la commande d'abord (Django, Phase 6) — le paiement s'ouvre
      // ensuite contre une commande réelle, jamais l'inverse.
      //
      // La commande de groupe ne passe plus par ici : elle naît de la
      // confirmation du panier collaboratif (`group-carts/{id}/confirm/`), qui
      // est le seul chemin où le serveur sait répartir les lignes entre
      // convives.
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

      // `context.mounted` et non `mounted` : le contexte utilisé ici est celui
      // que la méthode reçoit en paramètre, pas celui de l'état.
      if (finalOrderId.isNotEmpty && context.mounted) {
        cartService.clear();
        // Le paiement se règle par webhook signé, jamais par le retour de
        // cet écran (`apps/payments/services.py`) — la commande existe déjà
        // quelle que soit l'issue.
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => PaymentScreen(orderId: finalOrderId)),
        );
      }

      if (finalOrderId.isNotEmpty && mounted) {
        // Naviguer vers l'écran de suivi de commande
        if (mounted && context.mounted) {
          await context.navigateToDeliveryTracking(finalOrderId);
        }

        // Afficher un message de succès
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commande #$finalOrderId passée avec succès! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        // Capturer les valeurs nécessaires avant le gap async
        final errorColor = Theme.of(context).colorScheme.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la commande: ${e.toString()}'),
            backgroundColor: errorColor,
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
