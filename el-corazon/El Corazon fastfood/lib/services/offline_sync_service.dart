import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/menu_category.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/services/database_service.dart';

/// Service complet de synchronisation hors ligne avec stockage persistant
class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  Database? _database;
  SharedPreferences? _prefs;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isOnline = true;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;

  // Queues pour les opérations en attente
  final List<Map<String, dynamic>> _pendingOrders = [];
  final List<Map<String, dynamic>> _pendingMenuUpdates = [];
  final List<Map<String, dynamic>> _pendingUserUpdates = [];
  final List<Map<String, dynamic>> _pendingCartUpdates = [];

  // Cache local
  List<MenuItem>? _cachedMenuItems;
  List<MenuCategory>? _cachedCategories;
  DateTime? _menuCacheTime;
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  final DatabaseService _databaseService = DatabaseService();

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<Map<String, dynamic>> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<Map<String, dynamic>> get pendingMenuUpdates => List.unmodifiable(_pendingMenuUpdates);
  List<Map<String, dynamic>> get pendingUserUpdates => List.unmodifiable(_pendingUserUpdates);
  List<Map<String, dynamic>> get pendingCartUpdates => List.unmodifiable(_pendingCartUpdates);
  int get totalPendingOperations => _pendingOrders.length + _pendingMenuUpdates.length + _pendingUserUpdates.length + _pendingCartUpdates.length;

  /// Vérifie si la base de données est disponible
  bool get _isDatabaseAvailable => _database != null && !kIsWeb;

  /// Initialise le service de synchronisation hors ligne
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeStorage();
      await _initializeDatabase();
      await _checkConnectivity();
      await _loadStoredData();
      _startConnectivityListener();
      _startSyncTimer();
      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ OfflineSyncService: Service initialisé avec succès');
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur d\'initialisation - $e');
      _isInitialized = false;
    }
  }

  /// Initialise le stockage SharedPreferences
  Future<void> _initializeStorage() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ OfflineSyncService: SharedPreferences initialisé');
  }

  /// Initialise la base de données SQLite locale
  Future<void> _initializeDatabase() async {
    // SQLite n'est pas disponible sur web, utiliser seulement SharedPreferences
    if (kIsWeb) {
      debugPrint('⚠️ OfflineSyncService: SQLite non disponible sur web, utilisation de SharedPreferences uniquement');
      _database = null;
      return;
    }

    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'fastgo_offline.db');

      _database = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      debugPrint('✅ OfflineSyncService: Base de données SQLite initialisée');
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur initialisation DB - $e');
      // Ne pas bloquer l'initialisation sur web, continuer avec SharedPreferences
      if (kIsWeb) {
        _database = null;
        debugPrint('⚠️ OfflineSyncService: Continuation avec SharedPreferences uniquement');
      } else {
        rethrow;
      }
    }
  }

  /// Crée les tables de la base de données
  Future<void> _onCreate(Database db, int version) async {
    // Table des commandes hors ligne
    await db.execute('''
      CREATE TABLE offline_orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0,
        last_sync_attempt INTEGER
      )
    ''');

    // Table des items du menu en cache
    await db.execute('''
      CREATE TABLE cached_menu_items (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        category_id TEXT,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // Table des catégories en cache
    await db.execute('''
      CREATE TABLE cached_categories (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // Table des mises à jour utilisateur en attente
    await db.execute('''
      CREATE TABLE pending_user_updates (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0
      )
    ''');

    // Table des mises à jour de panier en attente
    await db.execute('''
      CREATE TABLE pending_cart_updates (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        data TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0
      )
    ''');

    // Index pour améliorer les performances
    await db.execute('CREATE INDEX idx_offline_orders_user_id ON offline_orders(user_id)');
    await db.execute('CREATE INDEX idx_offline_orders_synced ON offline_orders(synced)');
    await db.execute('CREATE INDEX idx_pending_user_updates_user_id ON pending_user_updates(user_id)');
    await db.execute('CREATE INDEX idx_pending_cart_updates_user_id ON pending_cart_updates(user_id)');

    debugPrint('✅ OfflineSyncService: Tables créées');
  }

  /// Met à jour la base de données lors d'un changement de version
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajouter la colonne sync_attempts si elle n'existe pas
      try {
        await db.execute('ALTER TABLE offline_orders ADD COLUMN sync_attempts INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE offline_orders ADD COLUMN last_sync_attempt INTEGER');
        await db.execute('ALTER TABLE pending_user_updates ADD COLUMN sync_attempts INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE pending_cart_updates ADD COLUMN sync_attempts INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('⚠️ OfflineSyncService: Colonnes déjà présentes ou erreur: $e');
      }
    }
  }

  /// Charge les données stockées localement
  Future<void> _loadStoredData() async {
    if (!_isDatabaseAvailable) {
      debugPrint('⚠️ OfflineSyncService: Base de données non disponible, chargement depuis SharedPreferences uniquement');
      // Charger depuis SharedPreferences si disponible
      _lastSyncTime = _prefs?.getInt('last_sync_time') != null
          ? DateTime.fromMillisecondsSinceEpoch(_prefs!.getInt('last_sync_time')!)
          : null;
      return;
    }

    try {
      // Charger les commandes en attente depuis la DB
      final pendingOrdersData = await _database!.query(
        'offline_orders',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );

      _pendingOrders.clear();
      for (final row in pendingOrdersData) {
        final orderData = json.decode(row['data'] as String) as Map<String, dynamic>;
        _pendingOrders.add(orderData);
      }

      // Charger les mises à jour utilisateur en attente
      if (!_isDatabaseAvailable) return;
      final pendingUserData = await _database!.query(
        'pending_user_updates',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );

      _pendingUserUpdates.clear();
      for (final row in pendingUserData) {
        final userData = json.decode(row['data'] as String) as Map<String, dynamic>;
        _pendingUserUpdates.add(userData);
      }

      // Charger les mises à jour panier en attente
      final pendingCartData = await _database!.query(
        'pending_cart_updates',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'created_at ASC',
      );

      _pendingCartUpdates.clear();
      for (final row in pendingCartData) {
        final cartData = json.decode(row['data'] as String) as Map<String, dynamic>;
        _pendingCartUpdates.add(cartData);
      }

      // Charger le timestamp de la dernière synchronisation
      _lastSyncTime = _prefs?.getInt('last_sync_time') != null
          ? DateTime.fromMillisecondsSinceEpoch(_prefs!.getInt('last_sync_time')!)
          : null;

      debugPrint('✅ OfflineSyncService: Données chargées - ${_pendingOrders.length} commandes, ${_pendingUserUpdates.length} updates utilisateur, ${_pendingCartUpdates.length} updates panier');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur de chargement des données - $e');
    }
  }

  /// Vérifie la connectivité réseau
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = connectivityResults.isNotEmpty && 
                  !connectivityResults.contains(ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        debugPrint('📡 OfflineSyncService: Connectivité changée - ${_isOnline ? "En ligne" : "Hors ligne"}');
        
        if (_isOnline && !wasOnline) {
          // Connexion restaurée, synchroniser immédiatement
          debugPrint('🔄 OfflineSyncService: Connexion restaurée, synchronisation en cours...');
          await _syncPendingData();
        }
        
        notifyListeners();
      }
    } catch (e) {
      _isOnline = false;
      debugPrint('❌ OfflineSyncService: Erreur de vérification de connectivité - $e');
    }
  }

  /// Démarre l'écoute des changements de connectivité
  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final wasOnline = _isOnline;
        _isOnline = results.isNotEmpty && 
                    !results.contains(ConnectivityResult.none);

        if (wasOnline != _isOnline) {
          debugPrint('📡 OfflineSyncService: Connectivité changée - ${_isOnline ? "En ligne" : "Hors ligne"}');
          
          if (_isOnline && !wasOnline) {
            // Connexion restaurée, synchroniser immédiatement
            debugPrint('🔄 OfflineSyncService: Connexion restaurée, synchronisation en cours...');
            await _syncPendingData();
          }
          
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('❌ OfflineSyncService: Erreur écoute connectivité - $error');
      },
    );
  }

  /// Démarre le timer de synchronisation périodique
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_isOnline && totalPendingOperations > 0) {
        await _syncPendingData();
      }
    });
  }

  /// Synchronise les données en attente avec Supabase
  Future<void> _syncPendingData() async {
    if (!_isOnline || totalPendingOperations == 0) {
      return;
    }

    try {
      debugPrint('🔄 OfflineSyncService: Début de la synchronisation...');
      
      // Synchroniser les commandes
      await _syncPendingOrders();
      
      // Synchroniser les mises à jour utilisateur
      await _syncPendingUserUpdates();
      
      // Synchroniser les mises à jour panier
      await _syncPendingCartUpdates();
      
      // Mettre à jour le timestamp de dernière synchronisation
      _lastSyncTime = DateTime.now();
      await _prefs?.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
      
      debugPrint('✅ OfflineSyncService: Synchronisation terminée');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur de synchronisation - $e');
    }
  }

  /// Synchronise les commandes en attente
  Future<void> _syncPendingOrders() async {
    final ordersToSync = List<Map<String, dynamic>>.from(_pendingOrders);

    for (final orderData in ordersToSync) {
      try {
        final orderId = orderData['id'] as String;
        
        // Créer la commande dans Supabase
        await _databaseService.createOrder(orderData);
        
        // Ajouter les items de la commande
        if (orderData['items'] != null) {
          final items = List<Map<String, dynamic>>.from(orderData['items'] as List);
          await _databaseService.addOrderItems(orderId, items);
        }
        
        // Marquer comme synchronisé dans la DB locale
        await _database!.update(
          'offline_orders',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [orderId],
        );
        
        // Retirer de la liste en attente
        _pendingOrders.removeWhere((order) => order['id'] == orderId);
        
        debugPrint('✅ OfflineSyncService: Commande synchronisée - $orderId');
      } catch (e) {
        final orderId = orderData['id'] as String;
        debugPrint('❌ OfflineSyncService: Erreur sync commande $orderId - $e');
        
        // Incrémenter le nombre de tentatives
        await _incrementSyncAttempts('offline_orders', orderId);
      }
    }

    if (ordersToSync.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Synchronise les mises à jour utilisateur en attente
  Future<void> _syncPendingUserUpdates() async {
    final updatesToSync = List<Map<String, dynamic>>.from(_pendingUserUpdates);

    for (final updateData in updatesToSync) {
      try {
        final userId = updateData['user_id'] as String;
        final updateId = updateData['id'] as String;
        
        // Mettre à jour le profil utilisateur dans Supabase
        await _databaseService.updateUserProfile(userId, updateData);
        
        // Marquer comme synchronisé
        await _database!.update(
          'pending_user_updates',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [updateId],
        );
        
        // Retirer de la liste en attente
        _pendingUserUpdates.removeWhere((update) => update['id'] == updateId);
        
        debugPrint('✅ OfflineSyncService: Mise à jour utilisateur synchronisée - $updateId');
      } catch (e) {
        final updateId = updateData['id'] as String;
        debugPrint('❌ OfflineSyncService: Erreur sync utilisateur $updateId - $e');
        
        // Incrémenter le nombre de tentatives
        await _incrementSyncAttempts('pending_user_updates', updateId);
      }
    }

    if (updatesToSync.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Synchronise les mises à jour panier en attente
  Future<void> _syncPendingCartUpdates() async {
    final updatesToSync = List<Map<String, dynamic>>.from(_pendingCartUpdates);

    for (final updateData in updatesToSync) {
      try {
        final userId = updateData['user_id'] as String;
        final updateId = updateData['id'] as String;
        final operationType = updateData['operation_type'] as String;
        
        if (operationType == 'upsert') {
          // Synchroniser le panier complet
          final items = (updateData['items'] as List)
              .map((item) => CartItem.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          
          await _databaseService.upsertUserCart(
            userId: userId,
            items: items,
            deliveryFee: (updateData['delivery_fee'] as num?)?.toDouble() ?? 500.0,
            discount: (updateData['discount'] as num?)?.toDouble() ?? 0.0,
            promoCode: updateData['promo_code'] as String?,
          );
        }
        
        // Marquer comme synchronisé
        await _database!.update(
          'pending_cart_updates',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [updateId],
        );
        
        // Retirer de la liste en attente
        _pendingCartUpdates.removeWhere((update) => update['id'] == updateId);
        
        debugPrint('✅ OfflineSyncService: Mise à jour panier synchronisée - $updateId');
      } catch (e) {
        final updateId = updateData['id'] as String;
        debugPrint('❌ OfflineSyncService: Erreur sync panier $updateId - $e');
        
        // Incrémenter le nombre de tentatives
        await _incrementSyncAttempts('pending_cart_updates', updateId);
      }
    }

    if (updatesToSync.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Incrémente le nombre de tentatives de synchronisation
  Future<void> _incrementSyncAttempts(String table, String id) async {
    try {
      final result = await _database!.rawQuery(
        'SELECT sync_attempts FROM $table WHERE id = ?',
        [id],
      );
      
      if (result.isNotEmpty) {
        final currentAttempts = result.first['sync_attempts'] as int? ?? 0;
        await _database!.update(
          table,
          {
            'sync_attempts': currentAttempts + 1,
            'last_sync_attempt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        
        // Si trop de tentatives, marquer comme erreur permanente
        if (currentAttempts >= 10) {
          debugPrint('⚠️ OfflineSyncService: Trop de tentatives pour $id, marqué comme erreur');
        }
      }
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur incrément tentatives - $e');
    }
  }

  /// Sauvegarde une commande hors ligne
  Future<void> saveOrderOffline(Order order) async {
    try {
      final orderData = {
        'id': order.id,
        'user_id': order.userId,
        'status': order.status.toString().split('.').last,
        'subtotal': order.subtotal,
        'delivery_fee': order.deliveryFee,
        'discount': order.discount,
        'total': order.total,
        'payment_method': order.paymentMethod.toString().split('.').last,
        'delivery_address': order.deliveryAddress,
        'delivery_notes': order.deliveryNotes ?? '',
        'promo_code': order.promoCode,
        'created_at': order.createdAt.toIso8601String(),
        'items': order.items.map((item) => {
          'menu_item_id': item.menuItemId,
          'menu_item_name': item.menuItemName,
          'name': item.name,
          'category': item.category,
          'menu_item_image': item.menuItemImage,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
        },).toList(),
      };

      // Sauvegarder dans la DB locale
      await _database!.insert(
        'offline_orders',
        {
          'id': order.id,
          'user_id': order.userId,
          'data': json.encode(orderData),
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'synced': 0,
          'sync_attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _pendingOrders.add(orderData);
      
      debugPrint('✅ OfflineSyncService: Commande sauvegardée hors ligne - ${order.id}');
      notifyListeners();
      
      // Essayer de synchroniser immédiatement si en ligne
      if (_isOnline) {
        await _syncPendingOrders();
      }
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur sauvegarde commande - $e');
      rethrow;
    }
  }

  /// Sauvegarde une mise à jour utilisateur hors ligne
  Future<void> saveUserUpdateOffline(String userId, Map<String, dynamic> userData) async {
    try {
      final updateId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final updateData = {
        'id': updateId,
        'user_id': userId,
        ...userData,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Sauvegarder dans la DB locale
      await _database!.insert(
        'pending_user_updates',
        {
          'id': updateId,
          'user_id': userId,
          'data': json.encode(updateData),
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'synced': 0,
          'sync_attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _pendingUserUpdates.add(updateData);
      
      debugPrint('✅ OfflineSyncService: Mise à jour utilisateur sauvegardée hors ligne - $updateId');
      notifyListeners();
      
      // Essayer de synchroniser immédiatement si en ligne
      if (_isOnline) {
        await _syncPendingUserUpdates();
      }
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur sauvegarde utilisateur - $e');
      rethrow;
    }
  }

  /// Sauvegarde une mise à jour panier hors ligne
  Future<void> saveCartUpdateOffline(
    String userId,
    List<CartItem> items,
    double deliveryFee,
    double discount,
    String? promoCode,
  ) async {
    try {
      final updateId = 'cart_${userId}_${DateTime.now().millisecondsSinceEpoch}';
      final updateData = {
        'id': updateId,
        'user_id': userId,
        'operation_type': 'upsert',
        'items': items.map((item) => item.toMap()).toList(),
        'delivery_fee': deliveryFee,
        'discount': discount,
        'promo_code': promoCode,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Sauvegarder dans la DB locale
      await _database!.insert(
        'pending_cart_updates',
        {
          'id': updateId,
          'user_id': userId,
          'data': json.encode(updateData),
          'operation_type': 'upsert',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'synced': 0,
          'sync_attempts': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _pendingCartUpdates.add(updateData);
      
      debugPrint('✅ OfflineSyncService: Mise à jour panier sauvegardée hors ligne - $updateId');
      notifyListeners();
      
      // Essayer de synchroniser immédiatement si en ligne
      if (_isOnline) {
        await _syncPendingCartUpdates();
      }
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur sauvegarde panier - $e');
      rethrow;
    }
  }

  /// Cache le menu localement
  Future<void> cacheMenuItems(List<MenuItem> items) async {
    try {
      _cachedMenuItems = items;
      _menuCacheTime = DateTime.now();
      
      // Sur web, utiliser seulement le cache en mémoire
      if (!_isDatabaseAvailable) {
        debugPrint('✅ OfflineSyncService: Menu mis en cache (mémoire uniquement) - ${items.length} items');
        return;
      }
      
      // Sauvegarder dans la DB locale
      final batch = _database!.batch();
      
      // Supprimer l'ancien cache
      batch.delete('cached_menu_items');
      
      // Ajouter les nouveaux items
      final expiresAt = DateTime.now().add(_cacheValidityDuration).millisecondsSinceEpoch;
      for (final item in items) {
        batch.insert(
          'cached_menu_items',
          {
            'id': item.id,
            'data': json.encode(item.toMap()),
            'category_id': item.category?.id,
            'cached_at': DateTime.now().millisecondsSinceEpoch,
            'expires_at': expiresAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      
      debugPrint('✅ OfflineSyncService: Menu mis en cache - ${items.length} items');
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur cache menu - $e');
    }
  }

  /// Charge le menu depuis le cache local
  Future<List<MenuItem>?> loadCachedMenuItems() async {
    // Sur web, retourner le cache en mémoire si disponible
    if (!_isDatabaseAvailable) {
      if (_cachedMenuItems != null && _menuCacheTime != null) {
        final cacheAge = DateTime.now().difference(_menuCacheTime!);
        if (cacheAge < _cacheValidityDuration) {
          debugPrint('✅ OfflineSyncService: Menu chargé depuis le cache mémoire - ${_cachedMenuItems!.length} items');
          return _cachedMenuItems;
        }
      }
      return null;
    }

    try {
      // Vérifier si le cache en mémoire est valide
      if (_cachedMenuItems != null && _menuCacheTime != null) {
        final cacheAge = DateTime.now().difference(_menuCacheTime!);
        if (cacheAge < _cacheValidityDuration) {
          debugPrint('✅ OfflineSyncService: Menu chargé depuis le cache mémoire');
          return _cachedMenuItems;
        }
      }
      
      // Charger depuis la DB locale
      final cachedData = await _database!.query(
        'cached_menu_items',
        where: 'expires_at > ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
      );
      
      if (cachedData.isEmpty) {
        debugPrint('⚠️ OfflineSyncService: Aucun menu en cache valide');
        return null;
      }
      
      final items = cachedData.map((row) {
        final data = json.decode(row['data'] as String) as Map<String, dynamic>;
        return MenuItem.fromMap(data);
      }).toList();
      
      _cachedMenuItems = items;
      _menuCacheTime = DateTime.now();
      
      debugPrint('✅ OfflineSyncService: Menu chargé depuis le cache DB - ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur chargement cache menu - $e');
      return null;
    }
  }

  /// Cache les catégories localement
  Future<void> cacheCategories(List<MenuCategory> categories) async {
    // Sur web, utiliser seulement le cache en mémoire
    if (!_isDatabaseAvailable) {
      _cachedCategories = categories;
      debugPrint('✅ OfflineSyncService: Catégories mises en cache (mémoire uniquement) - ${categories.length} catégories');
      return;
    }

    try {
      // Filtrer les catégories invalides (avec id, name, displayName ou emoji null/vide)
      final validCategories = categories.where((category) {
        if (category.id.isEmpty) {
          debugPrint('⚠️ OfflineSyncService: Catégorie ignorée - id vide: ${category.name}');
          return false;
        }
        if (category.name.isEmpty) {
          debugPrint('⚠️ OfflineSyncService: Catégorie ignorée - name vide: id=${category.id}');
          return false;
        }
        if (category.displayName.isEmpty) {
          debugPrint('⚠️ OfflineSyncService: Catégorie ignorée - displayName vide: id=${category.id}, name=${category.name}');
          return false;
        }
        if (category.emoji.isEmpty) {
          debugPrint('⚠️ OfflineSyncService: Catégorie ignorée - emoji vide: id=${category.id}, name=${category.name}');
          return false;
        }
        return true;
      }).toList();
      
      if (validCategories.isEmpty) {
        debugPrint('⚠️ OfflineSyncService: Aucune catégorie valide à mettre en cache');
        return;
      }
      
      _cachedCategories = validCategories;
      
      // Sauvegarder dans la DB locale
      final batch = _database!.batch();
      
      // Supprimer l'ancien cache
      batch.delete('cached_categories');
      
      // Ajouter les nouvelles catégories
      final expiresAt = DateTime.now().add(_cacheValidityDuration).millisecondsSinceEpoch;
      for (final category in validCategories) {
        try {
          final categoryMap = category.toMap();
          
          // Vérifier que toMap() ne retourne pas de valeurs null pour les champs requis
          if (categoryMap['id'] == null || categoryMap['id'].toString().isEmpty) {
            debugPrint('⚠️ OfflineSyncService: Catégorie ignorée - id null dans toMap(): ${category.name}');
            continue;
          }
          
          batch.insert(
            'cached_categories',
            {
              'id': category.id,
              'data': json.encode(categoryMap),
              'cached_at': DateTime.now().millisecondsSinceEpoch,
              'expires_at': expiresAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint('⚠️ OfflineSyncService: Erreur lors de l\'insertion de la catégorie ${category.id}: $e');
          // Continuer avec les autres catégories
        }
      }
      
      await batch.commit(noResult: true);
      
      debugPrint('✅ OfflineSyncService: Catégories mises en cache - ${validCategories.length}/${categories.length} catégories valides');
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur cache catégories - $e');
      // Log plus de détails pour le débogage
      if (e.toString().contains('null')) {
        debugPrint('   Détails: Une valeur null a été détectée. Vérifiez les catégories passées.');
        debugPrint('   Nombre de catégories reçues: ${categories.length}');
        for (var i = 0; i < categories.length; i++) {
          final cat = categories[i];
          debugPrint('   Catégorie $i: id=${cat.id}, name=${cat.name}, displayName=${cat.displayName}, emoji=${cat.emoji}');
        }
      }
    }
  }

  /// Charge les catégories depuis le cache local
  Future<List<MenuCategory>?> loadCachedCategories() async {
    // Sur web, retourner le cache en mémoire si disponible
    if (!_isDatabaseAvailable) {
      if (_cachedCategories != null) {
        debugPrint('✅ OfflineSyncService: Catégories chargées depuis le cache mémoire - ${_cachedCategories!.length} catégories');
        return _cachedCategories;
      }
      return null;
    }

    try {
      // Vérifier si le cache en mémoire est valide
      if (_cachedCategories != null) {
        return _cachedCategories;
      }
      
      // Charger depuis la DB locale
      final cachedData = await _database!.query(
        'cached_categories',
        where: 'expires_at > ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
      );
      
      if (cachedData.isEmpty) {
        debugPrint('⚠️ OfflineSyncService: Aucune catégorie en cache valide');
        return null;
      }
      
      final categories = cachedData.map((row) {
        final data = json.decode(row['data'] as String) as Map<String, dynamic>;
        return MenuCategory.fromMap(data);
      }).toList();
      
      _cachedCategories = categories;
      
      debugPrint('✅ OfflineSyncService: Catégories chargées depuis le cache - ${categories.length} catégories');
      return categories;
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur chargement cache catégories - $e');
      return null;
    }
  }

  /// Force la synchronisation immédiate
  Future<void> forceSync() async {
    if (!_isOnline) {
      debugPrint('⚠️ OfflineSyncService: Impossible de synchroniser - hors ligne');
      return;
    }

    debugPrint('🔄 OfflineSyncService: Synchronisation forcée...');
    await _syncPendingData();
  }

  /// Obtient le statut de synchronisation
  Map<String, dynamic> getSyncStatus() {
    return {
      'isOnline': _isOnline,
      'isInitialized': _isInitialized,
      'pendingOrders': _pendingOrders.length,
      'pendingMenuUpdates': _pendingMenuUpdates.length,
      'pendingUserUpdates': _pendingUserUpdates.length,
      'pendingCartUpdates': _pendingCartUpdates.length,
      'totalPending': totalPendingOperations,
      'lastSync': _lastSyncTime?.toIso8601String(),
      'hasCachedMenu': _cachedMenuItems != null,
      'hasCachedCategories': _cachedCategories != null,
    };
  }

  /// Vide le cache local
  Future<void> clearLocalCache() async {
    try {
      await _database!.delete('offline_orders', where: 'synced = ?', whereArgs: [1]);
      await _database!.delete('cached_menu_items');
      await _database!.delete('cached_categories');
      
      _cachedMenuItems = null;
      _cachedCategories = null;
      _menuCacheTime = null;
      
      await _prefs?.remove('last_sync_time');
      
      debugPrint('✅ OfflineSyncService: Cache local vidé');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur vidage cache - $e');
    }
  }

  /// Vide toutes les données (y compris les données en attente)
  Future<void> clearAllData() async {
    try {
      await _database!.delete('offline_orders');
      await _database!.delete('pending_user_updates');
      await _database!.delete('pending_cart_updates');
      await _database!.delete('cached_menu_items');
      await _database!.delete('cached_categories');
      
      _pendingOrders.clear();
      _pendingUserUpdates.clear();
      _pendingCartUpdates.clear();
      _pendingMenuUpdates.clear();
      _cachedMenuItems = null;
      _cachedCategories = null;
      _menuCacheTime = null;
      
      await _prefs?.remove('last_sync_time');
      
      debugPrint('✅ OfflineSyncService: Toutes les données supprimées');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ OfflineSyncService: Erreur suppression données - $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _database?.close();
    super.dispose();
  }
}

