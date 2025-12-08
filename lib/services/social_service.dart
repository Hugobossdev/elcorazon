import 'package:flutter/foundation.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/database_service.dart';

class SocialPost {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final String type; // 'order', 'review', 'achievement'
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final int likes;
  final List<String> comments;
  final String? imageUrl;

  SocialPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.type,
    required this.metadata,
    required this.createdAt,
    this.likes = 0,
    this.comments = const [],
    this.imageUrl,
  });
}

class FamilyGroup {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? description;
  final bool isActive;
  final Map<String, dynamic> settings;

  FamilyGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
    this.description,
    this.isActive = true,
    this.settings = const {},
  });
}

class GroupOrder {
  final String id;
  final String familyGroupId;
  final String initiatorId;
  final Map<String, List<MenuItem>> memberOrders; // userId -> items
  final double totalAmount;
  final String status; // 'collecting', 'confirmed', 'preparing', 'delivered'
  final DateTime createdAt;
  final DateTime? deadlineAt;
  final String deliveryAddress;

  GroupOrder({
    required this.id,
    required this.familyGroupId,
    required this.initiatorId,
    required this.memberOrders,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.deliveryAddress, this.deadlineAt,
  });
}

class SocialService extends ChangeNotifier {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final DatabaseService _databaseService = DatabaseService();

  List<SocialPost> _posts = [];
  List<FamilyGroup> _familyGroups = [];
  List<GroupOrder> _groupOrders = [];
  bool _isInitialized = false;

  List<SocialPost> get posts => List.unmodifiable(_posts);
  List<FamilyGroup> get familyGroups => List.unmodifiable(_familyGroups);
  List<GroupOrder> get groupOrders => List.unmodifiable(_groupOrders);
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSocialData();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Social Service: $e');
    }
  }

  Future<void> _loadSocialData() async {
    try {
      // Charger les posts sociaux depuis la base de données
      await _loadSocialPosts();

      // Charger les groupes familiaux depuis la base de données
      await _loadFamilyGroups();

      // Charger les commandes de groupe depuis la base de données
      await _loadGroupOrders();
    } catch (e) {
      debugPrint('❌ Error loading social data: $e');
      // En cas d'erreur, utiliser des listes vides
      _posts = [];
      _familyGroups = [];
      _groupOrders = [];
    }
  }

  Future<void> _loadGroupOrders() async {
    try {
      // Récupérer les commandes de groupe depuis la base de données
      final response = await _databaseService.supabase
          .from('orders')
          .select('''
            id,
            user_id,
            group_id,
            delivery_address,
            status,
            total,
            created_at,
            estimated_delivery_time
          ''')
          .eq('is_group_order', true)
          .inFilter('status', ['pending', 'confirmed', 'preparing', 'ready'])
          .order('created_at', ascending: false);

      _groupOrders = response.map((data) {
        return GroupOrder(
          id: data['id'] as String,
          familyGroupId: data['group_id'] as String? ?? '',
          initiatorId: data['user_id'] as String,
          memberOrders: {}, // Will be loaded separately if needed
          totalAmount: (data['total'] as num?)?.toDouble() ?? 0.0,
          status: _mapOrderStatusToGroupStatus(data['status'] as String),
          createdAt: DateTime.parse(data['created_at'] as String),
          deadlineAt: data['estimated_delivery_time'] != null
              ? DateTime.parse(data['estimated_delivery_time'] as String)
              : null,
          deliveryAddress: data['delivery_address'] as String? ?? '',
        );
      }).toList();

      debugPrint('✅ Group orders loaded from database: ${_groupOrders.length} orders');
    } catch (e) {
      debugPrint('❌ Error loading group orders: $e');
      _groupOrders = [];
    }
  }

  String _mapOrderStatusToGroupStatus(String orderStatus) {
    switch (orderStatus) {
      case 'pending':
      case 'confirmed':
        return 'collecting';
      case 'preparing':
        return 'confirmed';
      case 'ready':
      case 'picked_up':
      case 'on_the_way':
        return 'preparing';
      case 'delivered':
        return 'delivered';
      default:
        return 'collecting';
    }
  }

  Future<void> _loadSocialPosts() async {
    try {
      // Récupérer les posts depuis la base de données avec likes et commentaires
      final response = await _databaseService.supabase
          .from('social_posts')
          .select('''
            *,
            users!social_posts_user_id_fkey(name),
            post_likes(user_id),
            post_comments(id, content, user_id, created_at)
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      _posts = response.map((data) {
        final user = data['users'] as Map<String, dynamic>?;
        final likes = data['post_likes'] as List? ?? [];
        final comments = data['post_comments'] as List? ?? [];
        
        return SocialPost(
          id: data['id'] as String,
          userId: data['user_id'] as String,
          userName: user?['name'] as String? ?? 'Utilisateur',
          content: data['content'] as String,
          type: data['post_type'] as String,
          metadata: data['data'] as Map<String, dynamic>? ?? {},
          createdAt: DateTime.parse(data['created_at'] as String),
          likes: (data['likes_count'] as num?)?.toInt() ?? likes.length,
          comments: comments.map((c) => c['content'] as String).toList(),
          imageUrl: data['image_url'] as String?,
        );
      }).toList();

      debugPrint('✅ Social posts loaded from database: ${_posts.length} posts');
    } catch (e) {
      debugPrint('❌ Error loading social posts: $e');
      _posts = [];
    }
  }

  Future<void> _loadFamilyGroups() async {
    try {
      // Récupérer les groupes familiaux avec leurs membres depuis la base de données
      final response = await _databaseService.supabase
          .from('social_groups')
          .select('''
            *,
            users!social_groups_creator_id_fkey(name),
            group_members!inner(user_id, role, is_active)
          ''')
          .eq('group_type', 'family')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _familyGroups = response.map((data) {
        // Extraire les IDs des membres actifs
        final members = (data['group_members'] as List? ?? [])
            .where((m) => m['is_active'] == true)
            .map((m) => m['user_id'] as String)
            .toList();

        return FamilyGroup(
          id: data['id'] as String,
          name: data['name'] as String,
          ownerId: data['creator_id'] as String,
          memberIds: members,
          createdAt: DateTime.parse(data['created_at'] as String),
          description: data['description'] as String? ?? '',
          isActive: data['is_active'] as bool? ?? true,
        );
      }).toList();

      debugPrint(
          '✅ Family groups loaded from database: ${_familyGroups.length} groups',);
    } catch (e) {
      debugPrint('❌ Error loading family groups: $e');
      _familyGroups = [];
    }
  }

  // Social Sharing Functions

  /// Share an order on social media
  Future<String?> shareOrder(Order order, String caption,
      {String? imageUrl,}) async {
    try {
      // Sauvegarder en base de données
      final response = await _databaseService.supabase
          .from('social_posts')
          .insert({
            'user_id': order.userId,
            'content': caption,
            'post_type': 'order_share',
            'order_id': order.id,
            'image_url': imageUrl,
            'data': {
              'orderId': order.id,
              'items': order.items.map((item) => item.name).toList(),
              'total': order.total,
            },
          })
          .select()
          .single();

      final postId = response['id'] as String;

      // Ajouter à la liste locale
      final SocialPost post = SocialPost(
        id: postId,
        userId: order.userId,
        userName: 'Utilisateur', // In real app, get from user service
        content: caption,
        type: 'order_share',
        metadata: {
          'orderId': order.id,
          'items': order.items.map((item) => item.name).toList(),
          'total': order.total,
        },
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );

      _posts.insert(0, post);
      notifyListeners();

      // Simulate posting to external social platforms
      await _postToExternalPlatforms(post);

      debugPrint('Order shared on social media and saved to database: $postId');
      return postId;
    } catch (e) {
      debugPrint('Error sharing order: $e');
      return null;
    }
  }

  Future<void> _postToExternalPlatforms(SocialPost post) async {
    // Simulate posting to Instagram, TikTok, Facebook, etc.
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Posted to external platforms: ${post.content}');
  }

  /// Share an achievement
  Future<String?> shareAchievement(String userId, String achievement,
      {String? badgeImageUrl,}) async {
    try {
      final content =
          '🏆 Nouveau badge débloqué : $achievement ! #FastFoodGo #Achievement';

      // Sauvegarder en base de données
      final response = await _databaseService.supabase
          .from('social_posts')
          .insert({
            'user_id': userId,
            'content': content,
            'post_type': 'text', // Achievement posts are text type
            'image_url': badgeImageUrl,
            'data': {
              'achievement': achievement,
              'badgeImage': badgeImageUrl,
            },
          })
          .select()
          .single();

      final postId = response['id'] as String;

      // Récupérer le nom de l'utilisateur
      String userName = 'Utilisateur';
      try {
        final userResponse = await _databaseService.supabase
            .from('users')
            .select('name')
            .eq('id', userId)
            .maybeSingle();
        if (userResponse != null) {
          userName = userResponse['name'] as String? ?? 'Utilisateur';
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch user name: $e');
      }

      // Ajouter à la liste locale
      final SocialPost post = SocialPost(
        id: postId,
        userId: userId,
        userName: userName,
        content: content,
        type: 'achievement',
        metadata: {
          'achievement': achievement,
          'badgeImage': badgeImageUrl,
        },
        createdAt: DateTime.parse(response['created_at'] as String),
        imageUrl: badgeImageUrl,
      );

      _posts.insert(0, post);
      notifyListeners();

      debugPrint('✅ Achievement shared and saved to database: $postId');
      return postId;
    } catch (e) {
      debugPrint('❌ Error sharing achievement: $e');
      return null;
    }
  }

  /// Add a food review
  Future<String?> shareReview(
      String userId, MenuItem item, int rating, String review,) async {
    try {
      final content =
          '⭐ ${'★' * rating}${'☆' * (5 - rating)}\n$review\n#${item.name.replaceAll(' ', '')} #FastFoodGo';

      // Sauvegarder en base de données
      final response = await _databaseService.supabase
          .from('social_posts')
          .insert({
            'user_id': userId,
            'content': content,
            'post_type': 'review',
            'image_url': item.imageUrl,
            'data': {
              'itemId': item.id,
              'itemName': item.name,
              'rating': rating,
              'review': review,
            },
          })
          .select()
          .single();

      final postId = response['id'] as String;

      // Récupérer le nom de l'utilisateur
      String userName = 'Utilisateur';
      try {
        final userResponse = await _databaseService.supabase
            .from('users')
            .select('name')
            .eq('id', userId)
            .maybeSingle();
        if (userResponse != null) {
          userName = userResponse['name'] as String? ?? 'Utilisateur';
        }
      } catch (e) {
        debugPrint('⚠️ Could not fetch user name: $e');
      }

      // Ajouter à la liste locale
      final SocialPost post = SocialPost(
        id: postId,
        userId: userId,
        userName: userName,
        content: content,
        type: 'review',
        metadata: {
          'itemId': item.id,
          'itemName': item.name,
          'rating': rating,
          'review': review,
        },
        createdAt: DateTime.parse(response['created_at'] as String),
        imageUrl: item.imageUrl,
      );

      _posts.insert(0, post);
      notifyListeners();

      debugPrint('✅ Review shared and saved to database: $postId');
      return postId;
    } catch (e) {
      debugPrint('❌ Error sharing review: $e');
      return null;
    }
  }

  /// Get social media filters for food photos
  List<Map<String, dynamic>> getFoodFilters() {
    return [
      {
        'id': 'delicious',
        'name': 'Délicieux',
        'description': 'Filtre qui rend la nourriture encore plus appétissante',
        'overlayText': '😋 Délicieux !',
      },
      {
        'id': 'fastfoodgo_classic',
        'name': 'El Corazón Classic',
        'description': 'Filtre officiel FastFoodGo',
        'overlayText': '🍔 FastFoodGo - El Corazón',
      },
      {
        'id': 'spicy',
        'name': 'Épicé',
        'description': 'Pour les plats relevés',
        'overlayText': '🌶️ Ça pique !',
      },
      {
        'id': 'healthy',
        'name': 'Santé',
        'description': 'Pour les options healthy',
        'overlayText': '🥗 Healthy Choice',
      },
      {
        'id': 'celebration',
        'name': 'Célébration',
        'description': 'Pour célébrer un bon repas',
        'overlayText': '🎉 Bon appétit !',
      },
    ];
  }

  // Family & Friends Group Functions

  /// Create a new family group
  Future<String?> createFamilyGroup({
    required String ownerId,
    required String name,
    String? description,
  }) async {
    try {
      // Générer un code d'invitation unique
      final inviteCode = _generateInviteCode();

      // Créer le groupe en base de données
      final groupResponse = await _databaseService.supabase
          .from('social_groups')
          .insert({
            'name': name,
            'description': description ?? '',
            'group_type': 'family',
            'creator_id': ownerId,
            'invite_code': inviteCode,
            'is_active': true,
          })
          .select()
          .single();

      final groupId = groupResponse['id'] as String;

      // Ajouter le créateur comme membre avec le rôle 'creator'
      await _databaseService.supabase
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': ownerId,
            'role': 'creator',
            'is_active': true,
          });

      // Mettre à jour le compteur de membres
      await _databaseService.supabase
          .from('social_groups')
          .update({'member_count': 1})
          .eq('id', groupId);

      // Créer l'objet local
      final FamilyGroup group = FamilyGroup(
        id: groupId,
        name: name,
        ownerId: ownerId,
        memberIds: [ownerId],
        createdAt: DateTime.parse(groupResponse['created_at'] as String),
        description: description,
      );

      _familyGroups.add(group);
      notifyListeners();

      debugPrint('✅ Family group created and saved to database: $groupId');
      return groupId;
    } catch (e) {
      debugPrint('❌ Error creating family group: $e');
      return null;
    }
  }

  /// Generate a unique invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }
    return code;
  }

  /// Invite someone to a family group
  Future<bool> inviteToFamilyGroup(String groupId, String inviteeId) async {
    try {
      final int index = _familyGroups.indexWhere((g) => g.id == groupId);
      if (index == -1) {
        debugPrint('⚠️ Family group not found: $groupId');
        return false;
      }

      final group = _familyGroups[index];
      if (group.memberIds.contains(inviteeId)) {
        debugPrint('⚠️ User already in group: $inviteeId');
        return false;
      }

      // Ajouter le membre en base de données
      await _databaseService.supabase
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': inviteeId,
            'role': 'member',
            'is_active': true,
          });

      // Mettre à jour le compteur de membres
      final currentCount = await _databaseService.supabase
          .from('social_groups')
          .select('member_count')
          .eq('id', groupId)
          .single();

      final newCount = ((currentCount['member_count'] as num?)?.toInt() ?? 0) + 1;
      await _databaseService.supabase
          .from('social_groups')
          .update({'member_count': newCount})
          .eq('id', groupId);

      // Mettre à jour la liste locale
      final List<String> newMembers = List.from(group.memberIds)..add(inviteeId);

      final FamilyGroup updatedGroup = FamilyGroup(
        id: group.id,
        name: group.name,
        ownerId: group.ownerId,
        memberIds: newMembers,
        createdAt: group.createdAt,
        description: group.description,
        isActive: group.isActive,
        settings: group.settings,
      );

      _familyGroups[index] = updatedGroup;
      notifyListeners();

      debugPrint('✅ User invited to family group: $inviteeId');
      return true;
    } catch (e) {
      debugPrint('❌ Error inviting to family group: $e');
      return false;
    }
  }

  /// Join a family group using invite code
  Future<bool> joinFamilyGroupByCode(String inviteCode, String userId) async {
    try {
      // Rechercher le groupe avec ce code
      final groupResponse = await _databaseService.supabase
          .from('social_groups')
          .select('id')
          .eq('invite_code', inviteCode)
          .eq('is_active', true)
          .maybeSingle();

      if (groupResponse == null) {
        debugPrint('⚠️ Group not found with code: $inviteCode');
        return false;
      }

      final groupId = groupResponse['id'] as String;

      // Vérifier si l'utilisateur est déjà membre
      final memberResponse = await _databaseService.supabase
          .from('group_members')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();

      if (memberResponse != null) {
        // Déjà membre, réactiver si nécessaire
        if (memberResponse['is_active'] == false) {
           await _databaseService.supabase
              .from('group_members')
              .update({'is_active': true})
              .eq('group_id', groupId)
              .eq('user_id', userId);
           
           await _loadFamilyGroups(); // Reload to update local state
           return true;
        }
        return true; // Déjà membre actif
      }

      // Ajouter le membre
      await _databaseService.supabase
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': userId,
            'role': 'member',
            'is_active': true,
          });

      // Mettre à jour le compteur de membres
      final currentCount = await _databaseService.supabase
          .from('social_groups')
          .select('member_count')
          .eq('id', groupId)
          .single();

      final newCount = ((currentCount['member_count'] as num?)?.toInt() ?? 0) + 1;
      await _databaseService.supabase
          .from('social_groups')
          .update({'member_count': newCount})
          .eq('id', groupId);

      // Recharger les groupes pour mettre à jour l'état local
      await _loadFamilyGroups();
      
      notifyListeners();
      debugPrint('✅ User joined family group via code: $inviteCode');
      return true;
    } catch (e) {
      debugPrint('❌ Error joining family group by code: $e');
      return false;
    }
  }

  /// Start a group order
  Future<String?> startGroupOrder({
    required String groupId,
    required String initiatorId,
    required String deliveryAddress,
    DateTime? deadline,
  }) async {
    try {
      // Créer la commande groupe en base de données
      final response = await _databaseService.supabase
          .from('orders')
          .insert({
            'user_id': initiatorId,
            'is_group_order': true,
            'group_id': groupId,
            'delivery_address': deliveryAddress,
            'status': 'pending',
            'subtotal': 0.0,
            'delivery_fee': 0.0,
            'total': 0.0,
            'payment_method': 'cash',
            'payment_status': 'pending',
            'estimated_delivery_time': deadline?.toIso8601String() ??
                DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
          })
          .select()
          .single();

      final orderId = response['id'] as String;

      final GroupOrder groupOrder = GroupOrder(
        id: orderId,
        familyGroupId: groupId,
        initiatorId: initiatorId,
        memberOrders: {},
        totalAmount: 0.0,
        status: 'collecting',
        createdAt: DateTime.parse(response['created_at'] as String),
        deadlineAt: deadline ?? DateTime.now().add(const Duration(hours: 1)),
        deliveryAddress: deliveryAddress,
      );

      _groupOrders.add(groupOrder);
      notifyListeners();

      // Notify group members
      await _notifyGroupMembers(groupId, 'Nouvelle commande groupe démarrée !');

      debugPrint('✅ Group order created and saved to database: $orderId');
      return orderId;
    } catch (e) {
      debugPrint('❌ Error starting group order: $e');
      return null;
    }
  }

  /// Add items to a group order
  Future<bool> addToGroupOrder({
    required String groupOrderId,
    required String userId,
    required List<MenuItem> items,
  }) async {
    try {
      final int index = _groupOrders.indexWhere((o) => o.id == groupOrderId);
      if (index == -1) return false;

      final order = _groupOrders[index];
      if (order.status != 'collecting') return false;

      final Map<String, List<MenuItem>> newMemberOrders =
          Map.from(order.memberOrders);
      newMemberOrders[userId] = items;

      double newTotal = 0.0;
      newMemberOrders.forEach((userId, userItems) {
        newTotal += userItems.fold(0.0, (sum, item) => sum + item.price);
      });

      final GroupOrder updatedOrder = GroupOrder(
        id: order.id,
        familyGroupId: order.familyGroupId,
        initiatorId: order.initiatorId,
        memberOrders: newMemberOrders,
        totalAmount: newTotal,
        status: order.status,
        createdAt: order.createdAt,
        deadlineAt: order.deadlineAt,
        deliveryAddress: order.deliveryAddress,
      );

      _groupOrders[index] = updatedOrder;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error adding to group order: $e');
      return false;
    }
  }

  /// Confirm a group order
  Future<bool> confirmGroupOrder(String groupOrderId) async {
    try {
      final int index = _groupOrders.indexWhere((o) => o.id == groupOrderId);
      if (index == -1) {
        debugPrint('⚠️ Group order not found: $groupOrderId');
        return false;
      }

      final order = _groupOrders[index];

      // Mettre à jour le statut en base de données
      await _databaseService.supabase
          .from('orders')
          .update({
            'status': 'confirmed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', groupOrderId);

      final GroupOrder confirmedOrder = GroupOrder(
        id: order.id,
        familyGroupId: order.familyGroupId,
        initiatorId: order.initiatorId,
        memberOrders: order.memberOrders,
        totalAmount: order.totalAmount,
        status: 'confirmed',
        createdAt: order.createdAt,
        deadlineAt: order.deadlineAt,
        deliveryAddress: order.deliveryAddress,
      );

      _groupOrders[index] = confirmedOrder;
      notifyListeners();

      // Notify group members
      try {
        final group = _familyGroups.firstWhere((g) => g.id == order.familyGroupId);
        await _notifyGroupMembers(group.id,
            'Commande groupe confirmée ! Total: ${order.totalAmount.toInt()} CFA',);
      } catch (e) {
        debugPrint('⚠️ Could not notify group members: $e');
      }

      debugPrint('✅ Group order confirmed: $groupOrderId');
      return true;
    } catch (e) {
      debugPrint('❌ Error confirming group order: $e');
      return false;
    }
  }

  Future<void> _notifyGroupMembers(String groupId, String message) async {
    // Simulate sending notifications to group members
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('Notification to group $groupId: $message');
  }

  /// Get family groups for a user
  List<FamilyGroup> getUserFamilyGroups(String userId) {
    return _familyGroups
        .where((group) => group.memberIds.contains(userId) && group.isActive)
        .toList();
  }

  /// Get active group orders for a user
  List<GroupOrder> getUserGroupOrders(String userId) {
    return _groupOrders.where((order) {
      // User is either initiator or has added items
      return order.initiatorId == userId ||
          order.memberOrders.containsKey(userId);
    }).toList();
  }

  /// Get group orders for a family group
  List<GroupOrder> getFamilyGroupOrders(String groupId) {
    return _groupOrders
        .where((order) => order.familyGroupId == groupId)
        .toList();
  }

  // Social Features

  /// Like a post
  Future<bool> likePost(String postId, String userId) async {
    try {
      // Vérifier si l'utilisateur a déjà liké ce post
      final existingLike = await _databaseService.supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Supprimer le like (unlike)
        await _databaseService.supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Récupérer le nombre actuel de likes
        final currentPost = await _databaseService.supabase
            .from('social_posts')
            .select('likes_count')
            .eq('id', postId)
            .single();

        final currentLikes = (currentPost['likes_count'] as num?)?.toInt() ?? 0;
        final newLikesCount = (currentLikes > 0) ? currentLikes - 1 : 0;

        // Mettre à jour le compteur dans social_posts
        await _databaseService.supabase
            .from('social_posts')
            .update({'likes_count': newLikesCount})
            .eq('id', postId);

        // Mettre à jour la liste locale
        _updatePostLikes(postId, newLikesCount);

        debugPrint('✅ Post unliked: $postId');
        return false;
      } else {
        // Ajouter le like
        await _databaseService.supabase
            .from('post_likes')
            .insert({
              'post_id': postId,
              'user_id': userId,
            });

        // Récupérer le nombre actuel de likes
        final currentPost = await _databaseService.supabase
            .from('social_posts')
            .select('likes_count')
            .eq('id', postId)
            .single();

        final currentLikes = (currentPost['likes_count'] as num?)?.toInt() ?? 0;
        final newLikesCount = currentLikes + 1;

        // Mettre à jour le compteur dans social_posts
        await _databaseService.supabase
            .from('social_posts')
            .update({'likes_count': newLikesCount})
            .eq('id', postId);

        // Mettre à jour la liste locale
        _updatePostLikes(postId, newLikesCount);

        debugPrint('✅ Post liked and saved to database: $postId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error liking post: $e');
      return false;
    }
  }

  /// Helper method to update post likes in local cache
  void _updatePostLikes(String postId, int newLikesCount) {
    final int index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final SocialPost updatedPost = SocialPost(
        id: post.id,
        userId: post.userId,
        userName: post.userName,
        content: post.content,
        type: post.type,
        metadata: post.metadata,
        createdAt: post.createdAt,
        likes: newLikesCount,
        comments: post.comments,
        imageUrl: post.imageUrl,
      );

      _posts[index] = updatedPost;
      notifyListeners();
    }
  }

  /// Comment on a post
  Future<bool> commentOnPost(
      String postId, String userId, String comment,) async {
    try {
      // Sauvegarder le commentaire en base de données
      final response = await _databaseService.supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': comment,
          })
          .select()
          .single();

      // Récupérer le nombre actuel de commentaires
      final currentPost = await _databaseService.supabase
          .from('social_posts')
          .select('comments_count')
          .eq('id', postId)
          .single();

      final currentComments = (currentPost['comments_count'] as num?)?.toInt() ?? 0;
      final newCommentsCount = currentComments + 1;

      // Mettre à jour le compteur de commentaires
      await _databaseService.supabase
          .from('social_posts')
          .update({'comments_count': newCommentsCount})
          .eq('id', postId);

      // Récupérer tous les commentaires du post
      final commentsResponse = await _databaseService.supabase
          .from('post_comments')
          .select('content')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final comments = (commentsResponse as List)
          .map((c) => c['content'] as String)
          .toList();

      // Mettre à jour la liste locale
      final int index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        final SocialPost commentedPost = SocialPost(
          id: post.id,
          userId: post.userId,
          userName: post.userName,
          content: post.content,
          type: post.type,
          metadata: post.metadata,
          createdAt: post.createdAt,
          likes: post.likes,
          comments: comments,
          imageUrl: post.imageUrl,
        );

        _posts[index] = commentedPost;
        notifyListeners();
      }

      debugPrint('✅ Comment added and saved to database: ${response['id']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error commenting on post: $e');
      return false;
    }
  }

  /// Get trending hashtags
  List<String> getTrendingHashtags() {
    return [
      '#FastFoodGo',
      '#ElCorazón',
      '#BurgerClassic',
      '#PizzaTime',
      '#Délicieux',
      '#FastDelivery',
      '#FoodLover',
      '#Bamako',
      '#Mali',
      '#LocalFood',
    ];
  }

  /// Get popular social templates
  List<Map<String, dynamic>> getSocialTemplates() {
    return [
      {
        'id': 'order_joy',
        'title': 'Commande Réussie',
        'template':
            '🎉 Ma commande FastFoodGo est arrivée ! {items} 😋 #FastFoodGo #Délicieux',
        'category': 'order',
      },
      {
        'id': 'recommendation',
        'title': 'Recommandation',
        'template':
            '👌 Je recommande le {item} de FastFoodGo ! Un délice ! #Recommandation #FastFoodGo',
        'category': 'review',
      },
      {
        'id': 'group_order',
        'title': 'Commande Groupe',
        'template':
            '👨‍👩‍👧‍👦 Commande en famille avec FastFoodGo ! Tout le monde est content 😊 #FamilyTime #FastFoodGo',
        'category': 'group',
      },
      {
        'id': 'achievement',
        'title': 'Nouveau Badge',
        'template':
            '🏆 Nouveau badge débloqué sur FastFoodGo ! {achievement} 🎯 #Achievement #FastFoodGo',
        'category': 'gamification',
      },
    ];
  }

  /// Generate social content with AI
  Future<String> generateSocialContent({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    switch (type) {
      case 'order':
        final List<String> items = List<String>.from(data['items'] ?? []);
        return '🍔 Super commande aujourd\'hui ! ${items.join(', ')} était délicieux ! Merci FastFoodGo 😋 #FastFoodGo #Délicieux';

      case 'review':
        final String item = data['itemName'] ?? 'ce plat';
        final int rating = data['rating'] ?? 5;
        return '⭐ ${'★' * rating}${'☆' * (5 - rating)} $item de FastFoodGo ! ${rating >= 4 ? 'Excellent' : 'Pas mal'} ! #FastFoodGo #Avis';

      case 'achievement':
        final String achievement = data['achievement'] ?? 'nouveau badge';
        return '🏆 Fier d\'avoir débloqué "$achievement" sur FastFoodGo ! 💪 #Achievement #FastFoodGo #Gamification';

      default:
        return '🍴 Encore un bon moment avec FastFoodGo ! #FastFoodGo';
    }
  }

  // CRUD Operations for Posts

  /// Delete a social post
  Future<bool> deletePost(String postId, String userId) async {
    try {
      // Vérifier que l'utilisateur est le propriétaire du post
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex == -1) {
        debugPrint('⚠️ Post not found: $postId');
        return false;
      }

      final post = _posts[postIndex];
      if (post.userId != userId) {
        debugPrint('⚠️ User is not the owner of the post');
        return false;
      }

      // Supprimer le post de la base de données
      await _databaseService.supabase
          .from('social_posts')
          .delete()
          .eq('id', postId);

      // Supprimer de la liste locale
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();

      debugPrint('✅ Post deleted: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting post: $e');
      return false;
    }
  }

  /// Update a social post
  Future<bool> updatePost(String postId, String userId, String newContent) async {
    try {
      // Vérifier que l'utilisateur est le propriétaire du post
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex == -1) {
        debugPrint('⚠️ Post not found: $postId');
        return false;
      }

      final post = _posts[postIndex];
      if (post.userId != userId) {
        debugPrint('⚠️ User is not the owner of the post');
        return false;
      }

      // Mettre à jour le post en base de données
      await _databaseService.supabase
          .from('social_posts')
          .update({
            'content': newContent,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', postId);

      // Mettre à jour la liste locale
      final int index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final updatedPost = _posts[index];
        final SocialPost newPost = SocialPost(
          id: updatedPost.id,
          userId: updatedPost.userId,
          userName: updatedPost.userName,
          content: newContent,
          type: updatedPost.type,
          metadata: updatedPost.metadata,
          createdAt: updatedPost.createdAt,
          likes: updatedPost.likes,
          comments: updatedPost.comments,
          imageUrl: updatedPost.imageUrl,
        );

        _posts[index] = newPost;
        notifyListeners();
      }

      debugPrint('✅ Post updated: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating post: $e');
      return false;
    }
  }

  // CRUD Operations for Family Groups

  /// Leave a family group
  Future<bool> leaveFamilyGroup(String groupId, String userId) async {
    try {
      final int index = _familyGroups.indexWhere((g) => g.id == groupId);
      if (index == -1) {
        debugPrint('⚠️ Family group not found: $groupId');
        return false;
      }

      final group = _familyGroups[index];
      if (!group.memberIds.contains(userId)) {
        debugPrint('⚠️ User is not a member of the group');
        return false;
      }

      // Si c'est le propriétaire, on ne peut pas quitter (doit supprimer le groupe)
      if (group.ownerId == userId) {
        debugPrint('⚠️ Owner cannot leave group, must delete it instead');
        return false;
      }

      // Retirer le membre de la base de données
      await _databaseService.supabase
          .from('group_members')
          .update({'is_active': false})
          .eq('group_id', groupId)
          .eq('user_id', userId);

      // Mettre à jour le compteur de membres
      final currentCount = await _databaseService.supabase
          .from('social_groups')
          .select('member_count')
          .eq('id', groupId)
          .single();

      final newCount = ((currentCount['member_count'] as num?)?.toInt() ?? 1) - 1;
      await _databaseService.supabase
          .from('social_groups')
          .update({'member_count': newCount > 0 ? newCount : 0})
          .eq('id', groupId);

      // Mettre à jour la liste locale
      final List<String> newMembers = List.from(group.memberIds)..remove(userId);

      final FamilyGroup updatedGroup = FamilyGroup(
        id: group.id,
        name: group.name,
        ownerId: group.ownerId,
        memberIds: newMembers,
        createdAt: group.createdAt,
        description: group.description,
        isActive: group.isActive,
        settings: group.settings,
      );

      _familyGroups[index] = updatedGroup;
      notifyListeners();

      debugPrint('✅ User left family group: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Error leaving family group: $e');
      return false;
    }
  }

  /// Delete a family group
  Future<bool> deleteFamilyGroup(String groupId, String userId) async {
    try {
      final int index = _familyGroups.indexWhere((g) => g.id == groupId);
      if (index == -1) {
        debugPrint('⚠️ Family group not found: $groupId');
        return false;
      }

      final group = _familyGroups[index];
      if (group.ownerId != userId) {
        debugPrint('⚠️ Only the owner can delete the group');
        return false;
      }

      // Désactiver le groupe en base de données (soft delete)
      await _databaseService.supabase
          .from('social_groups')
          .update({'is_active': false})
          .eq('id', groupId);

      // Désactiver tous les membres
      await _databaseService.supabase
          .from('group_members')
          .update({'is_active': false})
          .eq('group_id', groupId);

      // Retirer de la liste locale
      _familyGroups.removeAt(index);
      notifyListeners();

      debugPrint('✅ Family group deleted: $groupId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting family group: $e');
      return false;
    }
  }

  void clearSocialData() {
    _posts.clear();
    _familyGroups.clear();
    _groupOrders.clear();
    notifyListeners();
  }
}
