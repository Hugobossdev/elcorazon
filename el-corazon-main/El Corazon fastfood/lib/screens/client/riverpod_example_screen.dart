import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elcora_fast/providers/menu_providers.dart';
import 'package:elcora_fast/providers/cart_providers.dart';
import 'package:elcora_fast/models/menu_item.dart';

/// Exemple d'écran utilisant Riverpod pour la gestion d'état
/// Cet écran montre comment utiliser Riverpod à la place de Provider
class RiverpodExampleScreen extends ConsumerWidget {
  const RiverpodExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utiliser les providers Riverpod
    final menuItemsAsync = ref.watch(menuItemsProvider);
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemple Riverpod'),
        actions: [
          // Badge pour le panier
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // Naviguer vers le panier
                },
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cartState.itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: menuItemsAsync.when(
        data: (items) => _buildMenuItems(context, ref, items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Recharger les données
                  ref.invalidate(menuItemsProvider);
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, WidgetRef ref, List<MenuItem> items) {
    final cartNotifier = ref.read(cartProvider.notifier);

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: item.imageUrl != null
              ? Image.network(item.imageUrl!, width: 60, height: 60, fit: BoxFit.cover)
              : const Icon(Icons.restaurant),
          title: Text(item.name),
          subtitle: Text(item.description),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${item.price.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () {
                  // Ajouter au panier
                  cartNotifier.addItem(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} ajouté au panier'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Ajouter'),
              ),
            ],
          ),
        );
      },
    );
  }
}

