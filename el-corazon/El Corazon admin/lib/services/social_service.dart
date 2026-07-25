import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/menu_models.dart';

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
    await Future.delayed(const Duration(milliseconds: 300));

    // Mock data
    _posts = [
      SocialPost(
        id: '1',
        userId: 'user123',
        userName: 'Marie Traoré',
        content: 'Délicieux burger aujourd\'hui ! 😋 #FastFoodGo',
        type: 'order',
        metadata: {
          'orderId': 'order123',
          'items': ['Burger Classic'],
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 15,
        comments: ['Ça a l\'air délicieux !', 'Je vais commander le même'],
        imageUrl: 'burger_post.jpg',
      ),
    ];

    _familyGroups = [
      FamilyGroup(
        id: 'family1',
        name: 'Famille Traoré',
        ownerId: 'user123',
        memberIds: ['user123', 'user456', 'user789'],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        description: 'Notre groupe familial pour les commandes ensemble',
      ),
    ];
  }

  // Social Sharing Functions

  /// Share an order on social media
  Future<String?> shareOrder(
    Order order,
    String caption, {
    String? imageUrl,
  }) async {
    try {
      String postId = DateTime.now().millisecondsSinceEpoch.toString();

      SocialPost post = SocialPost(
        id: postId,
        userId: order.userId,
        userName: 'Utilisateur', // In real app, get from user service
        content: caption,
        type: 'order',
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
  Future<String?> shareAchievement(
    String userId,
    String achievement, {
    String? badgeImageUrl,
  }) async {
    try {
      String postId = DateTime.now().millisecondsSinceEpoch.toString();

      SocialPost post = SocialPost(
        id: postId,
        userId: userId,
        userName: 'Utilisateur',
        content:
            '🏆 Nouveau badge débloqué : $achievement ! #FastFoodGo #Achievement',
        type: 'achievement',
        metadata: {'achievement': achievement, 'badgeImage': badgeImageUrl},
        createdAt: DateTime.now(),
        imageUrl: badgeImageUrl,
      );

      _posts.insert(0, post);
      notifyListeners();

      return postId;
    } catch (e) {
      debugPrint('Error sharing achievement: $e');
      return null;
    }
  }

  /// Add a food review
  Future<String?> shareReview(
    String userId,
    MenuItem item,
    int rating,
    String review,
  ) async {
    try {
      String postId = DateTime.now().millisecondsSinceEpoch.toString();

      SocialPost post = SocialPost(
        id: postId,
        userId: userId,
        userName: 'Utilisateur',
        content:
            '⭐ ${'★' * rating}${'☆' * (5 - rating)}\n$review\n#${item.name.replaceAll(' ', '')} #FastFoodGo',
        type: 'review',
        metadata: {'itemId': item.id, 'itemName': item.name, 'rating': rating},
        createdAt: DateTime.now(),
      );

      _posts.insert(0, post);
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

      Map<String, List<MenuItem>> newMemberOrders = Map.from(
        order.memberOrders,
      );
      newMemberOrders[userId] = items;

      double newTotal = 0.0;
      newMemberOrders.forEach((userId, userItems) {
        newTotal += userItems.fold(0.0, (sum, item) => sum + item.basePrice);
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
      FamilyGroup? group = _familyGroups.firstWhere(
        (g) => g.id == order.familyGroupId,
      );
      await _notifyGroupMembers(
        group.id,
        'Commande groupe confirmée ! Total: ${order.totalAmount.toInt()} CFA',
      );

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
    String postId,
    String userId,
    String comment,
  ) async {
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
        List<String> items = List<String>.from(data['items'] ?? []);
        return '🍔 Super commande aujourd\'hui ! ${items.join(', ')} était délicieux ! Merci FastFoodGo 😋 #FastFoodGo #Délicieux';

      case 'review':
        String item = data['itemName'] ?? 'ce plat';
        int rating = data['rating'] ?? 5;
        return '⭐ ${'★' * rating}${'☆' * (5 - rating)} $item de FastFoodGo ! ${rating >= 4 ? 'Excellent' : 'Pas mal'} ! #FastFoodGo #Avis';

      case 'achievement':
        String achievement = data['achievement'] ?? 'nouveau badge';
        return '🏆 Fier d\'avoir débloqué "$achievement" sur FastFoodGo ! 💪 #Achievement #FastFoodGo #Gamification';

      default:
        return '🍴 Encore un bon moment avec FastFoodGo ! #FastFoodGo';
    }
  }

  void clearSocialData() {
    _posts.clear();
    _familyGroups.clear();
    _groupOrders.clear();
    notifyListeners();
  }
}
