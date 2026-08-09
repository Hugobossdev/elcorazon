# 📋 Guide de l'Historique des Commandes Amélioré

> ⚠️ **Document antérieur à la migration Django (1er août 2026).**
> Les exemples ci-dessous montrent des dépôts Supabase qui n'existent plus.
> L'accès aux données passe désormais par `packages/elcorazon_core`, dont les
> dépôts parlent à l'API Django `/api/v1/*`. Le **patron** décrit ici reste
> valable — c'est son implémentation qui a changé.
>
> Référence : [`docs/architecture/04-migration-flutter.md`](../../../docs/architecture/04-migration-flutter.md).

## Vue d'ensemble

L'amélioration #16 implémente un historique des commandes amélioré avec :
- Filtres par statut (toutes, en cours, terminées, annulées)
- Options de tri (date, prix, statut)
- Groupement par date
- Statistiques des commandes
- Interface améliorée

## Fonctionnalités

### 1. Filtres par Statut

- **Toutes** : Affiche toutes les commandes
- **En cours** : Commandes en cours (pending, confirmed, preparing, ready, pickedUp, onTheWay)
- **Terminées** : Commandes livrées
- **Annulées** : Commandes annulées

### 2. Options de Tri

- **Date décroissante** : Plus récentes en premier (par défaut)
- **Date croissante** : Plus anciennes en premier
- **Prix décroissant** : Plus chères en premier
- **Prix croissant** : Moins chères en premier
- **Par statut** : Grouper par statut

### 3. Groupement par Date

Les commandes sont automatiquement groupées par date :
- Aujourd'hui
- Hier
- Cette semaine
- Ce mois
- Date spécifique (JJ/MM/AAAA)

### 4. Statistiques

Le service fournit des statistiques :
- Nombre total de commandes
- Montant total dépensé
- Valeur moyenne des commandes
- Répartition par statut

## Utilisation

### 1. Créer le Service

```dart
import 'lib/services/order_history_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

final orderRepository = OrderRepository(apiClient: apiClient);
final orderHistoryService = OrderHistoryService(orderRepository);
```

### 2. Charger les Commandes

```dart
final userId = appService.currentUser?.id;
if (userId != null) {
  await orderHistoryService.loadOrders(userId);
}
```

### 3. Appliquer un Filtre

```dart
// Filtrer par statut
orderHistoryService.applyFilter(OrderFilter.active);
orderHistoryService.applyFilter(OrderFilter.completed);
orderHistoryService.applyFilter(OrderFilter.all);

// Obtenir les commandes filtrées
final filteredOrders = orderHistoryService.orders;
```

### 4. Appliquer un Tri

```dart
// Trier par date (plus récentes en premier)
orderHistoryService.applySort(OrderSortOption.dateDesc);

// Trier par prix (plus chères en premier)
orderHistoryService.applySort(OrderSortOption.totalDesc);

// Obtenir les commandes triées
final sortedOrders = orderHistoryService.orders;
```

### 5. Filtrer par Date

```dart
// Filtrer par période
final startDate = DateTime(2024, 1, 1);
final endDate = DateTime(2024, 12, 31);
orderHistoryService.filterByDateRange(startDate, endDate);
```

### 6. Obtenir les Statistiques

```dart
final stats = orderHistoryService.getStatistics();
print('Total: ${stats['totalOrders']} commandes');
print('Montant total: ${stats['totalSpent']} FCFA');
print('Moyenne: ${stats['averageOrderValue']} FCFA');
```

### 7. Obtenir les Commandes Groupées par Date

```dart
final groupedOrders = orderHistoryService.getOrdersGroupedByDate();

groupedOrders.forEach((dateKey, orders) {
  print('$dateKey: ${orders.length} commandes');
});
```

## Exemple Complet : Écran avec Filtres

```dart
class EnhancedOrdersScreen extends StatefulWidget {
  @override
  State<EnhancedOrdersScreen> createState() => _EnhancedOrdersScreenState();
}

class _EnhancedOrdersScreenState extends State<EnhancedOrdersScreen> {
  late OrderHistoryService _orderHistoryService;

  @override
  void initState() {
    super.initState();
    final orderRepository = OrderRepository(apiClient: apiClient);
    _orderHistoryService = OrderHistoryService(orderRepository);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mes Commandes'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Consumer<OrderHistoryService>(
        builder: (context, service, child) {
          final orders = service.orders;

          // Grouper par date
          final groupedOrders = service.getOrdersGroupedByDate();

          return ListView.builder(
            itemCount: groupedOrders.length,
            itemBuilder: (context, index) {
              final dateKey = groupedOrders.keys.elementAt(index);
              final dateOrders = groupedOrders[dateKey]!;

              return Column(
                children: [
                  // En-tête de date
                  Text(dateKey),
                  // Liste des commandes
                  ...dateOrders.map((order) => OrderCard(order: order)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FilterBottomSheet(
        orderHistoryService: _orderHistoryService,
      ),
    );
  }
}
```

## Bénéfices

- ✅ **Meilleure organisation** : Filtres et tri pour trouver rapidement les commandes
- ✅ **Accès rapide** : Groupement par date pour une navigation facile
- ✅ **Expérience améliorée** : Interface claire et intuitive
- ✅ **Statistiques** : Informations sur les habitudes d'achat
- ✅ **Performance** : Tri et filtrage efficaces

