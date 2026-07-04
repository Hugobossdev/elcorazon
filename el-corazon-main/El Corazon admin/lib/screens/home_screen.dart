import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_service.dart';
import '../models/user.dart';
import '../models/order.dart';
import 'admin/enhanced_admin_dashboard.dart';
import 'admin/admin_orders_screen.dart';
import 'auth_screen.dart';
import '../utils/price_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        if (!appService.isLoggedIn) {
          return const AuthScreen();
        }

        final user = appService.currentUser!;

        return Scaffold(
          body: _buildBody(user),
          bottomNavigationBar: _buildBottomNavBar(user),
          floatingActionButton: _buildFloatingActionButton(user),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildBody(User user) {
    switch (user.role) {
      case UserRole.client:
        return _buildClientBody();
      case UserRole.admin:
        return _buildClientBody(); // Redirigé vers client
      case UserRole.delivery:
        return _buildClientBody(); // Redirigé vers client
    }
  }

  Widget _buildClientBody() {
    switch (_currentIndex) {
      case 0:
        return const EnhancedAdminDashboard();
      case 1:
        return const AdminOrdersScreen();
      case 2:
        return const EnhancedAdminDashboard();
      case 3:
        return const EnhancedAdminDashboard();
      default:
        return const EnhancedAdminDashboard();
    }
  }

  Widget _buildFloatingActionButton(User user) {
    if (user.role == UserRole.client && _currentIndex == 1) {
      return Consumer<AppService>(
        builder: (context, appService, child) {
          final cartCount = appService.cartItemCount;
          if (cartCount == 0) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _showCartBottomSheet(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            icon: const Icon(Icons.shopping_cart),
            label: Text('$cartCount'),
          );
        },
      );
    }
    // IMPORTANT: Utiliser SizedBox.shrink() au lieu de null pour éviter les problèmes de hit testing
    return const SizedBox.shrink();
  }

  Widget _buildBottomNavBar(User user) {
    List<BottomNavigationBarItem> items;

    switch (user.role) {
      case UserRole.client:
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Commandes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ];
        break;
      case UserRole.admin:
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Commandes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ];
        break;
      case UserRole.delivery:
        items = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Livraisons',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ];
        break;
    }

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.6),
      items: items,
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CartBottomSheet(),
    );
  }
}

class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final cartItems = appService.cartItems;
        final cartTotal = appService.cartTotal;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Panier (${cartItems.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: appService.clearCart,
                      child: const Text('Vider'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: false,
                  itemCount: cartItems.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= cartItems.length) {
                      return const SizedBox.shrink();
                    }
                    final item = cartItems[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.fastfood),
                              ),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Prix: ${PriceFormatter.format(item.basePrice)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            PriceFormatter.format(item.basePrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // IMPORTANT: Material + InkWell + Container avec taille explicite
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => appService.removeFromCart(item),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          PriceFormatter.format(cartTotal),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cartItems.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                // Navigate to checkout
                                _showCheckoutBottomSheet(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Commander',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _showCheckoutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const CheckoutBottomSheet(),
    );
  }
}

class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final _addressController = TextEditingController(
    text: '123 Rue de la Paix, Paris',
  );
  final _notesController = TextEditingController();
  PaymentMethod _selectedPayment = PaymentMethod.mobileMoney;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final cartTotal = appService.cartTotal;
        const deliveryFee = 1000.0;
        final total = cartTotal + deliveryFee;

        return Container(
          padding: const EdgeInsets.all(16.0),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
              ),
              Text(
                'Finaliser la commande',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse de livraison',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Instructions spéciales (optionnel)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Méthode de paiement',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              RadioGroup<PaymentMethod>(
                groupValue: _selectedPayment,
                onChanged: (value) =>
                    setState(() => _selectedPayment = value!),
                child: Column(
                  children: PaymentMethod.values.map((method) {
                    return RadioListTile<PaymentMethod>(
                      title: Row(
                        children: [
                          Text(method.emoji),
                          const SizedBox(width: 8),
                          Text(method.displayName),
                        ],
                      ),
                      value: method,
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              _buildPriceBreakdown(cartTotal, deliveryFee, total),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Confirmer la commande - ${PriceFormatter.format(total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceBreakdown(
    double cartTotal,
    double deliveryFee,
    double total,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sous-total:'),
            Text(PriceFormatter.format(cartTotal)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Livraison:'),
            Text(PriceFormatter.format(deliveryFee)),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
    );
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une adresse de livraison'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final orderId = await appService.placeOrder(
        _addressController.text.trim(),
        _selectedPayment,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted || !context.mounted) return;

      if (orderId.isNotEmpty) {
        Navigator.of(context).pop(); // Close checkout sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande #$orderId passée avec succès! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      // Capturer les valeurs nécessaires avant le gap async
      final errorColor = Theme.of(context).colorScheme.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
