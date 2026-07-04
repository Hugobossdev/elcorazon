import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../utils/price_formatter.dart';

class SocialFeaturesService extends ChangeNotifier {
  static final SocialFeaturesService _instance =
      SocialFeaturesService._internal();
  factory SocialFeaturesService() => _instance;
  SocialFeaturesService._internal();

  final List<SocialGroup> _groups = [];
  final List<SocialPost> _posts = [];
  final List<SocialEvent> _events = [];
  final Map<String, List<SocialPost>> _userPosts = {};
  final Map<String, List<String>> _userFollowers = {};
  final Map<String, List<String>> _userFollowing = {};

  // Getters
  List<SocialGroup> get groups => List.unmodifiable(_groups);
  List<SocialPost> get posts => List.unmodifiable(_posts);
  List<SocialEvent> get events => List.unmodifiable(_events);

  /// Crée un groupe social
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required String creatorId,
    SocialGroupType type = SocialGroupType.family,
    bool isPrivate = false,
  }) async {
    final group = SocialGroup(
      id: _generateId(),
      name: name,
      description: description,
      creatorId: creatorId,
      type: type,
      isPrivate: isPrivate,
      memberIds: [creatorId],
      createdAt: DateTime.now(),
      imageUrl: _getDefaultGroupImage(type),
    );

    _groups.add(group);
    notifyListeners();

    debugPrint('SocialFeaturesService: Groupe créé - ${group.name}');
    return group;
  }

  /// Rejoint un groupe
  Future<void> joinGroup(String groupId, String userId) async {
    final group = _groups.firstWhere((g) => g.id == groupId);

    if (!group.memberIds.contains(userId)) {
      group.memberIds.add(userId);
      notifyListeners();

      debugPrint(
        'SocialFeaturesService: Utilisateur $userId a rejoint le groupe ${group.name}',
      );
    }
  }

  /// Quitte un groupe
  Future<void> leaveGroup(String groupId, String userId) async {
    final group = _groups.firstWhere((g) => g.id == groupId);
    group.memberIds.remove(userId);

    // Si le créateur quitte, transférer la propriété au premier membre
    if (group.creatorId == userId && group.memberIds.isNotEmpty) {
      // Note: creatorId est final, donc on ne peut pas le modifier
      // Dans une vraie implémentation, il faudrait créer une nouvelle instance du groupe
    }

    notifyListeners();
    debugPrint(
      'SocialFeaturesService: Utilisateur $userId a quitté le groupe ${group.name}',
    );
  }

  /// Crée un post social
  Future<SocialPost> createPost({
    required String userId,
    required String content,
    required SocialPostType type,
    String? groupId,
    String? orderId,
    List<String>? imageUrls,
    Map<String, dynamic>? metadata,
  }) async {
    final post = SocialPost(
      id: _generateId(),
      userId: userId,
      content: content,
      type: type,
      groupId: groupId,
      orderId: orderId,
      imageUrls: imageUrls ?? [],
      metadata: metadata ?? {},
      likes: 0,
      comments: [],
      createdAt: DateTime.now(),
    );

    _posts.add(post);
    _userPosts[userId] = (_userPosts[userId] ?? [])..add(post);
    notifyListeners();

    debugPrint('SocialFeaturesService: Post créé par $userId');
    return post;
  }

  /// Like un post
  Future<void> likePost(String postId, String userId) async {
    final post = _posts.firstWhere((p) => p.id == postId);

    if (!post.likedBy.contains(userId)) {
      post.likedBy.add(userId);
      post.likes++;
      notifyListeners();

      debugPrint('SocialFeaturesService: Post $postId liké par $userId');
    }
  }

  /// Unlike un post
  Future<void> unlikePost(String postId, String userId) async {
    final post = _posts.firstWhere((p) => p.id == postId);

    if (post.likedBy.contains(userId)) {
      post.likedBy.remove(userId);
      post.likes--;
      notifyListeners();

      debugPrint('SocialFeaturesService: Post $postId unliké par $userId');
    }
  }

  /// Ajoute un commentaire
  Future<void> addComment(String postId, String userId, String content) async {
    final post = _posts.firstWhere((p) => p.id == postId);
    final comment = SocialComment(
      id: _generateId(),
      userId: userId,
      content: content,
      createdAt: DateTime.now(),
    );

    post.comments.add(comment);
    notifyListeners();

    debugPrint('SocialFeaturesService: Commentaire ajouté au post $postId');
  }

  /// Suit un utilisateur
  Future<void> followUser(String followerId, String followingId) async {
    _userFollowing[followerId] = (_userFollowing[followerId] ?? [])
      ..add(followingId);
    _userFollowers[followingId] = (_userFollowers[followingId] ?? [])
      ..add(followerId);

    notifyListeners();
    debugPrint(
      'SocialFeaturesService: $followerId suit maintenant $followingId',
    );
  }

  /// Ne suit plus un utilisateur
  Future<void> unfollowUser(String followerId, String followingId) async {
    _userFollowing[followerId]?.remove(followingId);
    _userFollowers[followingId]?.remove(followerId);

    notifyListeners();
    debugPrint('SocialFeaturesService: $followerId ne suit plus $followingId');
  }

  /// Partage une commande
  Future<SocialPost> shareOrder({
    required String userId,
    required Order order,
    String? groupId,
    String? customMessage,
  }) async {
    final content =
        customMessage ??
        'J\'ai commandé chez El Corazón! 🍔\n\nCommande #${order.id.substring(0, 8)} pour ${PriceFormatter.format(order.total)}';

    final metadata = {
      'orderId': order.id,
      'total': order.total,
      'itemCount': order.items.length,
      'items': order.items.map((item) => item.name).toList(),
    };

    return await createPost(
      userId: userId,
      content: content,
      type: SocialPostType.order,
      groupId: groupId,
      orderId: order.id,
      metadata: metadata,
    );
  }

  /// Partage une recommandation
  Future<SocialPost> shareRecommendation({
    required String userId,
    required MenuItem item,
    required double rating,
    String? review,
    String? groupId,
  }) async {
    final content =
        review ??
        'Je recommande ${item.name} chez El Corazón! ⭐ ${rating.toStringAsFixed(1)}/5';

    final metadata = {
      'itemId': item.id,
      'itemName': item.name,
      'rating': rating,
      'category': item.category.displayName,
      'price': item.price,
    };

    return await createPost(
      userId: userId,
      content: content,
      type: SocialPostType.recommendation,
      groupId: groupId,
      metadata: metadata,
    );
  }

  /// Crée un événement social
  Future<SocialEvent> createEvent({
    required String name,
    required String description,
    required DateTime date,
    required String organizerId,
    String? location,
    String? groupId,
    List<String>? attendeeIds,
  }) async {
    final event = SocialEvent(
      id: _generateId(),
      name: name,
      description: description,
      date: date,
      organizerId: organizerId,
      location: location,
      groupId: groupId,
      attendeeIds: attendeeIds ?? [organizerId],
      createdAt: DateTime.now(),
    );

    _events.add(event);
    notifyListeners();

    debugPrint('SocialFeaturesService: Événement créé - ${event.name}');
    return event;
  }

  /// Rejoint un événement
  Future<void> joinEvent(String eventId, String userId) async {
    final event = _events.firstWhere((e) => e.id == eventId);

    if (!event.attendeeIds.contains(userId)) {
      event.attendeeIds.add(userId);
      notifyListeners();

      debugPrint(
        'SocialFeaturesService: Utilisateur $userId a rejoint l\'événement ${event.name}',
      );
    }
  }

  /// Obtient les posts du feed d'un utilisateur
  List<SocialPost> getUserFeed(String userId) {
    final following = _userFollowing[userId] ?? [];
    final userGroups = _groups
        .where((g) => g.memberIds.contains(userId))
        .map((g) => g.id)
        .toList();

    return _posts.where((post) {
      return following.contains(post.userId) ||
          userGroups.contains(post.groupId) ||
          post.userId == userId;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Obtient les posts d'un groupe
  List<SocialPost> getGroupPosts(String groupId) {
    return _posts.where((post) => post.groupId == groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Obtient les groupes d'un utilisateur
  List<SocialGroup> getUserGroups(String userId) {
    return _groups.where((group) => group.memberIds.contains(userId)).toList();
  }

  /// Obtient les statistiques sociales d'un utilisateur
  SocialStats getUserSocialStats(String userId) {
    final userPosts = _userPosts[userId] ?? [];
    final followers = _userFollowers[userId] ?? [];
    final following = _userFollowing[userId] ?? [];
    final userGroups = getUserGroups(userId);

    return SocialStats(
      postsCount: userPosts.length,
      followersCount: followers.length,
      followingCount: following.length,
      groupsCount: userGroups.length,
      totalLikes: userPosts.fold(0, (sum, post) => sum + post.likes),
    );
  }

  /// Génère des posts de recommandation automatiques
  Future<void> generateAutoRecommendations() async {
    // Simulation de recommandations automatiques basées sur les commandes populaires
    final popularItems = [
      'El Corazón Burger',
      'Margherita Pizza',
      'Chicken Nuggets',
      'Frites Dorées',
      'Coca-Cola',
    ];

    for (final itemName in popularItems) {
      final post = SocialPost(
        id: _generateId(),
        userId: 'system',
        content:
            '🔥 $itemName est très populaire aujourd\'hui! Commandez maintenant!',
        type: SocialPostType.promotion,
        imageUrls: [],
        metadata: {'isAutoGenerated': true, 'itemName': itemName},
        likes: Random().nextInt(50),
        comments: [],
        createdAt: DateTime.now().subtract(
          Duration(minutes: Random().nextInt(60)),
        ),
      );

      _posts.add(post);
    }

    notifyListeners();
    debugPrint('SocialFeaturesService: Recommandations automatiques générées');
  }

  /// Obtient l'image par défaut pour un type de groupe
  String _getDefaultGroupImage(SocialGroupType type) {
    switch (type) {
      case SocialGroupType.family:
        return 'https://example.com/family-group.png';
      case SocialGroupType.friends:
        return 'https://example.com/friends-group.png';
      case SocialGroupType.work:
        return 'https://example.com/work-group.png';
      case SocialGroupType.neighborhood:
        return 'https://example.com/neighborhood-group.png';
    }
  }

  /// Génère un ID unique
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }
}

class SocialGroup {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final SocialGroupType type;
  final bool isPrivate;
  final List<String> memberIds;
  final DateTime createdAt;
  final String imageUrl;

  SocialGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.type,
    required this.isPrivate,
    required this.memberIds,
    required this.createdAt,
    required this.imageUrl,
  });
}

class SocialPost {
  final String id;
  final String userId;
  final String content;
  final SocialPostType type;
  final String? groupId;
  final String? orderId;
  final List<String> imageUrls;
  final Map<String, dynamic> metadata;
  int likes;
  final List<String> likedBy;
  final List<SocialComment> comments;
  final DateTime createdAt;

  SocialPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.type,
    this.groupId,
    this.orderId,
    required this.imageUrls,
    required this.metadata,
    required this.likes,
    List<String>? likedBy,
    List<SocialComment>? comments,
    required this.createdAt,
  }) : likedBy = likedBy ?? [],
       comments = comments ?? [];
}

class SocialComment {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;

  SocialComment({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
  });
}

class SocialEvent {
  final String id;
  final String name;
  final String description;
  final DateTime date;
  final String organizerId;
  final String? location;
  final String? groupId;
  final List<String> attendeeIds;
  final DateTime createdAt;

  SocialEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.organizerId,
    this.location,
    this.groupId,
    required this.attendeeIds,
    required this.createdAt,
  });
}

class SocialStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int groupsCount;
  final int totalLikes;

  SocialStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.groupsCount,
    required this.totalLikes,
  });
}

enum SocialGroupType { family, friends, work, neighborhood }

enum SocialPostType { order, recommendation, promotion, event, general }
