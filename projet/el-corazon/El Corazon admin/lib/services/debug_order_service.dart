import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class DebugOrderService {
  static Future<void> debugOrderLoading() async {
    final client = Supabase.instance.client;

    try {
      debugPrint('🔍 DEBUG: Début du chargement des commandes...');

      // Test 1: Vérifier la connexion
      debugPrint('1. Test de connexion Supabase...');
      final testResponse = await client.from('orders').select('id').limit(1);
      debugPrint(
          '✅ Connexion OK - ${testResponse.length} commande(s) trouvée(s)');

      // Test 2: Charger avec la requête exacte du OrderManagementService
      debugPrint('2. Chargement avec requête OrderManagementService...');
      final response = await client
          .from('orders')
          .select('*, order_items(*), users!orders_user_id_fkey(name, email)')
          .order('created_at', ascending: false);

      debugPrint('📦 Réponse brute: ${response.length} commande(s)');

      // Test 3: Parser chaque commande
      debugPrint('3. Parsing des commandes...');
      final orders = <Order>[];

      for (int i = 0; i < response.length; i++) {
        try {
          final orderData = response[i];
          debugPrint('   Commande ${i + 1}:');
          debugPrint('     - ID: ${orderData['id']}');
          debugPrint('     - Statut: ${orderData['status']}');
          debugPrint('     - Total: ${orderData['total']}');
          debugPrint(
              '     - Articles: ${orderData['order_items']?.length ?? 0}');

          final order = Order.fromMap(orderData);
          orders.add(order);
          debugPrint('     ✅ Parsing réussi');
        } catch (e) {
          debugPrint('     ❌ Erreur parsing: $e');
        }
      }

      debugPrint('📊 Résultat final: ${orders.length} commande(s) parsée(s)');

      // Test 4: Vérifier les statuts
      debugPrint('4. Vérification des statuts:');
      for (final order in orders) {
        debugPrint(
            '   - ${order.id}: ${order.status} (${order.status.displayName})');
      }
    } catch (e) {
      debugPrint('❌ Erreur dans debugOrderLoading: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }
}
