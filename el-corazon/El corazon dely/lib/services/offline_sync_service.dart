import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/order.dart';
import '../models/menu_item.dart';

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  Database? _database;
  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  final List<PendingOperation> _pendingOperations = [];
  Timer? _syncTimer;

  // Getters
  bool get isOnline => _isOnline;
  List<PendingOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);

  /// Initialise le service de synchronisation hors ligne
  Future<void> initialize() async {
    await _initializeDatabase();
    await _initializeConnectivity();
    _startSyncTimer();
    debugPrint('OfflineSyncService: Service initialisé');
  }

  /// Initialise la base de données SQLite locale
  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'el_corazon_offline.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    debugPrint('OfflineSyncService: Base de données locale initialisée');
  }

  /// Crée les tables de la base de données
  Future<void> _onCreate(Database db, int version) async {
    // Table des commandes hors ligne
    await db.execute('''
      CREATE TABLE offline_orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Table des items du menu en cache
    await db.execute('''
      CREATE TABLE cached_menu_items (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        last_updated INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // Table des opérations en attente
    await db.execute('''
      CREATE TABLE pending_operations (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Table des préférences utilisateur
    await db.execute('''
      CREATE TABLE user_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    debugPrint('OfflineSyncService: Tables créées');
  }

  /// Met à jour la base de données
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Logique de mise à jour si nécessaire
  }

  /// Initialise la surveillance de connectivité
  Future<void> _initializeConnectivity() async {
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        _syncPendingOperations();
      }

      notifyListeners();
      debugPrint(
          'OfflineSyncService: Connectivité changée - ${_isOnline ? "En ligne" : "Hors ligne"}');
    });

    // Vérifier l'état initial
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    notifyListeners();
  }

  /// Démarre le timer de synchronisation
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        _syncPendingOperations();
      }
    });
  }

  /// Sauvegarde une commande hors ligne
  Future<void> saveOrderOffline(Order order) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'offline_orders',
        {
          'id': order.id,
          'user_id': order.userId,
          'data': json.encode(order.toMap()),
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Ajouter à la liste des opérations en attente
      _pendingOperations.add(PendingOperation(
        id: order.id,
        type: 'create_order',
        data: order.toMap(),
        createdAt: DateTime.now(),
        retryCount: 0,
      ));

      notifyListeners();
      debugPrint(
          'OfflineSyncService: Commande sauvegardée hors ligne - ${order.id}');
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de sauvegarde hors ligne - $e');
    }
  }

  /// Met à jour une commande hors ligne
  Future<void> updateOrderOffline(
      String orderId, Map<String, dynamic> updates) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'pending_operations',
        {
          'id': '${orderId}_update_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'update_order',
          'data': json.encode({'orderId': orderId, 'updates': updates}),
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
        },
      );

      // Mettre à jour la commande locale
      await _database!.update(
        'offline_orders',
        {'data': json.encode(updates)},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      notifyListeners();
      debugPrint(
          'OfflineSyncService: Commande mise à jour hors ligne - $orderId');
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de mise à jour hors ligne - $e');
    }
  }

  /// Obtient les commandes hors ligne
  Future<List<Order>> getOfflineOrders(String userId) async {
    if (_database == null) return [];

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'offline_orders',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return maps.map((map) {
        final data = json.decode(map['data'] as String);
        return Order.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de récupération des commandes hors ligne - $e');
      return [];
    }
  }

  /// Cache les items du menu
  Future<void> cacheMenuItems(List<MenuItem> items) async {
    if (_database == null) return;

    try {
      final batch = _database!.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = now + (24 * 60 * 60 * 1000); // 24 heures

      for (final item in items) {
        batch.insert(
          'cached_menu_items',
          {
            'id': item.id,
            'data': json.encode(item.toMap()),
            'last_updated': now,
            'expires_at': expiresAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      debugPrint(
          'OfflineSyncService: ${items.length} items du menu mis en cache');
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de mise en cache du menu - $e');
    }
  }

  /// Obtient les items du menu depuis le cache
  Future<List<MenuItem>> getCachedMenuItems() async {
    if (_database == null) return [];

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final List<Map<String, dynamic>> maps = await _database!.query(
        'cached_menu_items',
        where: 'expires_at > ?',
        whereArgs: [now],
      );

      return maps.map((map) {
        final data = json.decode(map['data'] as String);
        return MenuItem.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de récupération du cache du menu - $e');
      return [];
    }
  }

  /// Sauvegarde les préférences utilisateur
  Future<void> saveUserPreference(String key, dynamic value) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'user_preferences',
        {
          'key': key,
          'value': json.encode(value),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('OfflineSyncService: Préférence sauvegardée - $key');
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de sauvegarde des préférences - $e');
    }
  }

  /// Obtient une préférence utilisateur
  Future<T?> getUserPreference<T>(String key) async {
    if (_database == null) return null;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (maps.isNotEmpty) {
        return json.decode(maps.first['value'] as String) as T;
      }
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de récupération des préférences - $e');
    }

    return null;
  }

  /// Synchronise les opérations en attente
  Future<void> _syncPendingOperations() async {
    if (_database == null || !_isOnline) return;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'pending_operations',
        orderBy: 'created_at ASC',
      );

      for (final map in maps) {
        final operation = PendingOperation.fromMap(map);
        await _processPendingOperation(operation);
      }

      debugPrint('OfflineSyncService: Synchronisation terminée');
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de synchronisation - $e');
    }
  }

  /// Traite une opération en attente
  Future<void> _processPendingOperation(PendingOperation operation) async {
    try {
      bool success = false;

      switch (operation.type) {
        case 'create_order':
          success = await _syncCreateOrder(operation.data);
          break;
        case 'update_order':
          success = await _syncUpdateOrder(operation.data);
          break;
        case 'delete_order':
          success = await _syncDeleteOrder(operation.data);
          break;
        default:
          debugPrint(
              'OfflineSyncService: Type d\'opération non supporté - ${operation.type}');
      }

      if (success) {
        await _database!.delete(
          'pending_operations',
          where: 'id = ?',
          whereArgs: [operation.id],
        );

        _pendingOperations.removeWhere((op) => op.id == operation.id);
        debugPrint(
            'OfflineSyncService: Opération synchronisée - ${operation.id}');
      } else {
        // Incrémenter le compteur de tentatives
        await _database!.update(
          'pending_operations',
          {'retry_count': operation.retryCount + 1},
          where: 'id = ?',
          whereArgs: [operation.id],
        );

        // Si trop de tentatives, supprimer l'opération
        if (operation.retryCount >= 3) {
          await _database!.delete(
            'pending_operations',
            where: 'id = ?',
            whereArgs: [operation.id],
          );
          debugPrint(
              'OfflineSyncService: Opération abandonnée après 3 tentatives - ${operation.id}');
        }
      }
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de traitement de l\'opération - $e');
    }
  }

  /// Synchronise une création de commande
  Future<bool> _syncCreateOrder(Map<String, dynamic> data) async {
    try {
      // Simuler l'envoi à l'API
      await Future.delayed(const Duration(seconds: 1));

      // Marquer comme synchronisé
      await _database!.update(
        'offline_orders',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [data['id']],
      );

      return true;
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de synchronisation de création - $e');
      return false;
    }
  }

  /// Synchronise une mise à jour de commande
  Future<bool> _syncUpdateOrder(Map<String, dynamic> data) async {
    try {
      // Simuler l'envoi à l'API
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de synchronisation de mise à jour - $e');
      return false;
    }
  }

  /// Synchronise une suppression de commande
  Future<bool> _syncDeleteOrder(Map<String, dynamic> data) async {
    try {
      // Simuler l'envoi à l'API
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Erreur de synchronisation de suppression - $e');
      return false;
    }
  }

  /// Force la synchronisation
  Future<void> forceSync() async {
    if (_isOnline) {
      await _syncPendingOperations();
    }
  }

  /// Nettoie les données expirées
  Future<void> cleanupExpiredData() async {
    if (_database == null) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Supprimer les items du menu expirés
      await _database!.delete(
        'cached_menu_items',
        where: 'expires_at < ?',
        whereArgs: [now],
      );

      // Supprimer les opérations anciennes (plus de 7 jours)
      final weekAgo = now - (7 * 24 * 60 * 60 * 1000);
      await _database!.delete(
        'pending_operations',
        where: 'created_at < ?',
        whereArgs: [weekAgo],
      );

      debugPrint('OfflineSyncService: Nettoyage des données expirées terminé');
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de nettoyage - $e');
    }
  }

  /// Obtient les statistiques de synchronisation
  Future<SyncStats> getSyncStats() async {
    if (_database == null) {
      return SyncStats(
        pendingOperations: 0,
        cachedMenuItems: 0,
        offlineOrders: 0,
        lastSyncTime: null,
      );
    }

    try {
      final pendingCount = Sqflite.firstIntValue(await _database!
              .rawQuery('SELECT COUNT(*) FROM pending_operations')) ??
          0;

      final cachedCount = Sqflite.firstIntValue(await _database!
              .rawQuery('SELECT COUNT(*) FROM cached_menu_items')) ??
          0;

      final offlineCount = Sqflite.firstIntValue(await _database!.rawQuery(
              'SELECT COUNT(*) FROM offline_orders WHERE synced = 0')) ??
          0;

      return SyncStats(
        pendingOperations: pendingCount,
        cachedMenuItems: cachedCount,
        offlineOrders: offlineCount,
        lastSyncTime: DateTime.now(), // Simuler la dernière sync
      );
    } catch (e) {
      debugPrint('OfflineSyncService: Erreur de calcul des statistiques - $e');
      return SyncStats(
        pendingOperations: 0,
        cachedMenuItems: 0,
        offlineOrders: 0,
        lastSyncTime: null,
      );
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _database?.close();
    super.dispose();
  }
}

class PendingOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  PendingOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.retryCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': json.encode(data),
      'created_at': createdAt.millisecondsSinceEpoch,
      'retry_count': retryCount,
    };
  }

  static PendingOperation fromMap(Map<String, dynamic> map) {
    return PendingOperation(
      id: map['id'],
      type: map['type'],
      data: json.decode(map['data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      retryCount: map['retry_count'],
    );
  }
}

class SyncStats {
  final int pendingOperations;
  final int cachedMenuItems;
  final int offlineOrders;
  final DateTime? lastSyncTime;

  SyncStats({
    required this.pendingOperations,
    required this.cachedMenuItems,
    required this.offlineOrders,
    required this.lastSyncTime,
  });
}
