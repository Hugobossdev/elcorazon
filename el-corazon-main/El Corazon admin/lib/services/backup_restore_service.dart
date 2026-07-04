import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/order.dart';
import '../models/menu_models.dart';

class BackupRestoreService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  /// Créer une sauvegarde des données critiques
  Future<String?> createBackup() async {
    try {
      _isProcessing = true;
      notifyListeners();

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      
      // 1. Sauvegarder les commandes
      final orders = await _supabase.from('orders').select();
      
      // 2. Sauvegarder le menu
      final menuItems = await _supabase.from('menu_items').select();
      final categories = await _supabase.from('menu_categories').select();
      
      // 3. Sauvegarder les utilisateurs (infos publiques)
      final users = await _supabase.from('users').select();

      final backupData = {
        'version': '1.0',
        'timestamp': timestamp,
        'data': {
          'orders': orders,
          'menu_items': menuItems,
          'categories': categories,
          'users': users,
        }
      };

      // Convertir en JSON
      final jsonString = jsonEncode(backupData);

      // Upload to Storage (binaire)
      final fileName = 'backups/backup_$timestamp.json';
      final bytes = utf8.encode(jsonString);
      await _supabase.storage
          .from('admin-backups')
          .uploadBinary(fileName, bytes);

      _isProcessing = false;
      notifyListeners();
      
      return fileName;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  /// Restaurer à partir d'un JSON (Attention: Dangereux)
  Future<bool> restoreFromJson(Map<String, dynamic> jsonData) async {
    // Implémentation de la restauration (nécessite des droits admin élevés)
    // À utiliser avec précaution
    return false;
  }

  /// Exporter les commandes
  Future<List<Order>> backupOrders() async {
    final response = await _supabase.from('orders').select();
    return (response as List).map((e) => Order.fromMap(e)).toList();
  }

  /// Exporter le menu
  Future<List<MenuItem>> backupMenu() async {
    final response = await _supabase.from('menu_items').select();
    return (response as List).map((e) => MenuItem.fromMap(e)).toList();
  }
}
