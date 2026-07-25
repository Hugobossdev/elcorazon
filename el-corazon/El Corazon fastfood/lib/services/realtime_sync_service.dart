import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart' as fs;  // Commented out - Firebase not configured
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/order.dart' as model_order;

/// Service de synchronisation temps réel Supabase <-> Firestore
class RealtimeSyncService extends ChangeNotifier {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Firebase/Cloud Firestore support is disabled - using Supabase only
  // To enable Firestore, uncomment cloud_firestore in pubspec.yaml, configure Firebase,
  // and uncomment the Firestore-related code below

  RealtimeChannel? _menuItemsChannel;
  RealtimeChannel? _ordersChannel;

  final StreamController<List<MenuItem>> _menuItemsController =
      StreamController<List<MenuItem>>.broadcast();
  final StreamController<List<model_order.Order>> _ordersController =
      StreamController<List<model_order.Order>>.broadcast();

  Stream<List<MenuItem>> get menuItemsStream => _menuItemsController.stream;
  Stream<List<model_order.Order>> get ordersStream => _ordersController.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final tasks = <Future<void>>[
      _subscribeSupabaseMenuItems(),
      _subscribeSupabaseOrders(),
    ];

    // Firebase disabled - not configured
    // if (_enableFirestoreFallback) {
    //   try {
    //     _firestore ??= await _loadFirestore();
    //     tasks.add(_subscribeFirestoreMenuItems());
    //     tasks.add(_subscribeFirestoreOrders());
    //   } catch (e) {
    //     debugPrint(
    //         'RealtimeSyncService: Firestore désactivé (initialisation impossible): $e');
    //   }
    // }

    await Future.wait(tasks);

    _initialized = true;
  }

  Future<void> disposeSubscriptions() async {
    await _menuItemsChannel?.unsubscribe();
    await _ordersChannel?.unsubscribe();
    await _menuItemsController.close();
    await _ordersController.close();
    _initialized = false;
  }

  // ================= Supabase =================
  Future<void> _subscribeSupabaseMenuItems() async {
    try {
      _menuItemsChannel = _supabase
          .channel('realtime_menu_items')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'menu_items',
            callback: (_) async {
              final data = await _supabase
                  .from('menu_items')
                  .select('*, menu_categories(name, display_name)');
              final items =
                  List<Map<String, dynamic>>.from(data).map(MenuItem.fromMap).toList();
              _menuItemsController.add(items);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('RealtimeSyncService: Supabase menu_items subscribe error: $e');
    }
  }

  Future<void> _subscribeSupabaseOrders() async {
    try {
      _ordersChannel = _supabase
          .channel('realtime_orders')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (_) async {
              final data = await _supabase
                  .from('orders')
                  .select('*, order_items(*)')
                  .order('created_at', ascending: false)
                  .limit(50);
              final orders = List<Map<String, dynamic>>.from(data)
                  .map((m) => model_order.Order.fromMap(m))
                  .toList();
              _ordersController.add(orders);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('RealtimeSyncService: Supabase orders subscribe error: $e');
    }
  }

  // ================= Firestore =================
  // Commented out - Firebase not configured
  // Future<void> _subscribeFirestoreMenuItems() async {
  //   if (!_enableFirestoreFallback || _firestore == null) return;
  //   ...
  // }

  // Future<void> _subscribeFirestoreOrders() async {
  //   if (!_enableFirestoreFallback || _firestore == null) return;
  //   ...
  // }

  // Future<fs.FirebaseFirestore> _loadFirestore() async {
  //   ...
  // }
}


