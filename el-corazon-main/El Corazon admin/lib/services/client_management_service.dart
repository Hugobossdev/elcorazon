import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import '../models/order.dart';

class ClientManagementService extends ChangeNotifier {
  static final ClientManagementService _instance =
      ClientManagementService._internal();
  factory ClientManagementService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;
  List<User> _clients = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _clientsChannel;
  bool _isInitialized = false;
  bool _isLoadingInProgress = false;

  // Getters
  List<User> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ClientManagementService._internal() {
    // Ne pas charger automatiquement dans le constructeur
    // Le chargement sera déclenché par l'écran quand nécessaire
  }

  /// Initialiser le service (appelé une seule fois)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await loadClients();
    _subscribeToClientsRealtime();
  }

  @override
  void dispose() {
    _clientsChannel?.unsubscribe();
    super.dispose();
  }

  /// S'abonner aux mises à jour en temps réel
  void _subscribeToClientsRealtime() {
    try {
      _clientsChannel = _supabase
          .channel('admin_clients_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'client',
            ),
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final client = User.fromMap(data);
              _clients.insert(0, client);
              notifyListeners();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'role',
              value: 'client',
            ),
            callback: (payload) {
              final data = Map<String, dynamic>.from(payload.newRecord);
              final client = User.fromMap(data);
              final index = _clients.indexWhere((c) => c.id == client.id);
              if (index != -1) {
                _clients[index] = client;
                notifyListeners();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error subscribing to realtime clients: $e');
    }
  }

  /// Charger tous les clients
  Future<void> loadClients({bool force = false}) async {
    // Éviter les appels multiples simultanés
    if (_isLoadingInProgress && !force) {
      debugPrint('ClientManagementService: Chargement déjà en cours, ignoré');
      return;
    }

    try {
      _isLoadingInProgress = true;
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('ClientManagementService: Début du chargement des clients...');
      
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'client')
          .order('created_at', ascending: false);

      debugPrint('ClientManagementService: Réponse reçue, type: ${response.runtimeType}');
      
      final responseList = response as List;
      debugPrint('ClientManagementService: Nombre d\'éléments: ${responseList.length}');

      _clients = responseList
          .map((data) {
            try {
              return User.fromMap(data);
            } catch (e) {
              debugPrint('ClientManagementService: Erreur parsing client: $e, data: $data');
              return null;
            }
          })
          .whereType<User>()
          .toList();

      debugPrint('ClientManagementService: ${_clients.length} clients chargés avec succès');
      
      if (_clients.isEmpty) {
        debugPrint('ClientManagementService: Aucun client trouvé dans la base de données');
        // Vérifier si l'utilisateur est connecté
        final currentUser = _supabase.auth.currentUser;
        debugPrint('ClientManagementService: Utilisateur actuel: ${currentUser?.id ?? "non connecté"}');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      _clients = [];
      debugPrint('ClientManagementService: Erreur chargement clients - $e');
      debugPrint('ClientManagementService: Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      _isLoadingInProgress = false;
      notifyListeners();
    }
  }

  /// Rechercher des clients
  Future<List<User>> searchClients(String query) async {
    try {
      if (query.isEmpty) return _clients;

      final response = await _supabase
          .from('users')
          .select('*')
          .eq('role', 'client')
          .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => User.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur recherche clients - $e');
      return [];
    }
  }

  /// Obtenir un client par ID
  Future<User?> getClientById(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .eq('role', 'client')
          .maybeSingle();

      if (response == null) return null;
      return User.fromMap(response);
    } catch (e) {
      debugPrint('ClientManagementService: Erreur récupération client - $e');
      return null;
    }
  }

  /// Charger les statistiques d'un client
  Future<Map<String, dynamic>> getClientStats(String userId) async {
    try {
      // Récupérer les commandes du client
      final ordersResponse = await _supabase
          .from('orders')
          .select('*')
          .eq('user_id', userId);

      final orders = (ordersResponse as List)
          .map((data) => Order.fromMap(data))
          .toList();

      final totalOrders = orders.length;
      final totalSpent = orders
          .where((o) => o.status == OrderStatus.delivered)
          .fold(0.0, (sum, o) => sum + o.total);
      final completedOrders = orders
          .where((o) => o.status == OrderStatus.delivered)
          .length;
      final cancelledOrders = orders
          .where((o) => o.status == OrderStatus.cancelled)
          .length;

      // Récupérer les adresses du client
      final addressesResponse = await _supabase
          .from('addresses')
          .select('*')
          .eq('user_id', userId);

      final addressesCount = (addressesResponse as List).length;

      // Récupérer les statistiques de gamification
      final userResponse = await _supabase
          .from('users')
          .select('loyalty_points, badges')
          .eq('id', userId)
          .maybeSingle();

      final loyaltyPoints = userResponse?['loyalty_points'] as int? ?? 0;
      final badges = userResponse?['badges'] as List? ?? [];

      // Récupérer les achievements
      final achievementsResponse = await _supabase
          .from('user_achievements')
          .select('*')
          .eq('user_id', userId)
          .eq('is_unlocked', true);

      final achievementsCount = (achievementsResponse as List).length;

      // Récupérer les challenges complétés
      final challengesResponse = await _supabase
          .from('user_challenges')
          .select('*')
          .eq('user_id', userId)
          .eq('is_completed', true);

      final challengesCount = (challengesResponse as List).length;

      return {
        'total_orders': totalOrders,
        'total_spent': totalSpent,
        'completed_orders': completedOrders,
        'cancelled_orders': cancelledOrders,
        'average_order_value': totalOrders > 0 ? totalSpent / totalOrders : 0.0,
        'addresses_count': addressesCount,
        'loyalty_points': loyaltyPoints,
        'badges_count': badges.length,
        'achievements_count': achievementsCount,
        'challenges_completed': challengesCount,
        'last_order_date': orders.isNotEmpty
            ? orders.first.orderTime.toIso8601String()
            : null,
      };
    } catch (e) {
      debugPrint('ClientManagementService: Erreur stats client - $e');
      return {
        'total_orders': 0,
        'total_spent': 0.0,
        'completed_orders': 0,
        'cancelled_orders': 0,
        'average_order_value': 0.0,
        'addresses_count': 0,
        'loyalty_points': 0,
        'badges_count': 0,
        'achievements_count': 0,
        'challenges_completed': 0,
        'last_order_date': null,
      };
    }
  }

  /// Obtenir les commandes d'un client
  Future<List<Order>> getClientOrders(String userId, {int? limit}) async {
    try {
      var query = _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      return (response as List)
          .map((data) => Order.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur commandes client - $e');
      return [];
    }
  }

  /// Obtenir les adresses d'un client
  Future<List<Map<String, dynamic>>> getClientAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('addresses')
          .select('*')
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List).map((data) => Map<String, dynamic>.from(data)).toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur adresses client - $e');
      return [];
    }
  }

  /// Obtenir l'historique de fidélité d'un client
  Future<List<Map<String, dynamic>>> getClientLoyaltyHistory(String userId) async {
    try {
      final response = await _supabase
          .from('loyalty_transactions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).map((data) => Map<String, dynamic>.from(data)).toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur historique fidélité - $e');
      return [];
    }
  }

  /// Obtenir les achievements d'un client
  Future<List<Map<String, dynamic>>> getClientAchievements(String userId) async {
    try {
      final response = await _supabase
          .from('user_achievements')
          .select('*, achievements(*)')
          .eq('user_id', userId)
          .order('unlocked_at', ascending: false);

      return (response as List).map((data) {
        return {
          'id': data['achievement_id'],
          'name': data['achievements']?['name'],
          'description': data['achievements']?['description'],
          'icon': data['achievements']?['icon'],
          'points_reward': data['achievements']?['points_reward'],
          'is_unlocked': data['is_unlocked'],
          'progress': data['progress'],
          'unlocked_at': data['unlocked_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur achievements client - $e');
      return [];
    }
  }

  /// Obtenir les badges d'un client
  Future<List<Map<String, dynamic>>> getClientBadges(String userId) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('unlocked_at', ascending: false);

      return (response as List).map((data) {
        return {
          'id': data['badge_id'],
          'title': data['badges']?['title'],
          'description': data['badges']?['description'],
          'icon': data['badges']?['icon'],
          'is_unlocked': data['is_unlocked'],
          'progress': data['progress'],
          'unlocked_at': data['unlocked_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('ClientManagementService: Erreur badges client - $e');
      return [];
    }
  }

  /// Suspendre un client
  Future<bool> suspendClient(String userId, {String? reason}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.from('users').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Recharger les clients
      await loadClients();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ClientManagementService: Erreur suspension - $e');
      return false;
    }
  }

  /// Réactiver un client
  Future<bool> reactivateClient(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.from('users').update({
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Recharger les clients
      await loadClients();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ClientManagementService: Erreur réactivation - $e');
      return false;
    }
  }

  /// Mettre à jour les points de fidélité d'un client
  Future<bool> updateClientLoyaltyPoints(String userId, int points, {String? reason}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Récupérer les points actuels
      final userResponse = await _supabase
          .from('users')
          .select('loyalty_points')
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        _error = 'Client non trouvé';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final currentPoints = userResponse['loyalty_points'] as int? ?? 0;
      final newPoints = currentPoints + points;

      // Mettre à jour les points
      await _supabase.from('users').update({
        'loyalty_points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Enregistrer la transaction
      await _supabase.from('loyalty_transactions').insert({
        'user_id': userId,
        'transaction_type': points > 0 ? 'earn' : 'adjustment',
        'points': points.abs(),
        'description': reason ?? 'Ajustement manuel par l\'administrateur',
        'metadata': {
          'adjusted_by': 'admin',
          'reason': reason,
        },
      });

      // Recharger les clients
      await loadClients();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ClientManagementService: Erreur mise à jour points - $e');
      return false;
    }
  }

  /// Mettre à jour le profil d'un client
  Future<bool> updateClientProfile(String userId, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('users').update(updates).eq('id', userId);

      // Recharger les clients
      await loadClients();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ClientManagementService: Erreur mise à jour profil - $e');
      return false;
    }
  }

  /// Obtenir les statistiques globales des clients
  Future<Map<String, dynamic>> getGlobalClientStats() async {
    try {
      // Compter tous les clients
      final totalClientsResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'client');

      // Compter les clients actifs
      final activeClientsResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'client')
          .eq('is_active', true);

      // Compter les clients avec des commandes
      final clientsWithOrders = await _supabase
          .from('orders')
          .select('user_id')
          .eq('status', 'delivered');

      final uniqueClientsWithOrders = (clientsWithOrders as List)
          .map((o) => o['user_id'])
          .toSet()
          .length;

      // Calculer le revenu total des clients
      final revenueResponse = await _supabase
          .from('orders')
          .select('total')
          .eq('status', 'delivered');

      final totalRevenue = (revenueResponse as List)
          .fold<double>(0.0, (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0.0));

      // Calculer la moyenne des points de fidélité
      final loyaltyResponse = await _supabase
          .from('users')
          .select('loyalty_points')
          .eq('role', 'client');

      final loyaltyPoints = (loyaltyResponse as List)
          .map((u) => u['loyalty_points'] as int? ?? 0)
          .toList();

      final avgLoyaltyPoints = loyaltyPoints.isNotEmpty
          ? loyaltyPoints.reduce((a, b) => a + b) / loyaltyPoints.length
          : 0.0;

      final totalClients = (totalClientsResponse as List).length;
      final activeClients = (activeClientsResponse as List).length;

      return {
        'total_clients': totalClients,
        'active_clients': activeClients,
        'inactive_clients': totalClients - activeClients,
        'clients_with_orders': uniqueClientsWithOrders,
        'total_revenue': totalRevenue,
        'average_loyalty_points': avgLoyaltyPoints,
        'average_revenue_per_client': uniqueClientsWithOrders > 0
            ? totalRevenue / uniqueClientsWithOrders
            : 0.0,
      };
    } catch (e) {
      debugPrint('ClientManagementService: Erreur stats globales - $e');
      return {};
    }
  }

  /// Filtrer les clients par statut
  List<User> filterClientsByStatus(bool isActive) {
    return _clients.where((client) {
      // Note: Le modèle User pourrait ne pas avoir isActive, ajuster selon le modèle
      return true; // Placeholder - ajuster selon le modèle User
    }).toList();
  }

  /// Vérifier si un client a un abonnement VIP actif
  Future<bool> hasActiveVIPSubscription(String userId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('current_period_end, status')
          .eq('user_id', userId)
          .eq('subscription_type', 'vip')
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return false;

      final endDate = DateTime.parse(response['current_period_end'] as String);
      return endDate.isAfter(DateTime.now());
    } catch (e) {
      debugPrint('ClientManagementService: Erreur vérification VIP - $e');
      return false;
    }
  }

  /// Rafraîchir les clients
  Future<void> refresh() async {
    await loadClients(force: true);
  }
}
