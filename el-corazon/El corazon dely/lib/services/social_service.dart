import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import 'database_service.dart';

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
    this.deadlineAt,
    required this.deliveryAddress,
  });
}

class SocialService extends ChangeNotifier {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final DatabaseService _databaseService = DatabaseService();
  List<SocialPost> _posts = [];
  List<FamilyGroup> _familyGroups = [];
  final List<GroupOrder> _groupOrders = [];
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
      // Load social posts from database
      final currentUser = _databaseService.currentUser;
      if (currentUser != null) {
        // Get user profile to get user ID
        final userProfile =
            await _databaseService.getUserProfile(currentUser.id);
        if (userProfile != null) {
          final userId = userProfile['id'] as String;

          // Load social posts
          final postsData = await _databaseService.getSocialPosts();
          _posts = postsData.map((data) {
            final userData = data['users'] as Map<String, dynamic>?;
            return SocialPost(
              id: data['id'] as String,
              userId: data['user_id'] as String,
              userName: userData?['name'] as String? ?? 'Utilisateur',
              content: data['content'] as String,
              type: data['post_type'] as String,
              metadata: {
                'orderId': data['order_id'],
                'imageUrl': data['image_url'],
              },
              createdAt: DateTime.parse(data['created_at'] as String),
              likes: data['likes_count'] as int? ?? 0,
              comments: [], // Will be loaded separately if needed
              imageUrl: data['image_url'] as String?,
            );
          }).toList();

          // Load social groups
          final groupsData = await _databaseService.getSocialGroups(userId);
          _familyGroups = groupsData.map((data) {
            final groupData = data['social_groups'] as Map<String, dynamic>;
            return FamilyGroup(
              id: groupData['id'] as String,
              name: groupData['name'] as String,
              ownerId: groupData['creator_id'] as String,
              memberIds: [
                groupData['creator_id'] as String
              ], // Will be loaded from group_members
              createdAt: DateTime.parse(groupData['created_at'] as String),
              description: groupData['description'] as String?,
              isActive: groupData['is_active'] as bool? ?? true,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading social data: $e');
      // Fallback to empty lists if database fails
      _posts = [];
      _familyGroups = [];
    }
  }

  // Social Sharing Functions

  /// Share an order on social media
  Future<String?> shareOrder(Order order, String caption,
      {String? imageUrl}) async {
    try {
      final currentUser = _databaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to share order');
      }

      final userProfile = await _databaseService.getUserProfile(currentUser.id);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      final userId = userProfile['id'] as String;

      // Create post in database
      final postId = await _databaseService.createSocialPost(
        userId: userId,
        content: caption,
        postType: 'order_share',
        orderId: order.id,
        imageUrl: imageUrl,
      );

      // Reload posts to include the new one
      await _loadSocialData();
      notifyListeners();

      // Simulate posting to external social platforms
      await _postToExternalPlatforms(_posts.firstWhere((p) => p.id == postId));

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
      {String? badgeImageUrl}) async {
    try {
      final currentUser = _databaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to share achievement');
      }

      final userProfile = await _databaseService.getUserProfile(currentUser.id);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      final dbUserId = userProfile['id'] as String;

      // Create post in database
      final postId = await _databaseService.createSocialPost(
        userId: dbUserId,
        content:
            '🏆 Nouveau badge débloqué : $achievement ! #ElCorazonDely #Achievement',
        postType: 'text',
        imageUrl: badgeImageUrl,
      );

      // Reload posts
      await _loadSocialData();
      notifyListeners();

      return postId;
    } catch (e) {
      debugPrint('Error sharing achievement: $e');
      return null;
    }
  }

  /// Add a food review
  Future<String?> shareReview(
      String userId, MenuItem item, int rating, String review) async {
    try {
      final currentUser = _databaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be logged in to share review');
      }

      final userProfile = await _databaseService.getUserProfile(currentUser.id);
      if (userProfile == null) {
        throw Exception('User profile not found');
      }

      final dbUserId = userProfile['id'] as String;

      // Create post in database
      final postId = await _databaseService.createSocialPost(
        userId: dbUserId,
        content:
            '⭐ ${'★' * rating}${'☆' * (5 - rating)}\n$review\n#${item.name.replaceAll(' ', '')} #ElCorazonDely',
        postType: 'review',
      );

      // Reload posts
      await _loadSocialData();
      notifyListeners();

      return postId;
    } catch (e) {
      debugPrint('Error sharing review: $e');
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
        'description': 'Filtre officiel El Corazon Dely',
        'overlayText': '🍔 El Corazon Dely - El Corazón',
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
      String groupId = DateTime.now().millisecondsSinceEpoch.toString();

      FamilyGroup group = FamilyGroup(
        id: groupId,
        name: name,
        ownerId: ownerId,
        memberIds: [ownerId],
        createdAt: DateTime.now(),
        description: description,
      );

      _familyGroups.add(group);
      notifyListeners();

      return groupId;
    } catch (e) {
      debugPrint('Error creating family group: $e');
      return null;
    }
  }

  /// Invite someone to a family group
  Future<bool> inviteToFamilyGroup(String groupId, String inviteeId) async {
    try {
      int index = _familyGroups.indexWhere((g) => g.id == groupId);
      if (index == -1) return false;

      var group = _familyGroups[index];
      if (group.memberIds.contains(inviteeId)) return false;

      List<String> newMembers = List.from(group.memberIds)..add(inviteeId);

      FamilyGroup updatedGroup = FamilyGroup(
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

      return true;
    } catch (e) {
      debugPrint('Error inviting to family group: $e');
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
      String orderId = DateTime.now().millisecondsSinceEpoch.toString();

      GroupOrder groupOrder = GroupOrder(
        id: orderId,
        familyGroupId: groupId,
        initiatorId: initiatorId,
        memberOrders: {},
        totalAmount: 0.0,
        status: 'collecting',
        createdAt: DateTime.now(),
        deadlineAt: deadline ?? DateTime.now().add(const Duration(hours: 1)),
        deliveryAddress: deliveryAddress,
      );

      _groupOrders.add(groupOrder);
      notifyListeners();

      // Notify group members
      await _notifyGroupMembers(groupId, 'Nouvelle commande groupe démarrée !');

      return orderId;
    } catch (e) {
      debugPrint('Error starting group order: $e');
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
      int index = _groupOrders.indexWhere((o) => o.id == groupOrderId);
      if (index == -1) return false;

      var order = _groupOrders[index];
      if (order.status != 'collecting') return false;

      Map<String, List<MenuItem>> newMemberOrders =
          Map.from(order.memberOrders);
      newMemberOrders[userId] = items;

      double newTotal = 0.0;
      newMemberOrders.forEach((userId, userItems) {
        newTotal += userItems.fold(0.0, (sum, item) => sum + item.price);
      });

      GroupOrder updatedOrder = GroupOrder(
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
      int index = _groupOrders.indexWhere((o) => o.id == groupOrderId);
      if (index == -1) return false;

      var order = _groupOrders[index];

      GroupOrder confirmedOrder = GroupOrder(
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
      FamilyGroup? group =
          _familyGroups.firstWhere((g) => g.id == order.familyGroupId);
      await _notifyGroupMembers(group.id,
          'Commande groupe confirmée ! Total: ${order.totalAmount.toInt()} CFA');

      return true;
    } catch (e) {
      debugPrint('Error confirming group order: $e');
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
      int index = _posts.indexWhere((p) => p.id == postId);
      if (index == -1) return false;

      var post = _posts[index];

      SocialPost likedPost = SocialPost(
        id: post.id,
        userId: post.userId,
        userName: post.userName,
        content: post.content,
        type: post.type,
        metadata: post.metadata,
        createdAt: post.createdAt,
        likes: post.likes + 1,
        comments: post.comments,
        imageUrl: post.imageUrl,
      );

      _posts[index] = likedPost;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error liking post: $e');
      return false;
    }
  }

  /// Comment on a post
  Future<bool> commentOnPost(
      String postId, String userId, String comment) async {
    try {
      int index = _posts.indexWhere((p) => p.id == postId);
      if (index == -1) return false;

      var post = _posts[index];
      List<String> newComments = List.from(post.comments)..add(comment);

      SocialPost commentedPost = SocialPost(
        id: post.id,
        userId: post.userId,
        userName: post.userName,
        content: post.content,
        type: post.type,
        metadata: post.metadata,
        createdAt: post.createdAt,
        likes: post.likes,
        comments: newComments,
        imageUrl: post.imageUrl,
      );

      _posts[index] = commentedPost;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error commenting on post: $e');
      return false;
    }
  }

  /// Get trending hashtags
  List<String> getTrendingHashtags() {
    return [
      '#ElCorazonDely',
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
            '🎉 Ma commande El Corazon Dely est arrivée ! {items} 😋 #ElCorazonDely #Délicieux',
        'category': 'order',
      },
      {
        'id': 'recommendation',
        'title': 'Recommandation',
        'template':
            '👌 Je recommande le {item} de El Corazon Dely ! Un délice ! #Recommandation #ElCorazonDely',
        'category': 'review',
      },
      {
        'id': 'group_order',
        'title': 'Commande Groupe',
        'template':
            '👨‍👩‍👧‍👦 Commande en famille avec El Corazon Dely ! Tout le monde est content 😊 #FamilyTime #ElCorazonDely',
        'category': 'group',
      },
      {
        'id': 'achievement',
        'title': 'Nouveau Badge',
        'template':
            '🏆 Nouveau badge débloqué sur El Corazon Dely ! {achievement} 🎯 #Achievement #ElCorazonDely',
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
        List<String> items = List<String>.from(data['items'] ?? []);
        return '🍔 Super commande aujourd\'hui ! ${items.join(', ')} était délicieux ! Merci El Corazon Dely 😋 #ElCorazonDely #Délicieux';

      case 'review':
        String item = data['itemName'] ?? 'ce plat';
        int rating = data['rating'] ?? 5;
        return '⭐ ${'★' * rating}${'☆' * (5 - rating)} $item de El Corazon Dely ! ${rating >= 4 ? 'Excellent' : 'Pas mal'} ! #ElCorazonDely #Avis';

      case 'achievement':
        String achievement = data['achievement'] ?? 'nouveau badge';
        return '🏆 Fier d\'avoir débloqué "$achievement" sur El Corazon Dely ! 💪 #Achievement #ElCorazonDely #Gamification';

      default:
        return '🍴 Encore un bon moment avec El Corazon Dely ! #ElCorazonDely';
    }
  }

  void clearSocialData() {
    _posts.clear();
    _familyGroups.clear();
    _groupOrders.clear();
    notifyListeners();
  }
}
