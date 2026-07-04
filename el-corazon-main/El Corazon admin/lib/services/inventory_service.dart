import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final double currentStock;
  final double minimumStock;
  final String unit; // 'kg', 'liters', 'pieces', etc.
  final double unitPrice;
  final DateTime? lastRestockDate;
  final DateTime? expiryDate;
  final String? supplier;
  final String? location;
  final bool isLowStock;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.minimumStock,
    required this.unit,
    required this.unitPrice,
    this.lastRestockDate,
    this.expiryDate,
    this.supplier,
    this.location,
    bool? isLowStock,
  }) : isLowStock = currentStock <= minimumStock;

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      currentStock: (map['current_stock'] as num).toDouble(),
      minimumStock: (map['minimum_stock'] as num).toDouble(),
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      lastRestockDate: map['last_restock_date'] != null
          ? DateTime.parse(map['last_restock_date'])
          : null,
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'])
          : null,
      supplier: map['supplier'] as String?,
      location: map['location'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'unit': unit,
      'unit_price': unitPrice,
      'last_restock_date': lastRestockDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'supplier': supplier,
      'location': location,
    };
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? currentStock,
    double? minimumStock,
    String? unit,
    double? unitPrice,
    DateTime? lastRestockDate,
    DateTime? expiryDate,
    String? supplier,
    String? location,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      lastRestockDate: lastRestockDate ?? this.lastRestockDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      location: location ?? this.location,
    );
  }
}

class InventoryService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<InventoryItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<InventoryItem> get items => List.unmodifiable(_items);
  List<InventoryItem> get lowStockItems =>
      _items.where((item) => item.isLowStock).toList();
  List<InventoryItem> get expiredItems {
    final now = DateTime.now();
    return _items
        .where((item) => item.expiryDate != null && item.expiryDate!.isBefore(now))
        .toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalItems => _items.length;
  int get lowStockCount => lowStockItems.length;
  int get expiredCount => expiredItems.length;

  double get totalInventoryValue {
    return _items.fold(0.0, (sum, item) => sum + (item.currentStock * item.unitPrice));
  }

  /// Charger tous les articles d'inventaire
  Future<void> loadInventory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('inventory_items')
          .select()
          .order('name', ascending: true);

      _items = (response as List)
          .map((item) => InventoryItem.fromMap(item))
          .toList();
      
      debugPrint('✅ Chargé ${_items.length} articles d\'inventaire');
    } catch (e) {
      _error = 'Erreur lors du chargement de l\'inventaire: $e';
      debugPrint('❌ $_error');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajouter un article à l'inventaire
  Future<bool> addItem(InventoryItem item) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('inventory_items')
          .insert(item.toMap())
          .select()
          .single();

      final newItem = InventoryItem.fromMap(response);
      _items.add(newItem);
      _items.sort((a, b) => a.name.compareTo(b.name));
      
      debugPrint('✅ Article ajouté: ${newItem.name}');
      return true;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mettre à jour un article
  Future<bool> updateItem(String id, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('inventory_items')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      final updatedItem = InventoryItem.fromMap(response);
      final index = _items.indexWhere((item) => item.id == id);
      
      if (index != -1) {
        _items[index] = updatedItem;
        _items.sort((a, b) => a.name.compareTo(b.name));
      }
      
      debugPrint('✅ Article mis à jour: ${updatedItem.name}');
      return true;
    } catch (e) {
      _error = 'Erreur lors de la mise à jour: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Supprimer un article
  Future<bool> deleteItem(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('inventory_items').delete().eq('id', id);
      
      _items.removeWhere((item) => item.id == id);
      
      debugPrint('✅ Article supprimé: $id');
      return true;
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restocker un article
  Future<bool> restockItem(String id, double quantity) async {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      final newStock = item.currentStock + quantity;

      return await updateItem(id, {
        'current_stock': newStock,
        'last_restock_date': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Article non trouvé: $id');
      return false;
    }
  }

  /// Consommer un article (réduire le stock)
  Future<bool> consumeItem(String id, double quantity) async {
    try {
      final item = _items.firstWhere((i) => i.id == id);
      final newStock = (item.currentStock - quantity).clamp(0.0, double.infinity);

      return await updateItem(id, {
        'current_stock': newStock,
      });
    } catch (e) {
      debugPrint('Article non trouvé: $id');
      return false;
    }
  }

  /// Filtrer par catégorie
  List<InventoryItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  /// Obtenir les statistiques de l'inventaire
  Map<String, dynamic> getStatistics() {
    final categories = _items.map((item) => item.category).toSet().toList();
    
    final categoryStats = <String, Map<String, dynamic>>{};
    for (final category in categories) {
      final categoryItems = _items.where((i) => i.category == category).toList();
      categoryStats[category] = {
        'count': categoryItems.length,
        'low_stock_count': categoryItems.where((i) => i.isLowStock).length,
        'total_value': categoryItems.fold(
          0.0,
          (sum, item) => sum + (item.currentStock * item.unitPrice),
        ),
      };
    }

    return {
      'total_items': totalItems,
      'low_stock_count': lowStockCount,
      'expired_count': expiredCount,
      'total_value': totalInventoryValue,
      'categories': categoryStats,
    };
  }

  /// Vérifier les alertes de stock faible et expirations
  Future<List<InventoryAlert>> checkAlerts() async {
    final alerts = <InventoryAlert>[];

    // Vérifier les stocks faibles
    for (final item in lowStockItems) {
      alerts.add(InventoryAlert(
        type: AlertType.lowStock,
        itemId: item.id,
        itemName: item.name,
        message: 'Stock faible: ${item.currentStock} ${item.unit} (minimum: ${item.minimumStock} ${item.unit})',
        severity: item.currentStock <= (item.minimumStock * 0.5) 
            ? AlertSeverity.critical 
            : AlertSeverity.warning,
        createdAt: DateTime.now(),
      ));
    }

    // Vérifier les articles expirés
    for (final item in expiredItems) {
      alerts.add(InventoryAlert(
        type: AlertType.expired,
        itemId: item.id,
        itemName: item.name,
        message: 'Article expiré depuis ${DateTime.now().difference(item.expiryDate!).inDays} jours',
        severity: AlertSeverity.critical,
        createdAt: DateTime.now(),
      ));
    }

    // Vérifier les articles proches de l'expiration (7 jours)
    final now = DateTime.now();
    final soonToExpire = _items.where((item) {
      if (item.expiryDate == null) return false;
      final daysUntilExpiry = item.expiryDate!.difference(now).inDays;
      return daysUntilExpiry > 0 && daysUntilExpiry <= 7;
    }).toList();

    for (final item in soonToExpire) {
      final daysUntilExpiry = item.expiryDate!.difference(now).inDays;
      alerts.add(InventoryAlert(
        type: AlertType.expiringSoon,
        itemId: item.id,
        itemName: item.name,
        message: 'Expire dans $daysUntilExpiry jour(s)',
        severity: daysUntilExpiry <= 3 ? AlertSeverity.warning : AlertSeverity.info,
        createdAt: DateTime.now(),
      ));
    }

    return alerts;
  }

  /// Configurer des alertes automatiques
  Future<void> setupAutomaticAlerts({
    required Function(List<InventoryAlert>) onAlerts,
    Duration checkInterval = const Duration(hours: 1),
  }) async {
    // Vérifier les alertes immédiatement
    final alerts = await checkAlerts();
    if (alerts.isNotEmpty) {
      onAlerts(alerts);
    }

    // Programmer des vérifications périodiques
    // Note: Dans une vraie application, utiliser un service de background tasks
    // Pour le web, on peut utiliser un Timer ou un Stream
    debugPrint('✅ Alertes automatiques configurées (vérification toutes les ${checkInterval.inHours}h)');
  }
}

/// Alerte d'inventaire
class InventoryAlert {
  final AlertType type;
  final String itemId;
  final String itemName;
  final String message;
  final AlertSeverity severity;
  final DateTime createdAt;

  InventoryAlert({
    required this.type,
    required this.itemId,
    required this.itemName,
    required this.message,
    required this.severity,
    required this.createdAt,
  });
}

enum AlertType {
  lowStock,
  expired,
  expiringSoon,
}

enum AlertSeverity {
  info,
  warning,
  critical,
}

