import 'dart:async';
import 'dart:convert';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elcora_fast/models/cart_item.dart';

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
  List<eccore.MenuItem>? _cachedMenuItems;
  List<eccore.Category>? _cachedCategories;
  DateTime? _menuCacheTime;
  static const Duration _cacheValidityDuration = Duration(hours: 24);

  /// Construit à la première écriture distante — même raison que dans
  /// `CartService` : `apiClient` lit le conteneur Riverpod monté par `main()`,
  /// et l'évaluer dans l'initialiseur de champ rendait ce service — donc tout
  /// service qui le tient — inconstructible hors de l'application lancée.
  late final eccore.CartRepository _cartRepository =
      eccore.CartRepository(apiClient: apiClient);

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

  // Clés du catalogue conservé sur disque.
  static const _cleMenuCache = 'catalogue_articles';
  static const _cleCategoriesCache = 'catalogue_categories';
  static const _cleCatalogueDate = 'catalogue_date';

  /// Les préférences, ouvertes à la demande.
  ///
  /// `initialize()` les ouvrait déjà — mais `initialize()` n'est appelée que
  /// par `ServiceInitializer.initializeAllServices`, qui ne figure dans aucun
  /// chemin de démarrage : au lancement réel, `_prefs` restait nul. Le
  /// catalogue mis « en cache » ne quittait donc jamais la mémoire vive, et
  /// disparaissait avec l'onglet. Les méthodes de cache ouvrent désormais le
  /// stockage elles-mêmes.
  Future<SharedPreferences?> _preferences() async {
    try {
      return _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      eccore.Journal.trace('⚠️ OfflineSyncService: préférences indisponibles - $e');
      return null;
    }
  }

  /// Écrit le catalogue sur disque. Sans effet si le stockage est refusé —
  /// c'est un confort de démarrage, jamais une condition de fonctionnement.
  Future<void> _conserverSurDisque(String cle, List<Object?> encodables) async {
    final prefs = await _preferences();
    if (prefs == null) return;
    try {
      await prefs.setString(cle, json.encode(encodables));
      await prefs.setInt(
        _cleCatalogueDate,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      eccore.Journal.trace('⚠️ OfflineSyncService: écriture du cache $cle - $e');
    }
  }

  /// Relit le catalogue depuis le disque, ou `null` s'il est absent ou périmé.
  Future<List<Map<String, dynamic>>?> _relireDuDisque(String cle) async {
    final prefs = await _preferences();
    if (prefs == null) return null;
    try {
      final brut = prefs.getString(cle);
      if (brut == null || brut.isEmpty) return null;

      final ecritLe = prefs.getInt(_cleCatalogueDate);
      if (ecritLe != null) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ecritLe),
        );
        if (age > _cacheValidityDuration) return null;
      }

      return (json.decode(brut) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      eccore.Journal.trace('⚠️ OfflineSyncService: lecture du cache $cle - $e');
      return null;
    }
  }

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
      eccore.Journal.trace('✅ OfflineSyncService: Service initialisé avec succès');
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur d\'initialisation - $e');
      _isInitialized = false;
    }
  }

  /// Initialise le stockage SharedPreferences
  Future<void> _initializeStorage() async {
    _prefs = await SharedPreferences.getInstance();
    eccore.Journal.trace('✅ OfflineSyncService: SharedPreferences initialisé');
  }

  /// Initialise la base de données SQLite locale
  Future<void> _initializeDatabase() async {
    // SQLite n'est pas disponible sur web, utiliser seulement SharedPreferences
    if (kIsWeb) {
      eccore.Journal.trace('⚠️ OfflineSyncService: SQLite non disponible sur web, utilisation de SharedPreferences uniquement');
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

      eccore.Journal.trace('✅ OfflineSyncService: Base de données SQLite initialisée');
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur initialisation DB - $e');
      // Ne pas bloquer l'initialisation sur web, continuer avec SharedPreferences
      if (kIsWeb) {
        _database = null;
        eccore.Journal.trace('⚠️ OfflineSyncService: Continuation avec SharedPreferences uniquement');
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

    eccore.Journal.trace('✅ OfflineSyncService: Tables créées');
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
        eccore.Journal.trace('⚠️ OfflineSyncService: Colonnes déjà présentes ou erreur: $e');
      }
    }
  }

  /// Charge les données stockées localement
  Future<void> _loadStoredData() async {
    if (!_isDatabaseAvailable) {
      eccore.Journal.trace('⚠️ OfflineSyncService: Base de données non disponible, chargement depuis SharedPreferences uniquement');
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

      eccore.Journal.trace('✅ OfflineSyncService: Données chargées - ${_pendingOrders.length} commandes, ${_pendingUserUpdates.length} updates utilisateur, ${_pendingCartUpdates.length} updates panier');
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur de chargement des données - $e');
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
        eccore.Journal.trace('📡 OfflineSyncService: Connectivité changée - ${_isOnline ? "En ligne" : "Hors ligne"}');
        
        if (_isOnline && !wasOnline) {
          // Connexion restaurée, synchroniser immédiatement
          eccore.Journal.trace('🔄 OfflineSyncService: Connexion restaurée, synchronisation en cours...');
          await _syncPendingData();
        }
        
        notifyListeners();
      }
    } catch (e) {
      _isOnline = false;
      eccore.Journal.trace('❌ OfflineSyncService: Erreur de vérification de connectivité - $e');
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
          eccore.Journal.trace('📡 OfflineSyncService: Connectivité changée - ${_isOnline ? "En ligne" : "Hors ligne"}');
          
          if (_isOnline && !wasOnline) {
            // Connexion restaurée, synchroniser immédiatement
            eccore.Journal.trace('🔄 OfflineSyncService: Connexion restaurée, synchronisation en cours...');
            await _syncPendingData();
          }
          
          notifyListeners();
        }
      },
      onError: (error) {
        eccore.Journal.trace('❌ OfflineSyncService: Erreur écoute connectivité - $error');
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
      eccore.Journal.trace('🔄 OfflineSyncService: Début de la synchronisation...');
      
      // Synchroniser les mises à jour panier
      await _syncPendingCartUpdates();
      
      // Mettre à jour le timestamp de dernière synchronisation
      _lastSyncTime = DateTime.now();
      await _prefs?.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
      
      eccore.Journal.trace('✅ OfflineSyncService: Synchronisation terminée');
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur de synchronisation - $e');
    }
  }

  /// Synchronise les mises à jour panier en attente
  Future<void> _syncPendingCartUpdates() async {
    final updatesToSync = List<Map<String, dynamic>>.from(_pendingCartUpdates);

    for (final updateData in updatesToSync) {
      try {
        // `user_id` n'est plus lu : le panier serveur est celui du porteur du
        // jeton, il ne se désigne pas.
        final updateId = updateData['id'] as String;
        final operationType = updateData['operation_type'] as String;
        
        if (operationType == 'upsert') {
          // Synchroniser le panier complet
          final items = (updateData['items'] as List)
              .map((item) => CartItem.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          
          // Réécriture intégrale du panier serveur, comme `CartService` :
          // il n'existe pas de correspondance stable entre l'identifiant
          // local d'une ligne et celui de Django.
          //
          // Ni frais de livraison, ni remise, ni code promo ne sont rejoués :
          // le serveur les recalcule au devis de commande (C1). Les envoyer
          // reviendrait à laisser le client fixer ce qu'il paie.
          //
          // Les options retenues et la note, elles, sont rejouées : ce sont
          // des **choix** du client, pas des montants. Les taire ferait
          // repartir un gâteau sur mesure composé hors ligne avec sa seule
          // recette de base.
          await _cartRepository.clear(restaurantSlug: AppConstants.restaurantSlug);
          for (final item in items) {
            await _cartRepository.addLine(
              restaurantSlug: AppConstants.restaurantSlug,
              menuItemId: item.menuItemId,
              quantity: item.quantity,
              optionIds: item.selectedOptionIds,
              notes: item.remoteNotes,
            );
          }
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
        
        eccore.Journal.trace('✅ OfflineSyncService: Mise à jour panier synchronisée - $updateId');
      } catch (e) {
        final updateId = updateData['id'] as String;
        eccore.Journal.trace('❌ OfflineSyncService: Erreur sync panier $updateId - $e');
        
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
          eccore.Journal.trace('⚠️ OfflineSyncService: Trop de tentatives pour $id, marqué comme erreur');
        }
      }
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur incrément tentatives - $e');
    }
  }

  /// Sauvegarde une commande hors ligne
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
      
      eccore.Journal.trace('✅ OfflineSyncService: Mise à jour panier sauvegardée hors ligne - $updateId');
      notifyListeners();
      
      // Essayer de synchroniser immédiatement si en ligne
      if (_isOnline) {
        await _syncPendingCartUpdates();
      }
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur sauvegarde panier - $e');
      rethrow;
    }
  }

  /// Cache le menu localement
  Future<void> cacheMenuItems(List<eccore.MenuItem> items) async {
    try {
      _cachedMenuItems = items;
      _menuCacheTime = DateTime.now();
      
      // Pas de SQLite sur le web : le catalogue va dans les préférences, qui
      // elles survivent au rechargement de l'onglet.
      if (!_isDatabaseAvailable) {
        await _conserverSurDisque(
          _cleMenuCache,
          items.map((item) => item.toJson()).toList(),
        );
        eccore.Journal.trace('✅ OfflineSyncService: Menu mis en cache - ${items.length} items');
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
            'data': json.encode(item.toJson()),
            'category_id': item.categorySlug,
            'cached_at': DateTime.now().millisecondsSinceEpoch,
            'expires_at': expiresAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
      
      eccore.Journal.trace('✅ OfflineSyncService: Menu mis en cache - ${items.length} items');
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur cache menu - $e');
    }
  }

  /// Charge le menu depuis le cache local
  Future<List<eccore.MenuItem>?> loadCachedMenuItems() async {
    // Mémoire d'abord, disque ensuite : le premier démarrage d'un onglet n'a
    // rien en mémoire, et c'est précisément là que le repli compte.
    if (!_isDatabaseAvailable) {
      if (_cachedMenuItems != null && _menuCacheTime != null) {
        final cacheAge = DateTime.now().difference(_menuCacheTime!);
        if (cacheAge < _cacheValidityDuration) {
          eccore.Journal.trace('✅ OfflineSyncService: Menu chargé depuis le cache mémoire - ${_cachedMenuItems!.length} items');
          return _cachedMenuItems;
        }
      }

      final conserves = await _relireDuDisque(_cleMenuCache);
      if (conserves == null || conserves.isEmpty) return null;
      try {
        final items = conserves.map(eccore.MenuItem.fromJson).toList();
        _cachedMenuItems = items;
        _menuCacheTime = DateTime.now();
        eccore.Journal.trace('✅ OfflineSyncService: Menu relu sur disque - ${items.length} items');
        return items;
      } catch (e) {
        eccore.Journal.trace('❌ OfflineSyncService: cache menu illisible - $e');
        return null;
      }
    }

    try {
      // Vérifier si le cache en mémoire est valide
      if (_cachedMenuItems != null && _menuCacheTime != null) {
        final cacheAge = DateTime.now().difference(_menuCacheTime!);
        if (cacheAge < _cacheValidityDuration) {
          eccore.Journal.trace('✅ OfflineSyncService: Menu chargé depuis le cache mémoire');
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
        eccore.Journal.trace('⚠️ OfflineSyncService: Aucun menu en cache valide');
        return null;
      }
      
      final items = cachedData.map((row) {
        final data = json.decode(row['data'] as String) as Map<String, dynamic>;
        return eccore.MenuItem.fromJson(data);
      }).toList();
      
      _cachedMenuItems = items;
      _menuCacheTime = DateTime.now();
      
      eccore.Journal.trace('✅ OfflineSyncService: Menu chargé depuis le cache DB - ${items.length} items');
      return items;
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur chargement cache menu - $e');
      return null;
    }
  }

  /// Cache les catégories localement
  Future<void> cacheCategories(List<eccore.Category> categories) async {
    // Idem : sur le web les catégories vont dans les préférences.
    if (!_isDatabaseAvailable) {
      _cachedCategories = categories;
      await _conserverSurDisque(
        _cleCategoriesCache,
        categories.map((c) => c.toJson()).toList(),
      );
      eccore.Journal.trace('✅ OfflineSyncService: Catégories mises en cache - ${categories.length} catégories');
      return;
    }

    try {
      // Filtrer les catégories invalides (avec id, name, displayName ou emoji null/vide)
      final validCategories = categories.where((category) {
        if (category.id.isEmpty) {
          eccore.Journal.trace('⚠️ OfflineSyncService: Catégorie ignorée - id vide: ${category.name}');
          return false;
        }
        if (category.name.isEmpty) {
          eccore.Journal.trace('⚠️ OfflineSyncService: Catégorie ignorée - name vide: id=${category.id}');
          return false;
        }
        // L'emoji ne conditionne plus la mise en cache. Une catégorie qui n'en
        // a pas disparaissait purement et simplement du mode hors ligne — un
        // champ décoratif faisait perdre des données.
        //
        // Il n'en conditionne plus l'affichage non plus : l'illustration se
        // choisit désormais sur le **slug** (`CategorieAffichee.illustration`).
        // Le champ reste mis en cache tel que le serveur le rend, sans
        // réécriture — les entrées déjà rangées se relisent à l'identique.
        return true;
      }).toList();
      
      if (validCategories.isEmpty) {
        eccore.Journal.trace('⚠️ OfflineSyncService: Aucune catégorie valide à mettre en cache');
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
          final categoryMap = category.toJson();
          
          // Vérifier que toMap() ne retourne pas de valeurs null pour les champs requis
          if (categoryMap['id'] == null || categoryMap['id'].toString().isEmpty) {
            eccore.Journal.trace('⚠️ OfflineSyncService: Catégorie ignorée - id null dans toMap(): ${category.name}');
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
          eccore.Journal.trace('⚠️ OfflineSyncService: Erreur lors de l\'insertion de la catégorie ${category.id}: $e');
          // Continuer avec les autres catégories
        }
      }
      
      await batch.commit(noResult: true);
      
      eccore.Journal.trace('✅ OfflineSyncService: Catégories mises en cache - ${validCategories.length}/${categories.length} catégories valides');
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur cache catégories - $e');
      // Log plus de détails pour le débogage
      if (e.toString().contains('null')) {
        eccore.Journal.trace('   Détails: Une valeur null a été détectée. Vérifiez les catégories passées.');
        eccore.Journal.trace('   Nombre de catégories reçues: ${categories.length}');
        for (var i = 0; i < categories.length; i++) {
          final cat = categories[i];
          eccore.Journal.trace('   Catégorie $i: id=${cat.id}, name=${cat.name}, displayName=${cat.name}, emoji=${cat.emoji}');
        }
      }
    }
  }

  /// Charge les catégories depuis le cache local
  Future<List<eccore.Category>?> loadCachedCategories() async {
    if (!_isDatabaseAvailable) {
      if (_cachedCategories != null) {
        eccore.Journal.trace('✅ OfflineSyncService: Catégories chargées depuis le cache mémoire - ${_cachedCategories!.length} catégories');
        return _cachedCategories;
      }

      final conservees = await _relireDuDisque(_cleCategoriesCache);
      if (conservees == null || conservees.isEmpty) return null;
      try {
        final categories = conservees.map(eccore.Category.fromJson).toList();
        _cachedCategories = categories;
        eccore.Journal.trace('✅ OfflineSyncService: Catégories relues sur disque - ${categories.length}');
        return categories;
      } catch (e) {
        eccore.Journal.trace('❌ OfflineSyncService: cache catégories illisible - $e');
        return null;
      }
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
        eccore.Journal.trace('⚠️ OfflineSyncService: Aucune catégorie en cache valide');
        return null;
      }
      
      final categories = cachedData.map((row) {
        final data = json.decode(row['data'] as String) as Map<String, dynamic>;
        return eccore.Category.fromJson(data);
      }).toList();
      
      _cachedCategories = categories;
      
      eccore.Journal.trace('✅ OfflineSyncService: Catégories chargées depuis le cache - ${categories.length} catégories');
      return categories;
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur chargement cache catégories - $e');
      return null;
    }
  }

  /// Force la synchronisation immédiate
  Future<void> forceSync() async {
    if (!_isOnline) {
      eccore.Journal.trace('⚠️ OfflineSyncService: Impossible de synchroniser - hors ligne');
      return;
    }

    eccore.Journal.trace('🔄 OfflineSyncService: Synchronisation forcée...');
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
      
      eccore.Journal.trace('✅ OfflineSyncService: Cache local vidé');
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur vidage cache - $e');
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
      
      eccore.Journal.trace('✅ OfflineSyncService: Toutes les données supprimées');
      notifyListeners();
    } catch (e) {
      eccore.Journal.trace('❌ OfflineSyncService: Erreur suppression données - $e');
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

