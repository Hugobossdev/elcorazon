import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/social_service.dart';
import 'package:elcora_fast/services/group_delivery_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
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

  // Realtime subscriptions
  RealtimeChannel? _orderSubscription;
  RealtimeChannel? _orderItemsSubscription;

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentGroup();

    // Initialiser les services de groupes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Provider.of<SocialService>(context, listen: false).initialize();
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
    super.dispose();
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
            return User(
              id: member['user_id'] ?? '',
              name: member['name'] ?? 'Membre',
              email: member['email'] ?? '',
              phone: member['phone'] ?? '',
              role: UserRole.client,
              createdAt: DateTime.now(),
            );
          }).toList();
        });

        // Charger la commande groupée active si elle existe
        await _loadActiveGroupOrder();
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement du groupe: $e');
    }
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

        // Charger les items de la commande
        final itemsData = order['order_items'] as List? ?? [];
        _groupItems = itemsData.map((item) {
          return OrderItem(
            menuItemId: item['menu_item_id'] ?? '',
            menuItemName: item['menu_item_name'] ?? item['name'] ?? '',
            name: item['name'] ?? '',
            category: item['category'] ?? 'Non catégorisé',
            menuItemImage: item['menu_item_image'] ?? '',
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
            totalPrice: (item['total_price'] as num?)?.toDouble() ?? 0.0,
            customizations: item['customizations'] is Map
                ? Map<String, String>.from(
                    (item['customizations'] as Map).map(
                      (key, value) =>
                          MapEntry(key.toString(), value.toString()),
                    ),
                  )
                : {},
            notes: item['notes']?.toString(),
          );
        }).toList();

        setState(() {});
        debugPrint(
          '✅ Commande groupée active chargée: $_activeGroupOrderId avec ${_groupItems.length} items',
        );

        // Configurer les abonnements temps réel
        _setupRealtimeSubscription();
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
        '📡 Configuration des abonnements temps réel pour la commande: $_activeGroupOrderId');

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
                '🔄 Changement détecté sur les items: ${payload.eventType}');
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
                '🔄 Changement détecté sur la commande: ${payload.eventType}');
            // Si le statut change, on pourrait vouloir recharger ou notifier
            if (payload.newRecord['status'] != payload.oldRecord['status']) {
              // Gérer le changement de statut (ex: confirmé)
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Statut de la commande mis à jour: ${payload.newRecord['status']}')),
                );
              }
            }
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
            return OrderItem(
              menuItemId: item['menu_item_id'] ?? '',
              menuItemName: item['menu_item_name'] ?? item['name'] ?? '',
              name: item['name'] ?? '',
              category: item['category'] ?? 'Non catégorisé',
              menuItemImage: item['menu_item_image'] ?? '',
              quantity: (item['quantity'] as num?)?.toInt() ?? 1,
              unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
              totalPrice: (item['total_price'] as num?)?.toDouble() ?? 0.0,
              customizations: item['customizations'] is Map
                  ? Map<String, String>.from(
                      (item['customizations'] as Map).map(
                        (key, value) =>
                            MapEntry(key.toString(), value.toString()),
                      ),
                    )
                  : {},
              notes: item['notes']?.toString(),
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
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Panier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupTab(),
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
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun item ne correspond aux filtres',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
          color: AppColors.surface,
          child: Row(
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
                style: const TextStyle(color: AppColors.textSecondary),
              ),
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
                      const Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Le panier est vide',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajoutez des articles depuis le menu',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupItems.length,
                  itemBuilder: (context, index) {
                    final item = _groupItems[index];
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
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
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
                SizedBox(
                  width: double.infinity,
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

          // Créer une commande en statut 'collecting'
          _activeGroupOrderId = await socialService.startGroupOrder(
            groupId: _currentGroup!['id'],
            initiatorId: currentUser.id,
            deliveryAddress: '', // Sera rempli au checkout
          );

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
              ? Map<String, String>.from(customizations.map(
                  (key, value) => MapEntry(key, value.toString()),
                ))
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
              ? Map<String, String>.from(customizations.map(
                  (key, value) => MapEntry(key, value.toString()),
                ))
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

      if (context.mounted) {
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
      if (context.mounted) {
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} retiré du panier'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression: $e');
      if (context.mounted) {
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

  void _shareGroupCode() {
    // Implémenter le partage du code du groupe
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code du groupe copié: ${_currentGroup!['inviteCode']}'),
        backgroundColor: AppColors.primary,
      ),
    );
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

    if (confirmed == true && _currentGroup != null) {
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

          _orderSubscription?.unsubscribe();
          _orderItemsSubscription?.unsubscribe();

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
                    'Impossible de quitter le groupe (êtes-vous le créateur ?)'),
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
      if (context.mounted) {
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
      if (context.mounted) {
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
      if (context.mounted) {
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
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
      if (context.mounted) {
        Navigator.of(context).pop();
      }

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

      if (context.mounted) {
        context.navigateToSharedPayment(
          groupId: _currentGroup!['id'],
          orderId: orderId,
          totalAmount: total,
          participants: participants,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ouverture du paiement partagé: $e');

      // Fermer le dialog de chargement si toujours ouvert
      if (context.mounted) {
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
      if (context.mounted) {
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
      if (context.mounted) {
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
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
      if (context.mounted) {
        Navigator.of(context).pop();

        // Naviguer vers l'écran de checkout avec l'ID de la commande
        await context.navigateToCheckout();
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la création de la commande: $e');

      // Fermer le dialog de chargement si toujours ouvert
      if (context.mounted) {
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
