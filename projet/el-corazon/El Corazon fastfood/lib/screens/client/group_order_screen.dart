import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/social_service.dart';
import 'package:elcora_fast/services/group_delivery_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/services/paydunya_service.dart';

class GroupOrderScreen extends StatefulWidget {
  const GroupOrderScreen({super.key});

  @override
  State<GroupOrderScreen> createState() => _GroupOrderScreenState();
}

class _GroupOrderScreenState extends State<GroupOrderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  Map<String, dynamic>? _currentGroup;
  List<User> _groupMembers = [];
  List<OrderItem> _groupItems = [];
  bool _isCreatingGroup = false;
  String? _activeGroupOrderId;
  String _currentFilter = 'all';
  List<MenuItem> _filteredMenuItems = [];
  DateTime? _orderDeadline; // Limite de temps pour rejoindre la commande
  Timer?
      _deadlineTimer; // Timer pour mettre à jour l'affichage du temps restant

  // Realtime subscriptions
  RealtimeChannel? _orderSubscription;
  RealtimeChannel? _orderItemsSubscription;
  RealtimeChannel? _groupMembersSubscription;

  // Nearby groups
  List<GroupDeliveryRequest> _nearbyGroups = [];
  bool _isLoadingNearbyGroups = false;
  GoogleMapController? _mapController;
  Set<Marker> _nearbyMarkers = {};
  LatLng? _userLocation;

  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentGroup();
    _loadNearbyGroups();

    // Initialiser les services de groupes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) return;
      try {
        if (!mounted || !context.mounted) return;
        await Provider.of<SocialService>(context, listen: false).initialize();
        if (!mounted || !context.mounted) return;
        await Provider.of<GroupDeliveryService>(context, listen: false)
            .initialize();
      } catch (e) {
        debugPrint('Error initializing group services: $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    _orderSubscription?.unsubscribe();
    _orderItemsSubscription?.unsubscribe();
    _groupMembersSubscription?.unsubscribe();
    _deadlineTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startDeadlineTimer() {
    _deadlineTimer?.cancel();

    // Mettre à jour toutes les secondes si une deadline existe
    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_orderDeadline != null && mounted) {
        final now = DateTime.now();
        if (now.isAfter(_orderDeadline!)) {
          // La deadline est passée
          timer.cancel();
          setState(() {
            _orderDeadline = null;
          });
        } else {
          // Mettre à jour l'affichage
          setState(() {});
        }
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTimeRemaining() {
    if (_orderDeadline == null) return '';

    final now = DateTime.now();
    if (now.isAfter(_orderDeadline!)) {
      return 'Temps écoulé';
    }

    final remaining = _orderDeadline!.difference(now);
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _loadCurrentGroup() async {
    try {
      final appService = context.read<AppService>();
      final currentUser = appService.currentUser;
      if (currentUser == null) return;

      // Charger les groupes de l'utilisateur
      final groups = await _databaseService.supabase
          .from('social_groups')
          .select('''
            *,
            group_members!inner(*)
          ''')
          .eq('group_members.user_id', currentUser.id)
          .eq('is_active', true);

      if (groups.isNotEmpty) {
        final group = groups.first;
        final membersData = group['group_members'] as List;

        setState(() {
          _currentGroup = {
            'id': group['id'],
            'name': group['name'],
            'inviteCode': group['invite_code'],
            'creatorId': group['creator_id'],
            'createdAt': DateTime.parse(group['created_at']),
          };

          _groupMembers = membersData.map((member) {
            final memberData = member as Map<String, dynamic>;
            return User(
              id: memberData['user_id'] ?? '',
              name: memberData['name'] ?? 'Membre',
              email: memberData['email'] ?? '',
              phone: memberData['phone'] ?? '',
              role: UserRole.client,
              createdAt: DateTime.now(),
            );
          }).toList();
        });

        // Charger la commande groupée active si elle existe
        await _loadActiveGroupOrder();

        // Démarrer le timer pour la limite de temps
        _startDeadlineTimer();

        // Configurer l'abonnement aux membres du groupe
        _setupGroupMembersSubscription();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement du groupe: $e');
    }
  }

  Future<void> _loadNearbyGroups() async {
    if (_currentGroup != null) return; // Ne pas charger si déjà dans un groupe

    setState(() {
      _isLoadingNearbyGroups = true;
    });

    try {
      // Obtenir la position de l'utilisateur
      try {
        final location = await _locationService.getCurrentLocation();
        if (location != null) {
          _userLocation = LatLng(location.latitude, location.longitude);
        }
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la récupération de la position: $e');
      }

      final appService = context.read<AppService>();
      final currentUser = appService.currentUser;
      if (currentUser == null) return;

      final groupDeliveryService = context.read<GroupDeliveryService>();
      await groupDeliveryService.initialize();

      // Charger les groupes disponibles
      final addressService = context.read<AddressService>();
      final address = addressService.selectedAddress?.address ??
          addressService.defaultAddress?.address ??
          'Abidjan, Côte d\'Ivoire';
      final nearbyGroups = await groupDeliveryService.findNearbyRequests(
        address,
        maxDistance: 2000, // 2km
        userLatitude: _userLocation?.latitude,
        userLongitude: _userLocation?.longitude,
      );

      // Filtrer les groupes auxquels l'utilisateur ne participe pas déjà
      final filteredGroups = nearbyGroups.where((group) {
        return !group.joinedUserIds.contains(currentUser.id);
      }).toList();

      setState(() {
        _nearbyGroups = filteredGroups;
        _isLoadingNearbyGroups = false;
      });

      // Mettre à jour les marqueurs sur la carte
      _updateNearbyMarkers();
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement des groupes disponibles: $e');
      setState(() {
        _isLoadingNearbyGroups = false;
      });
    }
  }

  void _updateNearbyMarkers() {
    final Set<Marker> markers = {};

    // Marqueur de l'utilisateur
    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Votre position'),
        ),
      );
    }

    // Marqueurs des groupes disponibles
    for (int i = 0; i < _nearbyGroups.length; i++) {
      final group = _nearbyGroups[i];
      if (group.deliveryLatitude != null && group.deliveryLongitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('group_${group.id}'),
            position: LatLng(group.deliveryLatitude!, group.deliveryLongitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Groupe disponible',
              snippet: '${group.joinedUserIds.length} participant(s)',
            ),
            onTap: () {
              _showGroupDetailsDialog(group);
            },
          ),
        );
      }
    }

    setState(() {
      _nearbyMarkers = markers;
    });

    // Ajuster la caméra pour voir tous les marqueurs
    if (_mapController != null && markers.length > 1) {
      final bounds = _calculateBounds(markers.map((m) => m.position).toList());
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else if (_mapController != null && _userLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 13),
      );
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _loadActiveGroupOrder() async {
    if (_currentGroup == null) return;

    try {
      // Chercher une commande groupée active pour ce groupe
      final orders = await _databaseService.supabase
          .from('orders')
          .select('id, order_items(*)')
          .eq('group_id', _currentGroup!['id'])
          .eq('is_group_order', true)
          .or('status.eq.pending,status.eq.collecting')
          .order('created_at', ascending: false)
          .limit(1);

      if (orders.isNotEmpty) {
        final order = orders.first;
        _activeGroupOrderId = order['id'] as String;

        // Charger la deadline si elle existe
        if (order['estimated_delivery_time'] != null) {
          _orderDeadline = DateTime.parse(
            order['estimated_delivery_time'] as String,
          ).subtract(
            const Duration(
              minutes: 15,
            ),
          ); // 15 minutes avant la livraison pour la deadline
          _startDeadlineTimer();
        }

        // Charger les items de la commande
        final itemsData = order['order_items'] as List? ?? [];
        _groupItems = itemsData.map((item) {
          final itemData = item as Map<String, dynamic>;
          return OrderItem(
            menuItemId: itemData['menu_item_id'] ?? '',
            menuItemName: itemData['menu_item_name'] ?? itemData['name'] ?? '',
            name: itemData['name'] ?? '',
            category: itemData['category'] ?? 'Non catégorisé',
            menuItemImage: itemData['menu_item_image'] ?? '',
            quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (itemData['unit_price'] as num?)?.toDouble() ?? 0.0,
            totalPrice: (itemData['total_price'] as num?)?.toDouble() ?? 0.0,
            customizations: itemData['customizations'] is Map
                ? Map<String, String>.from(
                    (itemData['customizations'] as Map).map(
                      (key, value) =>
                          MapEntry(key.toString(), value.toString()),
                    ),
                  )
                : {},
            notes: itemData['notes']?.toString(),
          );
        }).toList();

        setState(() {});
        debugPrint(
          '✅ Commande groupée active chargée: $_activeGroupOrderId avec ${_groupItems.length} items',
        );

        // Configurer les abonnements temps réel
        _setupRealtimeSubscription();
        _setupGroupMembersSubscription();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement de la commande groupée: $e');
    }
  }

  void _setupRealtimeSubscription() {
    if (_activeGroupOrderId == null) return;

    // Se désabonner des anciens canaux si nécessaire
    _orderItemsSubscription?.unsubscribe();
    _orderSubscription?.unsubscribe();

    debugPrint(
      '📡 Configuration des abonnements temps réel pour la commande: $_activeGroupOrderId',
    );

    // Écouter les changements sur les items de la commande
    _orderItemsSubscription = _databaseService.supabase
        .channel('public:order_items:order_id=eq.$_activeGroupOrderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: _activeGroupOrderId!,
          ),
          callback: (payload) {
            debugPrint(
              '🔄 Changement détecté sur les items: ${payload.eventType}',
            );
            _refreshOrderItems();
          },
        )
        .subscribe();

    // Écouter les changements sur la commande elle-même (statut, total)
    _orderSubscription = _databaseService.supabase
        .channel('public:orders:id=eq.$_activeGroupOrderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _activeGroupOrderId!,
          ),
          callback: (payload) {
            debugPrint(
              '🔄 Changement détecté sur la commande: ${payload.eventType}',
            );
            // Si le statut change, on pourrait vouloir recharger ou notifier
            if (payload.newRecord['status'] != payload.oldRecord['status']) {
              // Gérer le changement de statut (ex: confirmé)
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Statut de la commande mis à jour: ${payload.newRecord['status']}',
                    ),
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  void _setupGroupMembersSubscription() {
    if (_currentGroup == null) return;

    // Se désabonner de l'ancien canal si nécessaire
    _groupMembersSubscription?.unsubscribe();

    debugPrint(
      '📡 Configuration de l\'abonnement temps réel pour les membres du groupe: ${_currentGroup!['id']}',
    );

    // Écouter les changements sur les membres du groupe
    _groupMembersSubscription = _databaseService.supabase
        .channel('public:group_members:group_id=eq.${_currentGroup!['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: _currentGroup!['id'],
          ),
          callback: (payload) {
            debugPrint(
              '🔄 Changement détecté sur les membres: ${payload.eventType}',
            );

            if (payload.eventType == PostgresChangeEvent.insert) {
              // Nouveau membre ajouté
              final newMemberData = payload.newRecord;
              final memberName =
                  newMemberData['name'] as String? ?? 'Un nouveau membre';

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.person_add, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('$memberName a rejoint le groupe'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              // Membre retiré
              final oldMemberData = payload.oldRecord;
              final memberName =
                  oldMemberData['name'] as String? ?? 'Un membre';

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.person_remove, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('$memberName a quitté le groupe'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }

            // Recharger les membres du groupe
            _loadCurrentGroup();
          },
        )
        .subscribe();
  }

  Future<void> _refreshOrderItems() async {
    if (_activeGroupOrderId == null) return;
    try {
      final itemsResponse = await _databaseService.supabase
          .from('order_items')
          .select()
          .eq('order_id', _activeGroupOrderId!);

      final itemsData = itemsResponse as List? ?? [];

      if (mounted) {
        setState(() {
          _groupItems = itemsData.map((item) {
            final itemData = item as Map<String, dynamic>;
            return OrderItem(
              menuItemId: itemData['menu_item_id'] ?? '',
              menuItemName:
                  itemData['menu_item_name'] ?? itemData['name'] ?? '',
              name: itemData['name'] ?? '',
              category: itemData['category'] ?? 'Non catégorisé',
              menuItemImage: itemData['menu_item_image'] ?? '',
              quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
              unitPrice: (itemData['unit_price'] as num?)?.toDouble() ?? 0.0,
              totalPrice: (itemData['total_price'] as num?)?.toDouble() ?? 0.0,
              customizations: itemData['customizations'] is Map
                  ? Map<String, String>.from(
                      (itemData['customizations'] as Map).map(
                        (key, value) =>
                            MapEntry(key.toString(), value.toString()),
                      ),
                    )
                  : {},
              notes: itemData['notes']?.toString(),
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du rafraîchissement des items: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes Groupées'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Mon Groupe'),
            Tab(icon: Icon(Icons.map), text: 'Groupes'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Panier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupTab(),
          _buildNearbyGroupsTab(),
          _buildMenuTab(),
          _buildCartTab(),
        ],
      ),
    );
  }

  Widget _buildGroupTab() {
    if (_currentGroup == null) {
      return _buildCreateJoinGroup();
    }

    return _buildCurrentGroup();
  }

  Widget _buildCreateJoinGroup() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Créer un groupe
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_add, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Créer un groupe',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      hintText: 'Ex: Famille Dupont',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreatingGroup ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isCreatingGroup
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Créer le groupe'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Rejoindre un groupe
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Rejoindre un groupe',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inviteCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Code d\'invitation',
                      hintText: 'Entrez le code du groupe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _joinGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Rejoindre'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentGroup() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informations du groupe
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentGroup!['name'],
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Code: ${_currentGroup!['inviteCode']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_groupMembers.length} membre(s) • Total: ${PriceFormatter.format(_calculateGroupTotal())}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Membres du groupe
          Text(
            'Membres du groupe',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: _groupMembers.length,
              itemBuilder: (context, index) {
                final member = _groupMembers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(member.name),
                    subtitle: Text(member.email),
                    trailing: member.id == _currentGroup!['creatorId']
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Organisateur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Actions du groupe
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareGroupCode,
                  icon: const Icon(Icons.share),
                  label: const Text('Partager'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _leaveGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Quitter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyGroupsTab() {
    if (_currentGroup != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Vous êtes déjà dans un groupe',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Quittez votre groupe actuel pour voir les groupes disponibles',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Vue carte/liste toggle
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _loadNearbyGroups(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Carte ou liste
        Expanded(
          child: _isLoadingNearbyGroups
              ? const Center(child: CircularProgressIndicator())
              : _nearbyGroups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_off,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun groupe disponible',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Il n\'y a pas de groupes disponibles à proximité pour le moment',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Carte
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _userLocation == null
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Obtention de votre position...',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _userLocation!,
                                        zoom: 13,
                                      ),
                                      markers: _nearbyMarkers,
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                        _updateNearbyMarkers();
                                      },
                                      myLocationEnabled: true,
                                    ),
                            ),
                          ),
                        ),

                        // Liste des groupes
                        Expanded(
                          flex: 3,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _nearbyGroups.length,
                            itemBuilder: (context, index) {
                              final group = _nearbyGroups[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                child: InkWell(
                                  onTap: () => _showGroupDetailsDialog(group),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.group,
                                                color: AppColors.primary,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Groupe de livraison',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${group.joinedUserIds.length} participant(s)',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          )
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                group.deliveryAddress,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Livraison prévue: ${_formatDeliveryTime(group.preferredTime)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.local_shipping,
                                              size: 16,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Frais partagés: ${PriceFormatter.format(group.sharedDeliveryCost)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.success,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  String _formatDeliveryTime(DateTime time) {
    final now = DateTime.now();
    final difference = time.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} jour(s)';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure(s)';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s)';
    } else {
      return 'Bientôt';
    }
  }

  void _showGroupDetailsDialog(GroupDeliveryRequest group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails du groupe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                Icons.group,
                'Participants',
                '${group.joinedUserIds.length} personne(s)',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.location_on,
                'Adresse de livraison',
                group.deliveryAddress,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.access_time,
                'Livraison prévue',
                _formatDeliveryTime(group.preferredTime),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.local_shipping,
                'Frais de livraison partagés',
                PriceFormatter.format(group.sharedDeliveryCost),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.timer,
                'Expire dans',
                _formatTimeRemainingForGroup(group.expiresAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinNearbyGroup(group);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeRemainingForGroup(DateTime expiresAt) {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return 'Expiré';
    }

    final remaining = expiresAt.difference(now);
    if (remaining.inMinutes > 60) {
      return '${remaining.inHours} heure(s)';
    } else {
      return '${remaining.inMinutes} minute(s)';
    }
  }

  Future<void> _joinNearbyGroup(GroupDeliveryRequest group) async {
    try {
      final appService = context.read<AppService>();
      final currentUser = appService.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous devez être connecté'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Afficher un indicateur de chargement
      if (mounted && context.mounted) {
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Rejoindre le groupe via le code d'invitation
      // Le group.id correspond au group_id dans la table orders
      // On doit trouver le groupe social correspondant
      final socialService = context.read<SocialService>();

      // Chercher le groupe social via le group_id des commandes
      // On prend la première commande du groupe pour obtenir le group_id
      final orderData = await _databaseService.supabase
          .from('orders')
          .select('group_id')
          .eq('group_id', group.id)
          .eq('is_group_order', true)
          .limit(1)
          .maybeSingle();

      if (orderData == null || orderData['group_id'] == null) {
        // Fermer le dialog de chargement
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe introuvable dans les commandes'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final groupId = orderData['group_id'] as String;

      // Chercher le groupe social correspondant
      final groupData = await _databaseService.supabase
          .from('social_groups')
          .select('invite_code')
          .eq('id', groupId)
          .maybeSingle();

      if (groupData != null) {
        final inviteCode = groupData['invite_code'] as String;
        final success = await socialService.joinFamilyGroupByCode(
          inviteCode,
          currentUser.id,
        );

        // Fermer le dialog de chargement
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }

        if (success) {
          // Recharger le groupe actuel
          await _loadCurrentGroup();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vous avez rejoint le groupe avec succès!'),
                backgroundColor: AppColors.success,
              ),
            );

            // Changer d'onglet pour voir le groupe
            _tabController.animateTo(0);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de rejoindre le groupe'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        // Fermer le dialog de chargement
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe introuvable'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la jonction au groupe: $e');
      if (mounted && context.mounted) {
        Navigator.of(context).pop(); // Fermer le dialog de chargement
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildMenuTab() {
    final appService = context.read<AppService>();
    final allMenuItems = appService.menuItems;

    // Utiliser les items filtrés si disponibles, sinon tous les items
    final menuItems = _filteredMenuItems.isNotEmpty && _currentFilter != 'all'
        ? _filteredMenuItems
        : allMenuItems;

    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) => _applyFilter(value, allMenuItems),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.clear_all,
                          size: 20,
                          color: _currentFilter == 'all'
                              ? AppColors.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tous les items',
                          style: TextStyle(
                            fontWeight: _currentFilter == 'all'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'available',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: _currentFilter == 'available'
                              ? AppColors.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Disponibles uniquement',
                          style: TextStyle(
                            fontWeight: _currentFilter == 'available'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'price_low',
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          size: 20,
                          color: _currentFilter == 'price_low'
                              ? AppColors.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prix croissant',
                          style: TextStyle(
                            fontWeight: _currentFilter == 'price_low'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'price_high',
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: _currentFilter == 'price_high'
                              ? AppColors.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prix décroissant',
                          style: TextStyle(
                            fontWeight: _currentFilter == 'price_high'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'popular',
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 20,
                          color: _currentFilter == 'popular'
                              ? AppColors.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Les plus populaires',
                          style: TextStyle(
                            fontWeight: _currentFilter == 'popular'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Menu items
        Expanded(
          child: menuItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun item ne correspond aux filtres',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _buildMenuItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  void _applyFilter(String filter, List<MenuItem> allMenuItems) {
    setState(() {
      _currentFilter = filter;

      switch (filter) {
        case 'all':
          _filteredMenuItems = [];
          break;
        case 'available':
          _filteredMenuItems =
              allMenuItems.where((item) => item.isAvailable).toList();
          break;
        case 'price_low':
          _filteredMenuItems = List<MenuItem>.from(allMenuItems)
            ..sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'price_high':
          _filteredMenuItems = List<MenuItem>.from(allMenuItems)
            ..sort((a, b) => b.price.compareTo(a.price));
          break;
        case 'popular':
          _filteredMenuItems = List<MenuItem>.from(allMenuItems)
            ..sort((a, b) => b.rating.compareTo(a.rating));
          break;
        default:
          _filteredMenuItems = [];
      }
    });
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.navigateToItemCustomization(
            item,
            onAddToCart: (customizedItem, quantity, customizations) {
              _addToGroupCart(
                customizedItem,
                quantity: quantity,
                customizations: customizations,
              );
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.restaurant),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          PriceFormatter.format(item.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => _addToGroupCart(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(80, 32),
                          ),
                          child: const Text('Ajouter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartTab() {
    return Column(
      children: [
        // Résumé du panier
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Panier du groupe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_groupItems.length} article(s)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (_orderDeadline != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _orderDeadline!.isAfter(DateTime.now())
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: _orderDeadline!.isAfter(DateTime.now())
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Temps restant: ${_formatTimeRemaining()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _orderDeadline!.isAfter(DateTime.now())
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Items du panier
        Expanded(
          child: _groupItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Le panier est vide',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez des articles depuis le menu',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupItems.length + 1, // +1 pour le résumé
                  itemBuilder: (context, index) {
                    // Afficher le résumé en premier
                    if (index == 0) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Résumé de la commande',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_groupItems.length} article(s) • ${_groupMembers.length} membre(s)',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${PriceFormatter.format(_calculateGroupTotal())}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Afficher les items (index - 1 car le résumé est à l'index 0)
                    final item = _groupItems[index - 1];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            item.quantity.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          '${PriceFormatter.format(item.unitPrice)} × ${item.quantity}',
                        ),
                        trailing: Text(
                          PriceFormatter.format(item.totalPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () => _removeFromGroupCart(item),
                      ),
                    );
                  },
                ),
        ),

        // Total et actions
        if (_groupItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total du groupe:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      PriceFormatter.format(_calculateGroupTotal()),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bouton de confirmation pour l'initiateur uniquement
                if (_currentGroup != null && _isCurrentUserInitiator())
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _groupItems.isNotEmpty ? _confirmGroupOrder : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirmer la commande'),
                    ),
                  ),
                if (_currentGroup != null && _isCurrentUserInitiator())
                  const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _currentGroup != null ? _proceedToCheckout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Commander pour le groupe'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _groupItems.isNotEmpty &&
                                _currentGroup != null &&
                                _groupMembers.isNotEmpty
                            ? _openSharedPayment
                            : null,
                        icon: const Icon(Icons.handshake_outlined),
                        label: const Text('Paiement partagé'),
                      ),
                    ),
                    if (_activeGroupOrderId != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => _viewPaymentStatus(),
                        icon: const Icon(Icons.payment),
                        tooltip: 'Voir le statut des paiements',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom pour le groupe'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      final appService = context.read<AppService>();
      final socialService = context.read<SocialService>();
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final groupId = await socialService.createFamilyGroup(
        ownerId: currentUser.id,
        name: _groupNameController.text.trim(),
      );

      if (groupId != null) {
        // Recharger le groupe
        await _loadCurrentGroup();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe créé avec succès!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        throw Exception('Échec de la création du groupe');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du groupe: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGroup = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_inviteCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un code d\'invitation'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final appService = context.read<AppService>();
      final socialService = context.read<SocialService>();
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final success = await socialService.joinFamilyGroupByCode(
        _inviteCodeController.text.trim(),
        currentUser.id,
      );

      if (success) {
        await _loadCurrentGroup();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous avez rejoint le groupe avec succès!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code invalide ou erreur lors de la connexion'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la connexion au groupe: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addToGroupCart(
    MenuItem item, {
    int quantity = 1,
    Map<String, dynamic>? customizations,
  }) async {
    // Si pas de groupe, impossible d'ajouter
    if (_currentGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord rejoindre ou créer un groupe'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Si pas de commande active, en créer une automatiquement
      if (_activeGroupOrderId == null) {
        try {
          final socialService = context.read<SocialService>();
          final appService = context.read<AppService>();
          final currentUser = appService.currentUser;

          if (currentUser == null) throw Exception('Utilisateur non connecté');

          // Créer une commande en statut 'collecting' avec une deadline de 30 minutes
          final deadline = DateTime.now().add(const Duration(minutes: 30));
          _orderDeadline = deadline;
          _activeGroupOrderId = await socialService.startGroupOrder(
            groupId: _currentGroup!['id'],
            initiatorId: currentUser.id,
            deliveryAddress: '', // Sera rempli au checkout
            deadline: deadline,
          );

          _startDeadlineTimer();

          // Activer les abonnements
          _setupRealtimeSubscription();
        } catch (e) {
          debugPrint('⚠️ Impossible de démarrer la commande groupe: $e');
          // On continue en local si échec (fallback)
        }
      }

      final existingItemIndex = _groupItems
          .indexWhere((groupItem) => groupItem.menuItemId == item.id);

      OrderItem updatedItem;
      if (existingItemIndex != -1) {
        // Augmenter la quantité si l'item existe déjà
        final existingItem = _groupItems[existingItemIndex];
        updatedItem = OrderItem(
          menuItemId: item.id,
          menuItemName: item.name,
          name: item.name,
          quantity: existingItem.quantity + quantity,
          unitPrice: item.price,
          totalPrice: (existingItem.quantity + quantity) * item.price,
          category: item.category?.displayName ?? 'Non catégorisé',
          menuItemImage: item.imageUrl ?? '',
          customizations: customizations != null
              ? Map<String, String>.from(
                  customizations.map(
                    (key, value) => MapEntry(key, value.toString()),
                  ),
                )
              : existingItem.customizations,
          notes: existingItem.notes,
        );
        // Mise à jour locale optimiste (sera écrasée par le refresh temps réel)
        setState(() {
          _groupItems[existingItemIndex] = updatedItem;
        });
      } else {
        // Ajouter un nouvel item
        updatedItem = OrderItem(
          menuItemId: item.id,
          menuItemName: item.name,
          name: item.name,
          quantity: quantity,
          unitPrice: item.price,
          totalPrice: item.price * quantity,
          category: item.category?.displayName ?? 'Non catégorisé',
          menuItemImage: item.imageUrl ?? '',
          customizations: customizations != null
              ? Map<String, String>.from(
                  customizations.map(
                    (key, value) => MapEntry(key, value.toString()),
                  ),
                )
              : {},
        );
        // Mise à jour locale optimiste
        setState(() {
          _groupItems.add(updatedItem);
        });
      }

      // Sauvegarder dans la base de données
      if (_activeGroupOrderId != null) {
        try {
          // Vérifier si l'item existe déjà dans la commande
          final existingItems = await _databaseService.supabase
              .from('order_items')
              .select('id, quantity')
              .eq('order_id', _activeGroupOrderId!)
              .eq('menu_item_id', item.id)
              .maybeSingle();

          if (existingItems != null) {
            // Mettre à jour la quantité
            await _databaseService.supabase.from('order_items').update({
              'quantity': updatedItem.quantity,
              'total_price': updatedItem.totalPrice,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', existingItems['id']);
          } else {
            // Insérer un nouvel item
            await _databaseService.supabase.from('order_items').insert({
              'order_id': _activeGroupOrderId!,
              'menu_item_id': item.id,
              'menu_item_name': item.name,
              'name': item.name,
              'category': updatedItem.category,
              'quantity': updatedItem.quantity,
              'unit_price': updatedItem.unitPrice,
              'total_price': updatedItem.totalPrice,
              'menu_item_image': updatedItem.menuItemImage,
              'customizations': updatedItem.customizations,
              'notes': updatedItem.notes,
            });
          }

          // Mettre à jour le total de la commande
          final total = _calculateGroupTotal();
          await _databaseService.supabase.from('orders').update({
            'subtotal': total,
            'total': total,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', _activeGroupOrderId!);
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la sauvegarde de l\'item: $e');
          // Revert optimistic update if needed or show error
        }
      }

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} ajouté au panier du groupe'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ajout au panier: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajout: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFromGroupCart(OrderItem item) async {
    try {
      // Supprimer de la liste locale
      _groupItems
          .removeWhere((groupItem) => groupItem.menuItemId == item.menuItemId);

      // Si une commande groupée est active, supprimer de la base de données
      if (_activeGroupOrderId != null) {
        try {
          await _databaseService.supabase
              .from('order_items')
              .delete()
              .eq('order_id', _activeGroupOrderId!)
              .eq('menu_item_id', item.menuItemId);

          // Mettre à jour le total de la commande
          final total = _calculateGroupTotal();
          await _databaseService.supabase.from('orders').update({
            'subtotal': total,
            'total': total,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', _activeGroupOrderId!);
        } catch (e) {
          debugPrint('⚠️ Erreur lors de la suppression de l\'item: $e');
        }
      }

      setState(() {});

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} retiré du panier'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  double _calculateGroupTotal() {
    return _groupItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  bool _isCurrentUserInitiator() {
    if (_currentGroup == null) return false;
    final appService = context.read<AppService>();
    final currentUser = appService.currentUser;
    if (currentUser == null) return false;
    return _currentGroup!['creatorId'] == currentUser.id;
  }

  Future<void> _confirmGroupOrder() async {
    if (_activeGroupOrderId == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune commande active à confirmer'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!_isCurrentUserInitiator()) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seul l\'organisateur peut confirmer la commande'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la commande'),
        content: Text(
          'Vous allez confirmer la commande groupée.\n\n'
          'Total: ${PriceFormatter.format(_calculateGroupTotal())}\n'
          'Items: ${_groupItems.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || !context.mounted) return;

    try {
      final socialService = context.read<SocialService>();
      final success =
          await socialService.confirmGroupOrder(_activeGroupOrderId!);

      if (success && mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande groupée confirmée avec succès!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Recharger la commande pour mettre à jour le statut
        await _loadActiveGroupOrder();
      } else {
        throw Exception('Échec de la confirmation');
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la confirmation: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _viewPaymentStatus() async {
    if (_activeGroupOrderId == null || _currentGroup == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune commande active'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (mounted && context.mounted) {
      await context.navigateToGroupPaymentStatus(
        groupId: _currentGroup!['id'],
        orderId: _activeGroupOrderId!,
      );
    }
  }

  void _shareGroupCode() {
    if (_currentGroup == null) return;

    final inviteCode = _currentGroup!['inviteCode'] as String;
    Clipboard.setData(ClipboardData(text: inviteCode));

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Code d\'invitation copié: $inviteCode'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Êtes-vous sûr de vouloir quitter ce groupe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (!mounted || !context.mounted) return;

    if (confirmed == true && _currentGroup != null) {
      if (!mounted || !context.mounted) return;
      try {
        final appService = context.read<AppService>();
        final socialService = context.read<SocialService>();
        final currentUser = appService.currentUser;

        if (currentUser == null) return;

        final success = await socialService.leaveFamilyGroup(
          _currentGroup!['id'],
          currentUser.id,
        );

        if (success) {
          setState(() {
            _currentGroup = null;
            _groupMembers = [];
            _groupItems = [];
            _activeGroupOrderId = null;
          });

          unawaited(_orderSubscription?.unsubscribe());
          unawaited(_orderItemsSubscription?.unsubscribe());
          unawaited(_groupMembersSubscription?.unsubscribe());

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vous avez quitté le groupe'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Impossible de quitter le groupe (êtes-vous le créateur ?)',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la sortie du groupe: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openSharedPayment() async {
    final total = _calculateGroupTotal();
    if (total <= 0) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajoutez des articles avant de partager le paiement'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (_currentGroup == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vous devez être dans un groupe pour partager le paiement',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final appService = context.read<AppService>();
    final currentUser = appService.currentUser;
    if (currentUser == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez être connecté pour partager le paiement'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Afficher un indicateur de chargement
      if (context.mounted) {
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Créer ou récupérer la commande groupée
      String orderId;
      if (_activeGroupOrderId == null) {
        // Créer une nouvelle commande groupée
        orderId = await _createGroupOrder(total);
        if (orderId.isEmpty) {
          throw Exception('Impossible de créer la commande groupée');
        }
        _activeGroupOrderId = orderId;
      } else {
        orderId = _activeGroupOrderId!;
        // Mettre à jour le total de la commande existante
        await _databaseService.supabase.from('orders').update({
          'subtotal': total,
          'total': total,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      }

      // Fermer le dialog de chargement
      if (!mounted || !context.mounted) return;
      Navigator.of(context).pop();

      final members = _groupMembers.isNotEmpty ? _groupMembers : [currentUser];

      final participants = members.map((member) {
        return PaymentParticipant(
          userId: member.id,
          name: member.name,
          email: member.email,
          phoneNumber: member.phone,
          operator: 'mtn',
          amount: total / members.length,
        );
      }).toList();

      if (mounted && context.mounted) {
        await context.navigateToSharedPayment(
          groupId: _currentGroup!['id'],
          orderId: orderId,
          totalAmount: total,
          participants: participants,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ouverture du paiement partagé: $e');

      // Fermer le dialog de chargement si toujours ouvert
      if (mounted && context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String> _createGroupOrder(double total) async {
    try {
      final appService = context.read<AppService>();
      final currentUser = appService.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Créer la commande groupée en base de données
      final orderResponse = await _databaseService.supabase
          .from('orders')
          .insert({
            'user_id': currentUser.id,
            'is_group_order': true,
            'group_id': _currentGroup!['id'],
            'status': 'pending',
            'subtotal': total,
            'delivery_fee': 0.0,
            'total': total,
            'payment_method': 'shared',
            'payment_status': 'pending',
            'estimated_delivery_time':
                DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          })
          .select('id')
          .single();

      final orderId = orderResponse['id'] as String;

      // Ajouter les items de la commande
      for (final item in _groupItems) {
        await _databaseService.supabase.from('order_items').insert({
          'order_id': orderId,
          'menu_item_id': item.menuItemId,
          'menu_item_name': item.name,
          'name': item.name,
          'category': item.category,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
          'menu_item_image': item.menuItemImage,
          'customizations': item.customizations,
          'notes': item.notes,
        });
      }

      debugPrint('✅ Commande groupée créée: $orderId');
      return orderId;
    } catch (e) {
      debugPrint('❌ Erreur lors de la création de la commande groupée: $e');
      rethrow;
    }
  }

  Future<void> _proceedToCheckout() async {
    final total = _calculateGroupTotal();
    if (total <= 0) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajoutez des articles avant de commander'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (_currentGroup == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous devez être dans un groupe pour commander'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      // Afficher un indicateur de chargement
      if (context.mounted) {
        unawaited(
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      // Créer la commande groupée
      String orderId;
      if (_activeGroupOrderId == null) {
        orderId = await _createGroupOrder(total);
        if (orderId.isEmpty) {
          throw Exception('Impossible de créer la commande groupée');
        }
        _activeGroupOrderId = orderId;
      } else {
        orderId = _activeGroupOrderId!;
        // Mettre à jour le total
        await _databaseService.supabase.from('orders').update({
          'subtotal': total,
          'total': total,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      }

      // Fermer le dialog de chargement
      if (!mounted || !context.mounted) return;
      Navigator.of(context).pop();

      // Convertir les items de commande en items de panier pour le checkout
      final cartItems = _groupItems.map((item) {
        return CartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // ID temporaire
          menuItemId: item.menuItemId,
          name: item.name,
          price: item.unitPrice,
          quantity: item.quantity,
          imageUrl: item.menuItemImage,
          customizations: item.customizations,
        );
      }).toList();

      // Naviguer vers l'écran de checkout avec l'ID de la commande
      if (mounted && context.mounted) {
        await context.navigateToCheckout(
          existingOrderId: orderId,
          items: cartItems,
          total: total,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la création de la commande: $e');

      // Fermer le dialog de chargement si toujours ouvert
      if (mounted && context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la création de la commande: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
