import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../models/menu_models.dart';
import '../../theme.dart';
import '../../utils/price_formatter.dart';

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

  // Simulation d'un groupe pour les tests
  Map<String, dynamic>? _currentGroup;
  List<User> _groupMembers = [];
  List<OrderItem> _groupItems = [];
  bool _isCreatingGroup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentGroup();
  }

  Future<void> _loadCurrentGroup() async {
    // Simulation - dans une vraie implémentation, ceci viendrait du service
    // Pour l'instant, on laisse le groupe vide
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
        children: [_buildGroupTab(), _buildMenuTab(), _buildCartTab()],
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
    final allItems = appService.menuItems;

    // Supprimer les doublons basés sur l'ID
    final seenIds = <String>{};
    final menuItems = allItems.where((item) {
      if (seenIds.contains(item.id)) {
        return false;
      }
      seenIds.add(item.id);
      return true;
    }).toList();

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
              IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
            ],
          ),
        ),

        // Menu items
        Expanded(
          child: ListView.builder(
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

  Widget _buildMenuItemCard(MenuItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: AppColors.surfaceContainerHighest,
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
                    item.description ?? '',
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
                        PriceFormatter.format(item.basePrice),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.textSecondary),
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

      // Simulation de création de groupe
      final groupCode =
          DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final group = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _groupNameController.text.trim(),
        'inviteCode': groupCode,
        'creatorId': appService.currentUser!.id,
        'createdAt': DateTime.now(),
      };

      setState(() {
        _currentGroup = group;
        _groupMembers = [appService.currentUser!];
        _isCreatingGroup = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Groupe créé avec succès! Code: $groupCode'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() {
        _isCreatingGroup = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du groupe: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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

      // Simulation de connexion à un groupe
      // Dans une vraie implémentation, ceci vérifierait le code et récupérerait le groupe
      final group = {
        'id': 'group_${_inviteCodeController.text.trim()}',
        'name': 'Groupe de Test',
        'inviteCode': _inviteCodeController.text.trim(),
        'creatorId': 'creator_123',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
      };

      setState(() {
        _currentGroup = group;
        _groupMembers = [
          appService.currentUser!,
          // Simulation d'autres membres
          User(
            id: 'user_2',
            authUserId: 'auth_user_2',
            name: 'Marie Dupont',
            email: 'marie@example.com',
            phone: '0123456789',
            role: UserRole.client,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez rejoint le groupe avec succès!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la connexion au groupe: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _addToGroupCart(MenuItem item) {
    // Simulation d'ajout au panier de groupe
    final existingItemIndex = _groupItems.indexWhere(
      (groupItem) => groupItem.menuItemId == item.id,
    );

    if (existingItemIndex != -1) {
      // Augmenter la quantité si l'item existe déjà
      _groupItems[existingItemIndex] = OrderItem(
        menuItemId: item.id,
        menuItemName: item.name,
        name: item.name,
        quantity: _groupItems[existingItemIndex].quantity + 1,
        unitPrice: item.basePrice,
        totalPrice:
            (_groupItems[existingItemIndex].quantity + 1) * item.basePrice,
        categoryId: item.categoryId,
        menuItemImage: item.imageUrl ?? '',
      );
    } else {
      // Ajouter un nouvel item
      _groupItems.add(
        OrderItem(
          menuItemId: item.id,
          menuItemName: item.name,
          name: item.name,
          quantity: 1,
          unitPrice: item.basePrice,
          totalPrice: item.basePrice,
          categoryId: item.categoryId,
          menuItemImage: item.imageUrl ?? '',
        ),
      );
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} ajouté au panier du groupe'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _removeFromGroupCart(OrderItem item) {
    // Simulation de suppression du panier de groupe
    _groupItems.removeWhere(
      (groupItem) => groupItem.menuItemId == item.menuItemId,
    );
    setState(() {});
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Êtes-vous sûr de vouloir quitter ce groupe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Simulation de sortie du groupe
        setState(() {
          _currentGroup = null;
          _groupMembers = [];
          _groupItems = [];
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez quitté le groupe'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sortie du groupe: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _proceedToCheckout() async {
    // Naviguer vers l'écran de checkout pour le groupe
    Navigator.pushNamed(
      context,
      '/checkout',
      arguments: {'isGroupOrder': true},
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }
}
