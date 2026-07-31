import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/services/group_cart_service.dart';
import 'package:elcora_fast/services/address_service.dart';
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

  bool _isCreatingGroup = false;
  String _currentFilter = 'all';
  List<MenuItem> _filteredMenuItems = [];

  /// Rafraîchit l'affichage du compte à rebours ; l'échéance elle-même vient du
  /// serveur (`closes_at`), jamais d'une horloge locale.
  Timer? _deadlineTimer;

  /// Le panier collaboratif en cours, tenu par le service : un seul objet là où
  /// l'implémentation Supabase suivait un groupe, une commande, ses lignes et
  /// trois abonnements temps réel séparés.
  eccore.GroupCart? get _cart => GroupCartService().current;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) return;
      try {
        await GroupCartService().initialize();
        if (mounted) _startDeadlineTimer();
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
    _deadlineTimer?.cancel();
    // Le panier continue de vivre pour les autres participants : on ne ferme
    // que le socket de cet écran.
    GroupCartService().detach();
    super.dispose();
  }

  void _startDeadlineTimer() {
    _deadlineTimer?.cancel();
    _deadlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  String _formatTimeRemaining() {
    final deadline = _cart?.closesAt;
    if (deadline == null) return '';

    final now = DateTime.now();
    if (now.isAfter(deadline)) {
      return 'Temps écoulé';
    }

    final remaining = deadline.difference(now);
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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
    if (_cart == null) {
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
                          _cart!.title.isEmpty
                              ? 'Commande de groupe'
                              : _cart!.title,
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
                          'Code: ${_cart!.code}',
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
                    '${_cart!.members.length} membre(s) • Total: ${PriceFormatter.format(_calculateGroupTotal())}',
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
              itemCount: _cart!.members.length,
              itemBuilder: (context, index) {
                final member = _cart!.members[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        member.fullName.isNotEmpty
                            ? member.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(member.fullName),
                    // Le contrat ne porte pas l'adresse e-mail des autres
                    // participants : suivre son livreur est un service, lire le
                    // carnet d'adresses du groupe n'en est pas un.
                    subtitle: Text('Ce que ce convive doit : '
                        '${PriceFormatter.format(_cart!.totalFor(member.id).toMajorUnits())}'),
                    trailing: member.id == _cart!.hostId
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
                    '${_cart?.lines.length ?? 0} article(s)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (_cart?.closesAt != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cart!.closesAt!.isAfter(DateTime.now())
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
                        color: _cart!.closesAt!.isAfter(DateTime.now())
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Temps restant: ${_formatTimeRemaining()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cart!.closesAt!.isAfter(DateTime.now())
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
          child: (_cart?.lines.isEmpty ?? true)
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
                  itemCount: _cart!.lines.length + 1, // +1 pour le résumé
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
                                '${_cart!.lines.length} article(s) • ${_cart!.members.length} membre(s)',
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
                    final line = _cart!.lines[index - 1];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            line.quantity.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(line.name),
                        // Chaque ligne est attribuée à son auteur par le
                        // serveur : le groupe voit qui a commandé quoi, et une
                        // ligne indisponible le dit plutôt que de disparaître.
                        subtitle: Text(
                          line.isOrderable
                              ? '${line.memberName} • '
                                  '${PriceFormatter.format(line.unitPrice.toMajorUnits())} × ${line.quantity}'
                              : '${line.memberName} • ${line.unavailableReason}',
                          style: line.isOrderable
                              ? null
                              : const TextStyle(color: AppColors.error),
                        ),
                        trailing: Text(
                          PriceFormatter.format(line.total.toMajorUnits()),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () => _removeFromGroupCart(line),
                      ),
                    );
                  },
                ),
        ),

        // Total et actions
        if (_cart?.lines.isNotEmpty ?? false)
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
                if (_cart != null && _isCurrentUserInitiator())
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _cart!.isOrderable ? _confirmGroupOrder : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirmer la commande'),
                    ),
                  ),
                // Le partage du paiement ne s'ouvre qu'une fois la commande
                // née du panier : il porte sur une commande, pas sur un panier
                // que chacun peut encore modifier.
                if (_cart?.orderId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openSharedPayment,
                          icon: const Icon(Icons.handshake_outlined),
                          label: const Text('Paiement partagé'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _viewPaymentStatus,
                        icon: const Icon(Icons.payment),
                        tooltip: 'Voir le statut des paiements',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ],
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
      // Ouvrir un panier collaboratif : le code d'invitation est généré par le
      // serveur, et l'hôte est l'appelant — rien de tout cela ne se déclare.
      final cart = await GroupCartService().open(
        title: _groupNameController.text.trim(),
      );

      if (cart != null) {
        _startDeadlineTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe créé avec succès!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        throw Exception("Échec de l'ouverture du panier de groupe");
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
          content: Text("Veuillez entrer un code d'invitation"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Capacité et échéance sont vérifiées par le serveur, sous verrou : les
    // deviner ici depuis un état déjà périmé laisserait entrer un participant
    // dans un panier clos.
    final rejoint = await GroupCartService().join(_inviteCodeController.text);

    if (!mounted) return;

    if (rejoint) {
      _inviteCodeController.clear();
      _startDeadlineTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez rejoint le groupe !'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code invalide, panier clos ou déjà complet'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _addToGroupCart(
    MenuItem item, {
    int quantity = 1,
    Map<String, dynamic>? customizations,
  }) async {
    if (_cart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez d'abord rejoindre ou créer un groupe"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Le serveur attribue la ligne à l'appelant, valide l'article et refuse
    // l'ajout après l'échéance. Il n'y a plus de commande à ouvrir au préalable :
    // le panier collaboratif est l'objet, pas un conteneur autour d'une commande.
    final ajoute = await GroupCartService().addItem(
      menuItemId: item.id,
      quantity: quantity,
      notes: customizations == null || customizations.isEmpty
          ? ''
          : customizations.entries.map((e) => '${e.key}: ${e.value}').join(', '),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ajoute
              ? '${item.name} ajouté au panier du groupe'
              : 'Ajout refusé : le panier est peut-être clos',
        ),
        backgroundColor: ajoute ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _removeFromGroupCart(eccore.GroupCartLine line) async {
    final retire = await GroupCartService().removeItem(line.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          retire
              ? '${line.name} retiré du panier'
              : 'Suppression refusée : cette ligne appartient à un autre participant',
        ),
        backgroundColor: retire ? AppColors.primary : AppColors.error,
      ),
    );
  }

  /// Le sous-total vient du serveur : l'additionner ici donnerait un montant
  /// concurrent de celui qui sera facturé, et deux participants pourraient en
  /// afficher deux différents.
  double _calculateGroupTotal() => _cart?.subtotal.toMajorUnits() ?? 0.0;

  bool _isCurrentUserInitiator() {
    final cart = _cart;
    final currentUser = context.read<AppService>().currentUser;
    if (cart == null || currentUser == null) return false;
    return cart.isHost(currentUser.id);
  }

  /// Confirme le panier : le serveur en fait une commande.
  ///
  /// Réservé à l'hôte, et refusé côté serveur si une ligne est devenue
  /// indisponible. Aucun total n'est envoyé — c'est le même calcul que pour une
  /// commande ordinaire, fait au même endroit.
  Future<void> _confirmGroupOrder() async {
    final cart = _cart;
    if (cart == null) return;

    if (!_isCurrentUserInitiator()) {
      _avertir("Seul l'organisateur peut confirmer la commande");
      return;
    }

    final address = context.read<AddressService>().selectedAddress;
    if (address == null) {
      _avertir('Sélectionnez une adresse de livraison avant de commander');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la commande'),
        content: Text(
          'Vous allez commander pour le groupe.\n\n'
          'Total : ${PriceFormatter.format(_calculateGroupTotal())}\n'
          'Articles : ${cart.lines.length}\n'
          'Livraison : ${address.fullAddress}',
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

    if (confirmed != true || !mounted) return;

    final order = await GroupCartService().confirm(
      addressId: address.id,
      paymentMethod: PaymentMethod.mobileMoney,
    );

    if (!mounted) return;

    if (order == null) {
      _avertir('Commande refusée : un article est peut-être devenu indisponible');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Commande ${order.reference} créée pour le groupe'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _avertir(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _viewPaymentStatus() async {
    final cart = _cart;
    final orderId = cart?.orderId;
    if (cart == null || orderId == null) {
      _avertir('Aucune commande à régler pour l\'instant');
      return;
    }

    if (mounted && context.mounted) {
      await context.navigateToGroupPaymentStatus(
        groupId: cart.id,
        orderId: orderId,
      );
    }
  }

  void _shareGroupCode() {
    final cart = _cart;
    if (cart == null) return;

    final inviteCode = cart.code;
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

  /// Renonce au panier — **réservé à l'hôte**, et pour tout le monde.
  ///
  /// Il n'y a pas de « quitter » dans le contrat v2 : un panier collaboratif
  /// dure le temps d'un repas, et en sortir un participant laisserait ses
  /// lignes derrière lui, à la charge de l'hôte. Un invité qui ne veut plus
  /// participer retire ses lignes ; l'hôte, lui, referme le panier.
  Future<void> _leaveGroup() async {
    final cart = _cart;
    if (cart == null) return;

    if (!_isCurrentUserInitiator()) {
      _avertir("Seul l'organisateur peut fermer le panier du groupe");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fermer le panier du groupe'),
        content: const Text(
          'Le panier sera fermé pour tous les participants et leurs articles '
          'seront perdus. Cette action est définitive.',
        ),
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
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ferme = await GroupCartService().cancel('Fermé par l\'organisateur');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ferme ? 'Panier du groupe fermé' : 'Fermeture refusée'),
        backgroundColor: ferme ? AppColors.primary : AppColors.error,
      ),
    );
  }

  /// Ouvre le partage du paiement de la commande née du panier.
  ///
  /// Les parts viennent de `per_member`, calculé par le serveur : l'ancienne
  /// version divisait le total entre convives côté client, si bien que deux
  /// participants pouvaient afficher deux répartitions différentes du même
  /// montant.
  Future<void> _openSharedPayment() async {
    final cart = _cart;
    final orderId = cart?.orderId;
    if (cart == null || orderId == null) {
      _avertir('Confirmez d\'abord la commande du groupe');
      return;
    }

    final participants = cart.members
        .map(
          (member) => PaymentParticipant(
            userId: member.id,
            name: member.fullName,
            // Ni adresse e-mail ni téléphone dans le contrat : chaque payeur
            // saisit les siens sur l'écran de paiement.
            email: '',
            phoneNumber: '',
            operator: 'mtn',
            amount: cart.totalFor(member.id).toMajorUnits(),
          ),
        )
        .where((participant) => participant.amount > 0)
        .toList();

    if (!mounted || !context.mounted) return;

    await context.navigateToSharedPayment(
      groupId: cart.id,
      orderId: orderId,
      totalAmount: cart.subtotal.toMajorUnits(),
      participants: participants,
    );
  }
}
