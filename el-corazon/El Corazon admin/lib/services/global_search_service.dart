import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/menu_models.dart';
import '../models/user.dart' as app_user;
import '../models/driver.dart';

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'order', 'menu_item', 'user', 'driver'
  final dynamic data;
  final String? imageUrl;
  final DateTime? createdAt;

  GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.data,
    this.imageUrl,
    this.createdAt,
  });
}

class GlobalSearchResults {
  final List<GlobalSearchResult> orders;
  final List<GlobalSearchResult> menuItems;
  final List<GlobalSearchResult> users;
  final List<GlobalSearchResult> drivers;

  GlobalSearchResults({
    this.orders = const [],
    this.menuItems = const [],
    this.users = const [],
    this.drivers = const [],
  });

  bool get isEmpty =>
      orders.isEmpty &&
      menuItems.isEmpty &&
      users.isEmpty &&
      drivers.isEmpty;

  List<GlobalSearchResult> get all => [
        ...orders,
        ...menuItems,
        ...users,
        ...drivers,
      ];
}

class GlobalSearchService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Recherche globale
  Future<GlobalSearchResults> searchAll(String query) async {
    if (query.trim().isEmpty) return GlobalSearchResults();

    _isLoading = true;
    notifyListeners();

    try {
      // Lancer les recherches en parallèle
      final results = await Future.wait([
        _searchOrders(query),
        _searchMenuItems(query),
        _searchUsers(query),
        _searchDrivers(query),
      ]);

      _isLoading = false;
      notifyListeners();

      return GlobalSearchResults(
        orders: results[0],
        menuItems: results[1],
        users: results[2],
        drivers: results[3],
      );
    } catch (e) {
      debugPrint('Error in global search: $e');
      _isLoading = false;
      notifyListeners();
      return GlobalSearchResults();
    }
  }

  /// Recherche de commandes
  Future<List<GlobalSearchResult>> _searchOrders(String query) async {
    try {
      // Recherche par ID ou adresse
      final response = await _supabase
          .from('orders')
          .select()
          .or('id.ilike.%$query%,delivery_address.ilike.%$query%')
          .limit(5);

      return (response as List).map((data) {
        final order = Order.fromMap(data);
        return GlobalSearchResult(
          id: order.id,
          title: 'Commande #${order.id.substring(0, 8)}',
          subtitle: '${order.status.displayName} - ${order.total} FCFA',
          type: 'order',
          data: order,
          createdAt: order.createdAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching orders: $e');
      return [];
    }
  }

  /// Recherche d'éléments de menu
  Future<List<GlobalSearchResult>> _searchMenuItems(String query) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select()
          .ilike('name', '%$query%')
          .limit(5);

      return (response as List).map((data) {
        final item = MenuItem.fromMap(data);
        return GlobalSearchResult(
          id: item.id,
          title: item.name,
          subtitle: '${item.basePrice} FCFA - ${item.isAvailable ? 'Disponible' : 'Indisponible'}',
          type: 'menu_item',
          imageUrl: item.imageUrl,
          data: item,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching menu items: $e');
      return [];
    }
  }

  /// Recherche d'utilisateurs
  Future<List<GlobalSearchResult>> _searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .limit(5);

      return (response as List).map((data) {
        final user = app_user.User.fromMap(data);
        return GlobalSearchResult(
          id: user.id,
          title: user.name,
          subtitle: '${user.email} - ${user.role.name}',
          type: 'user',
          data: user,
          createdAt: user.createdAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Recherche de livreurs
  Future<List<GlobalSearchResult>> _searchDrivers(String query) async {
    try {
      // Recherche dans la table drivers
      final response = await _supabase
          .from('drivers')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .limit(5);

      return (response as List).map((data) {
        final driver = Driver.fromMap(data);
        return GlobalSearchResult(
          id: driver.id,
          title: driver.name,
          subtitle: 'Livreur - ${driver.status.toString().split('.').last}',
          type: 'driver',
          imageUrl: driver.profileImageUrl,
          data: driver,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching drivers: $e');
      return [];
    }
  }

  /// Recherche rapide (autocomplete)
  Future<List<GlobalSearchResult>> quickSearch(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final results = await searchAll(query);
      return results.all.take(5).toList();
    } catch (e) {
      return [];
    }
  }
}
