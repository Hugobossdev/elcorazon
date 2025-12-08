import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductReview {
  final String id;
  final String menuItemId;
  final String userId;
  final String userName;
  final double rating;
  final String title;
  final String comment;
  final List<String>? photos;
  final bool isVerifiedPurchase;
  final DateTime createdAt;
  final bool isHelpful;

  ProductReview({
    required this.id,
    required this.menuItemId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.title,
    required this.comment,
    required this.createdAt, this.photos,
    this.isVerifiedPurchase = false,
    this.isHelpful = false,
  });

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id'] as String,
      menuItemId: map['menu_item_id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      rating: (map['rating'] as num).toDouble(),
      title: map['title'] as String? ?? '',
      comment: map['comment'] as String,
      photos: map['photos'] != null ? List<String>.from(map['photos']) : null,
      isVerifiedPurchase: map['is_verified_purchase'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at']),
      isHelpful:
          map['helpful_count'] != null && (map['helpful_count'] as num) > 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_item_id': menuItemId,
      'user_id': userId,
      'user_name': userName,
      'rating': rating,
      'title': title,
      'comment': comment,
      'photos': photos,
      'is_verified_purchase': isVerifiedPurchase,
    };
  }
}

class ProductRating {
  final String menuItemId;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // rating -> count

  ProductRating({
    required this.menuItemId,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  factory ProductRating.fromMap(Map<String, dynamic> map) {
    return ProductRating(
      menuItemId: map['menu_item_id'] as String,
      averageRating: (map['average_rating'] as num).toDouble(),
      totalReviews: map['total_reviews'] as int,
      ratingDistribution: Map<int, int>.from(map['rating_distribution'] ?? {}),
    );
  }
}

class ReviewRatingService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<ProductReview> _reviews = [];
  final Map<String, ProductRating> _ratings = {};
  bool _isLoading = false;
  String? _error;

  List<ProductReview> get reviews => List.unmodifiable(_reviews);
  Map<String, ProductRating> get ratings => Map.unmodifiable(_ratings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charger les reviews d'un produit
  Future<void> loadReviews(String menuItemId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .eq('menu_item_id', menuItemId)
          .order('created_at', ascending: false);

      _reviews = (response as List)
          .map((item) => ProductReview.fromMap(item))
          .toList();

      debugPrint('✅ Chargé ${_reviews.length} reviews pour $menuItemId');
    } catch (e) {
      _error = 'Erreur lors du chargement des reviews: $e';
      debugPrint('❌ $_error');
      _reviews = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger le rating d'un produit
  Future<void> loadRating(String menuItemId) async {
    try {
      // Calculer la moyenne des ratings
      final response = await _supabase
          .from('product_reviews')
          .select('rating')
          .eq('menu_item_id', menuItemId);

      final ratings = (response as List)
          .map((r) => (r['rating'] as num).toDouble())
          .toList();

      if (ratings.isEmpty) {
        _ratings[menuItemId] = ProductRating(
          menuItemId: menuItemId,
          averageRating: 0,
          totalReviews: 0,
          ratingDistribution: {},
        );
        return;
      }

      // Calculer la distribution
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final rating in ratings) {
        final intRating = rating.round();
        distribution[intRating] = (distribution[intRating] ?? 0) + 1;
      }

      final average = ratings.reduce((a, b) => a + b) / ratings.length;

      _ratings[menuItemId] = ProductRating(
        menuItemId: menuItemId,
        averageRating: average,
        totalReviews: ratings.length,
        ratingDistribution: distribution,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors du chargement du rating: $e');
    }
  }

  /// Ajouter une review (ou mettre à jour si elle existe déjà)
  Future<bool> addReview(ProductReview review) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Utiliser upsert pour créer ou mettre à jour la review
      // Cela évite l'erreur 409 si la review existe déjà
      final response = await _supabase
          .from('product_reviews')
          .upsert(
            review.toMap(),
            onConflict: 'menu_item_id,user_id', // Colonnes de la contrainte unique
          )
          .select()
          .single();

      final newReview = ProductReview.fromMap(response);
      
      // Retirer l'ancienne review si elle existe et ajouter la nouvelle
      _reviews.removeWhere((r) => 
          r.menuItemId == review.menuItemId && r.userId == review.userId,);
      _reviews.insert(0, newReview);

      // Mettre à jour le rating
      await loadRating(review.menuItemId);

      debugPrint('✅ Review ajoutée/mise à jour: ${newReview.id}');
      return true;
    } on PostgrestException catch (e) {
      // Gérer spécifiquement les erreurs PostgREST
      if (e.code == '23505') {
        // Contrainte unique violée - la review existe déjà
        // Essayer de mettre à jour au lieu d'insérer
        try {
          final updateResponse = await _supabase
              .from('product_reviews')
              .update(review.toMap())
              .eq('menu_item_id', review.menuItemId)
              .eq('user_id', review.userId)
              .select()
              .single();

          final updatedReview = ProductReview.fromMap(updateResponse);
          
          // Retirer l'ancienne review et ajouter la mise à jour
          _reviews.removeWhere((r) => 
              r.menuItemId == review.menuItemId && r.userId == review.userId,);
          _reviews.insert(0, updatedReview);

          // Mettre à jour le rating
          await loadRating(review.menuItemId);

          debugPrint('✅ Review mise à jour: ${updatedReview.id}');
          return true;
        } catch (updateError) {
          _error = 'Erreur lors de la mise à jour de la review: $updateError';
          debugPrint('❌ $_error');
          return false;
        }
      } else {
        _error = 'Erreur lors de l\'ajout de la review: ${e.message}';
        debugPrint('❌ $_error');
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors de l\'ajout de la review: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marquer une review comme utile
  Future<bool> markHelpful(String reviewId) async {
    try {
      // Récupérer la review actuelle
      final currentReview = _reviews.firstWhere((r) => r.id == reviewId);

      await _supabase
          .from('product_reviews')
          .update({'helpful_count': (currentReview.isHelpful ? 1 : 0) + 1}).eq(
              'id', reviewId,);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erreur lors du marquage utile: $e');
      return false;
    }
  }

  /// Obtenir les reviews de l'utilisateur courant
  Future<List<ProductReview>> getUserReviews(String userId) async {
    try {
      final response = await _supabase
          .from('product_reviews')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => ProductReview.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors du chargement des reviews utilisateur: $e');
      return [];
    }
  }

  /// Vérifier si l'utilisateur peut reviewer un produit
  Future<bool> canReview(String userId, String menuItemId) async {
    try {
      // Vérifier si l'utilisateur a déjà commandé ce produit
      final response = await _supabase
          .from('product_reviews')
          .select('id')
          .eq('user_id', userId)
          .eq('menu_item_id', menuItemId)
          .maybeSingle();

      return response == null;
    } catch (e) {
      debugPrint('Erreur lors de la vérification: $e');
      return true;
    }
  }

  /// Vérifier si l'utilisateur a acheté un produit (pour badge "Achat vérifié")
  Future<bool> hasPurchasedProduct(String userId, String menuItemId) async {
    try {
      // Vérifier dans order_items si l'utilisateur a commandé ce produit
      // via les commandes livrées ou complétées
      // Faire deux requêtes séparées pour éviter les problèmes de syntaxe avec or() et les jointures
      final deliveredResponse = await _supabase
          .from('order_items')
          .select('id, orders!inner(user_id, status)')
          .eq('menu_item_id', menuItemId)
          .eq('orders.user_id', userId)
          .eq('orders.status', 'delivered')
          .limit(1);

      if ((deliveredResponse as List).isNotEmpty) {
        debugPrint(
            'Vérification achat: userId=$userId, menuItemId=$menuItemId, hasPurchased=true (delivered)',);
        return true;
      }

      final completedResponse = await _supabase
          .from('order_items')
          .select('id, orders!inner(user_id, status)')
          .eq('menu_item_id', menuItemId)
          .eq('orders.user_id', userId)
          .eq('orders.status', 'completed')
          .limit(1);

      final hasPurchased = (completedResponse as List).isNotEmpty;
      
      debugPrint(
          'Vérification achat: userId=$userId, menuItemId=$menuItemId, hasPurchased=$hasPurchased',);
      
      return hasPurchased;
    } catch (e) {
      debugPrint('Erreur lors de la vérification d\'achat: $e');
      // En cas d'erreur, on retourne false pour ne pas afficher le badge
      return false;
    }
  }
}
