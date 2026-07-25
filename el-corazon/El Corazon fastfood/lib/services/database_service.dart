import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/models/group_payment.dart';
import 'package:elcora_fast/models/loyalty_reward.dart';
import 'package:elcora_fast/models/loyalty_transaction.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/models/user.dart' as app_models;
import 'package:elcora_fast/supabase/supabase_config.dart';
import 'package:elcora_fast/utils/input_sanitizer.dart';
import 'package:elcora_fast/utils/security_helper.dart'
    show SecurityHelper, SecurityException;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final SupabaseClient _supabase = SupabaseConfig.client;

  // Getter public pour accéder au client Supabase
  SupabaseClient get supabase => _supabase;

  // =====================================================
  // AUTHENTICATION
  // =====================================================

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required app_models.UserRole role,
  }) async {
    try {
      // 🛡️ Sanitizer et valider les données avant insertion
      final sanitizedName = InputSanitizer.sanitize(name);
      if (sanitizedName == null) {
        throw Exception('Le nom contient des caractères non autorisés');
      }

      final sanitizedEmail = InputSanitizer.sanitize(email);
      if (sanitizedEmail == null ||
          !InputSanitizer.isValidEmailSafe(sanitizedEmail)) {
        throw Exception(
          'L\'email contient des caractères non autorisés ou est invalide',
        );
      }

      // Utiliser la méthode spécialisée pour les numéros de téléphone
      final sanitizedPhone = InputSanitizer.sanitizePhone(phone);
      if (sanitizedPhone == null) {
        throw Exception(
          'Le numéro de téléphone contient des caractères non autorisés ou est invalide',
        );
      }

      final response = await _supabase.auth.signUp(
        email: sanitizedEmail,
        password:
            password, // Le mot de passe n'est pas sanitizé (caractères spéciaux autorisés)
        data: {
          'name': sanitizedName,
          'phone': sanitizedPhone,
          'role': role.toString().split('.').last,
        },
      );

      if (response.user != null) {
        try {
          // Tentative de création immédiate du profil utilisateur avec données sanitizées
          await _supabase.from('users').insert({
            'auth_user_id': response.user!.id,
            'name': sanitizedName,
            'email': sanitizedEmail,
            'phone': sanitizedPhone,
            'role': role.toString().split('.').last,
            'loyalty_points': 0,
            'badges': [],
            'is_online': false,
            'is_active': true,
          });
        } on PostgrestException catch (e) {
          // Si la politique RLS bloque (pas encore de session), on ignore et on créera plus tard
          if (e.code == '42501') {
            debugPrint(
              'signUp: RLS a empêché la création immédiate du profil, tentative différée après authentification.',
            );
          } else if (e.code == '23505') {
            debugPrint(
              'signUp: profil déjà présent, aucune action nécessaire.',
            );
          } else {
            rethrow;
          }
        }
      }

      return response;
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription: $e');
    }
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 🛡️ Validation et sanitization de l'email avant envoi
      final trimmedEmail = email.trim().toLowerCase();
      if (trimmedEmail.isEmpty) {
        throw Exception('Veuillez entrer votre adresse email.');
      }

      // Vérifier le format email
      if (!InputSanitizer.isValidEmailSafe(trimmedEmail)) {
        throw Exception(
            'L\'adresse email est invalide ou contient des caractères non autorisés.');
      }

      // Vérifier les injections dans l'email
      final sanitizeResult = InputSanitizer.validateAndSanitize(
        trimmedEmail,
        fieldName: 'Email',
      );
      if (!sanitizeResult.isValid) {
        throw Exception(sanitizeResult.errorMessage);
      }

      // 🛡️ Validation basique du mot de passe (ne pas sanitizer, mais vérifier non vide)
      if (password.isEmpty) {
        throw Exception('Veuillez entrer votre mot de passe.');
      }
      if (password.length < 6) {
        throw Exception('Le mot de passe doit contenir au moins 6 caractères.');
      }

      final res = await _supabase.auth.signInWithPassword(
        email: sanitizeResult.sanitizedValue!,
        password: password,
      );
      // S'assurer qu'un profil public.users existe pour éviter les FK
      await ensureUserProfile();
      return res;
    } on AuthException catch (e) {
      final message = e.message.isNotEmpty
          ? e.message
          : 'Identifiants invalides, veuillez réessayer.';
      throw AuthException(message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw Exception('Erreur lors de la connexion: $e');
    }
  }

  /// Crée/met à jour le profil dans `public.users` pour l'utilisateur connecté.
  /// Indispensable si des tables (ex: `messages`) ont une FK vers `public.users`.
  Future<void> ensureUserProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

      final meta = authUser.userMetadata ?? <String, dynamic>{};
      final name =
          (meta['name'] ?? meta['full_name'] ?? 'Utilisateur').toString();
      final phone = (meta['phone'] ?? '').toString();
      final role = (meta['role'] ?? 'client').toString();

      // Dans ce projet, `auth_user_id` est unique (users_auth_user_id_key).
      // On upsert donc sur `auth_user_id` pour éviter les doublons.
      await _supabase.from('users').upsert(
        {
          'auth_user_id': authUser.id,
          'name': name,
          'email': authUser.email,
          'phone': phone,
          'role': role,
          'is_online': true,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'auth_user_id',
      );
    } catch (e) {
      debugPrint('ensureUserProfile: $e');
    }
  }

  // =====================================================
  // ADDRESSES
  // =====================================================

  Future<List<Address>> fetchUserAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((data) => Address.fromJson(Map<String, dynamic>.from(data)))
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.fetchUserAddresses: table addresses absente, retour liste vide',
        );
        return [];
      }
      throw Exception('Erreur lors du chargement des adresses: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors du chargement des adresses: $e');
    }
  }

  Future<Address> createAddress({
    required String userId,
    required String name,
    required String address,
    required String city,
    required String postalCode,
    required AddressType type,
    required bool isDefault,
    bool isFavorite = false,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // 🛡️ Sanitizer les données avant insertion
      final sanitizedData = SecurityHelper.sanitizeData({
        'user_id': userId,
        'name': name,
        'address': address,
        'city': city,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'type': type.name,
        'is_default': isDefault,
        'is_favorite': isFavorite,
      });

      final response = await _supabase
          .from('addresses')
          .insert(sanitizedData)
          .select()
          .single();

      return Address.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      if (e is SecurityException) {
        throw Exception('Erreur de sécurité: ${e.message}');
      }
      throw Exception('Erreur lors de la création de l\'adresse: $e');
    }
  }

  Future<Address> updateAddress({
    required String addressId,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    AddressType? type,
    bool? isDefault,
    bool? isFavorite,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (postalCode != null) 'postal_code': postalCode,
        if (type != null) 'type': type.name,
        if (isDefault != null) 'is_default': isDefault,
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (updates.isEmpty) {
        final current = await _supabase
            .from('addresses')
            .select()
            .eq('id', addressId)
            .maybeSingle();
        if (current == null) {
          throw Exception('Adresse introuvable');
        }
        return Address.fromJson(Map<String, dynamic>.from(current));
      }

      final response = await _supabase
          .from('addresses')
          .update(updates)
          .eq('id', addressId)
          .select()
          .single();

      return Address.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'adresse: $e');
    }
  }

  Future<void> unsetDefaultAddresses(String userId) async {
    try {
      await _supabase
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);
    } catch (e) {
      throw Exception(
        'Erreur lors de la désactivation des adresses par défaut: $e',
      );
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _supabase.from('addresses').delete().eq('id', addressId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de l\'adresse: $e');
    }
  }

  // =====================================================
  // CART
  // =====================================================

  Future<Map<String, dynamic>> fetchUserCart(String userId) async {
    try {
      final metaFuture = _supabase
          .from('user_carts')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      final itemsFuture = _supabase
          .from('user_cart_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final results = await Future.wait([metaFuture, itemsFuture]);
      final meta = results[0] as Map<String, dynamic>? ?? {};
      final rawItems = (results[1] as List<dynamic>)
          .map((data) => Map<String, dynamic>.from(data as Map))
          .toList();

      final items = rawItems.map(CartItem.fromMap).toList();

      return {
        'items': items,
        'deliveryFee': (meta['delivery_fee'] as num?)?.toDouble(),
        'discount': (meta['discount'] as num?)?.toDouble(),
        'promoCode': meta['promo_code'] as String?,
      };
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.fetchUserCart: tables user_carts/user_cart_items absentes, retour vide',
        );
        return {
          'items': <CartItem>[],
          'deliveryFee': null,
          'discount': null,
          'promoCode': null,
        };
      }
      throw Exception('Erreur lors du chargement du panier: ${e.message}');
    } catch (e) {
      throw Exception('Erreur lors du chargement du panier: $e');
    }
  }

  Future<void> upsertUserCart({
    required String userId,
    required List<CartItem> items,
    required double deliveryFee,
    required double discount,
    String? promoCode,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _supabase.from('user_carts').upsert({
        'user_id': userId,
        'delivery_fee': deliveryFee,
        'discount': discount,
        'promo_code': promoCode,
        'updated_at': now,
      });

      await _supabase.from('user_cart_items').delete().eq('user_id', userId);

      if (items.isNotEmpty) {
        final payload = items
            .map(
              (item) => {
                'user_id': userId,
                'menu_item_id': item.menuItemId,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'image_url': item.imageUrl,
                'customizations': item.customizations,
                'created_at': now,
                'updated_at': now,
              },
            )
            .toList();

        await _supabase.from('user_cart_items').insert(payload);
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.upsertUserCart: tables user_carts/user_cart_items absentes, synchronisation ignorée',
        );
        return;
      }
      debugPrint('DatabaseService.upsertUserCart error: $e');
    } catch (e) {
      debugPrint('DatabaseService.upsertUserCart error: $e');
    }
  }

  Future<void> clearUserCart(String userId) async {
    try {
      await _supabase.from('user_cart_items').delete().eq('user_id', userId);
      await _supabase.from('user_carts').delete().eq('user_id', userId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.clearUserCart: tables absentes, rien à effacer',
        );
        return;
      }
      debugPrint('DatabaseService.clearUserCart error: $e');
    } catch (e) {
      debugPrint('DatabaseService.clearUserCart error: $e');
    }
  }

  // =====================================================
  // GAMIFICATION – ACHIEVEMENTS / CHALLENGES / BADGES
  // =====================================================

  Future<List<Map<String, dynamic>>> fetchAchievementsWithProgress(
    String userId,
  ) async {
    try {
      final achievements = await _supabase
          .from('achievements')
          .select()
          .order('points_reward', ascending: true);

      List<dynamic> userProgress = [];
      try {
        userProgress = await _supabase
            .from('user_achievements')
            .select()
            .eq('user_id', userId);
      } catch (e) {
        debugPrint(
          'DatabaseService.fetchAchievementsWithProgress: user_achievements manquant',
        );
      }

      final progressById = <String, Map<String, dynamic>>{};
      for (final entry in userProgress) {
        final map = Map<String, dynamic>.from(entry as Map);
        final achievementId = map['achievement_id']?.toString();
        if (achievementId != null) {
          progressById[achievementId] = map;
        }
      }

      return achievements.map<Map<String, dynamic>>((raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        final id = data['id']?.toString() ?? '';
        final userData = progressById[id];
        return {
          'id': id,
          'title': data['title'] ?? data['name'] ?? '',
          'description': data['description'] ?? '',
          'icon': data['icon'] ?? '🏆',
          'points': data['points_reward'] ?? data['points'] ?? 0,
          'target': data['condition_value'] ??
              data['target'] ??
              data['required_value'] ??
              1,
          'criteria': data['criteria'] ?? data['type'] ?? 'orders',
          'progress': userData?['progress'] ?? 0,
          'isUnlocked': userData?['is_unlocked'] ?? false,
          'unlockedAt': userData?['unlocked_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('DatabaseService.fetchAchievementsWithProgress error: $e');
      return [];
    }
  }

  Future<void> upsertUserAchievement({
    required String userId,
    required String achievementId,
    int? progress,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'achievement_id': achievementId,
        if (progress != null) 'progress': progress,
        if (isUnlocked != null) 'is_unlocked': isUnlocked,
        if (unlockedAt != null) 'unlocked_at': unlockedAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_achievements')
          .upsert(payload, onConflict: 'user_id,achievement_id');
    } catch (e) {
      debugPrint('DatabaseService.upsertUserAchievement error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchChallengesWithProgress(
    String userId,
  ) async {
    try {
      final challenges = await _supabase
          .from('challenges')
          .select()
          .order('created_at', ascending: false);

      List<dynamic> userChallenges = [];
      try {
        userChallenges = await _supabase
            .from('user_challenges')
            .select()
            .eq('user_id', userId);
      } catch (e) {
        debugPrint(
          'DatabaseService.fetchChallengesWithProgress: user_challenges manquant',
        );
      }

      final progressById = <String, Map<String, dynamic>>{};
      for (final entry in userChallenges) {
        final map = Map<String, dynamic>.from(entry as Map);
        final challengeId = map['challenge_id']?.toString();
        if (challengeId != null) {
          progressById[challengeId] = map;
        }
      }

      return challenges.map<Map<String, dynamic>>((raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        final id = data['id']?.toString() ?? '';
        final userData = progressById[id];
        return {
          'id': id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'icon': data['icon'] ?? '🎯',
          'reward': data['reward_points'] ?? 0,
          'target': data['target_value'] ?? data['target'] ?? 1,
          'criteria': data['criteria'] ?? data['type'] ?? 'orders',
          'endDate': data['end_date'],
          'startDate': data['start_date'],
          'isActive': userData?['is_completed'] == true
              ? false
              : (data['is_active'] ?? true),
          'isCompleted': userData?['is_completed'] ?? false,
          'progress': userData?['progress'] ?? 0,
          'completedAt': userData?['completed_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('DatabaseService.fetchChallengesWithProgress error: $e');
      return [];
    }
  }

  Future<void> upsertUserChallenge({
    required String userId,
    required String challengeId,
    required int progress,
    required bool isCompleted,
    DateTime? completedAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'challenge_id': challengeId,
        'progress': progress,
        'is_completed': isCompleted,
        'completed_at': completedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_challenges')
          .upsert(payload, onConflict: 'user_id,challenge_id');
    } catch (e) {
      debugPrint('DatabaseService.upsertUserChallenge error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBadgesWithProgress(
    String userId,
  ) async {
    try {
      // Récupérer uniquement les badges actifs depuis la base de données
      final badgesResponse = await _supabase
          .from('badges')
          .select()
          .eq('is_active', true)
          .order('points_required', ascending: true);

      if (badgesResponse.isEmpty) {
        debugPrint(
          'DatabaseService.fetchBadgesWithProgress: Aucun badge actif trouvé',
        );
        return [];
      }

      // Récupérer les données de progression de l'utilisateur pour ces badges
      List<dynamic> userBadges = [];
      try {
        final badgeIds = badgesResponse
            .map((b) => (b as Map)['id']?.toString())
            .whereType<String>()
            .toList();

        if (badgeIds.isNotEmpty) {
          // Récupérer les user_badges pour tous les badges de l'utilisateur
          userBadges = await _supabase
              .from('user_badges')
              .select()
              .eq('user_id', userId);

          // Filtrer pour ne garder que ceux qui correspondent aux badges actifs
          userBadges = userBadges.where((ub) {
            final badgeId = (ub as Map)['badge_id']?.toString();
            return badgeId != null && badgeIds.contains(badgeId);
          }).toList();
        }
      } catch (e) {
        debugPrint(
          'DatabaseService.fetchBadgesWithProgress: Erreur récupération user_badges: $e',
        );
      }

      // Créer un map pour accéder rapidement aux données utilisateur par badge_id
      final userBadgeMap = <String, Map<String, dynamic>>{};
      for (final entry in userBadges) {
        final map = Map<String, dynamic>.from(entry as Map);
        final badgeId = map['badge_id']?.toString();
        if (badgeId != null) {
          userBadgeMap[badgeId] = map;
        }
      }

      // Mapper les badges avec leurs données de progression
      return badgesResponse.map<Map<String, dynamic>>((raw) {
        final data = Map<String, dynamic>.from(raw as Map);
        final id = data['id']?.toString() ?? '';
        final userBadgeData = userBadgeMap[id];

        // Convertir unlocked_at si c'est une chaîne
        DateTime? unlockedAt;
        if (userBadgeData?['unlocked_at'] != null) {
          final unlockedAtValue = userBadgeData!['unlocked_at'];
          if (unlockedAtValue is String) {
            unlockedAt = DateTime.tryParse(unlockedAtValue);
          } else if (unlockedAtValue is DateTime) {
            unlockedAt = unlockedAtValue;
          }
        }

        return {
          'id': id,
          'title': data['title']?.toString() ?? '',
          'description': data['description']?.toString() ?? '',
          'icon': data['icon']?.toString() ?? '🏅',
          'target': (data['points_required'] as num?)?.toInt() ??
              (data['target'] as num?)?.toInt() ??
              (data['condition_value'] as num?)?.toInt() ??
              0,
          'criteria': data['criteria']?.toString() ??
              data['type']?.toString() ??
              'points',
          'isUnlocked': userBadgeData?['is_unlocked'] == true,
          'unlockedAt': unlockedAt,
          'progress': (userBadgeData?['progress'] as num?)?.toInt() ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('DatabaseService.fetchBadgesWithProgress error: $e');
      rethrow; // Relancer l'erreur pour que le service puisse gérer
    }
  }

  Future<void> upsertUserBadge({
    required String userId,
    required String badgeId,
    bool? isUnlocked,
    int? progress,
    DateTime? unlockedAt,
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'badge_id': badgeId,
        if (isUnlocked != null) 'is_unlocked': isUnlocked,
        if (progress != null) 'progress': progress,
        if (unlockedAt != null) 'unlocked_at': unlockedAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('user_badges')
          .upsert(payload, onConflict: 'user_id,badge_id');
    } catch (e) {
      debugPrint('DatabaseService.upsertUserBadge error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Sign in with phone number - sends OTP
  Future<void> signInWithPhone(String phone) async {
    try {
      // 🛡️ Valider et nettoyer le numéro de téléphone
      final sanitizedPhone = InputSanitizer.sanitizePhone(phone);
      if (sanitizedPhone == null) {
        throw Exception(
          'Le numéro de téléphone est invalide. Utilisez le format international (ex: +22890123456).',
        );
      }
      await _supabase.auth.signInWithOtp(
        phone: sanitizedPhone,
      );
    } catch (e) {
      if (e is Exception && e.toString().contains('invalide')) {
        rethrow;
      }
      throw Exception('Erreur lors de l\'envoi du code OTP: $e');
    }
  }

  /// Verify OTP code for phone authentication
  Future<AuthResponse?> verifyOTP({
    required String phone,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      // Create user profile if new user
      if (response.user != null) {
        final userProfile = await getUserProfile(response.user!.id);
        if (userProfile == null) {
          // Create profile for new phone user
          await _supabase.from('users').insert({
            'auth_user_id': response.user!.id,
            'phone': phone,
            'role': app_models.UserRole.client.toString().split('.').last,
            'loyalty_points': 0,
            'badges': [],
            'is_online': false,
            'is_active': true,
          });
        }
      }

      return response;
    } catch (e) {
      throw Exception('Erreur lors de la vérification du code: $e');
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.elcorazon.fastfoodgo://callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return response;
    } catch (e) {
      throw Exception('Erreur lors de la connexion Google: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      // 🛡️ Valider l'email avant tout envoi
      final trimmedEmail = email.trim().toLowerCase();
      if (trimmedEmail.isEmpty) {
        throw Exception('Veuillez entrer votre adresse email.');
      }
      if (!InputSanitizer.isValidEmailSafe(trimmedEmail)) {
        throw Exception('L\'adresse email est invalide.');
      }
      final sanitizeResult = InputSanitizer.validateAndSanitize(
        trimmedEmail,
        fieldName: 'Email',
      );
      if (!sanitizeResult.isValid) {
        throw Exception(sanitizeResult.errorMessage);
      }

      await _supabase.auth
          .resetPasswordForEmail(sanitizeResult.sanitizedValue!);
    } catch (e) {
      throw Exception('Erreur lors de la réinitialisation: $e');
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  // =====================================================
  // USER MANAGEMENT
  // =====================================================

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Chercher d'abord par auth_user_id (le cas le plus courant)
      final byAuth = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (byAuth != null) {
        debugPrint(
          'DatabaseService.getUserProfile: Found user by auth_user_id: $userId',
        );
        return byAuth;
      }

      // Si pas trouvé par auth_user_id, chercher par id (pour compatibilité)
      // Note: Ce cas se produit quand on passe un ID de table users au lieu d'un auth_user_id
      final byId =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (byId != null) {
        debugPrint('DatabaseService.getUserProfile: Found user by id: $userId');
        debugPrint('  - This user has auth_user_id: ${byId['auth_user_id']}');
        // Si on trouve un utilisateur par id, c'est valide - on retourne le profil
        // Le warning précédent était trop strict - si on cherche par id et qu'on trouve,
        // c'est probablement ce qu'on voulait (par exemple, deliveryPersonId est un users.id)
        return byId;
      }

      return null;
    } catch (e) {
      debugPrint('DatabaseService.getUserProfile error: $e');
      throw Exception('Erreur lors de la récupération du profil: $e');
    }
  }

  Future<Map<String, dynamic>?> ensureUserProfileExists({
    String? userId,
  }) async {
    final currentAuthUser = _supabase.auth.currentUser;
    final targetId = userId ?? currentAuthUser?.id;

    if (targetId == null) {
      debugPrint(
        'DatabaseService.ensureUserProfileExists: No target ID provided',
      );
      return null;
    }

    // Vérifier d'abord si l'utilisateur existe déjà
    final existing = await getUserProfile(targetId);
    if (existing != null) {
      final userIdFromTable = existing['id'] as String?;
      final authUserIdFromTable = existing['auth_user_id'] as String?;
      debugPrint(
        'DatabaseService.ensureUserProfileExists: User already exists',
      );
      debugPrint('  - Table users.id: $userIdFromTable');
      debugPrint('  - Table users.auth_user_id: $authUserIdFromTable');
      debugPrint('  - Target auth_user_id: $targetId');

      // Vérifier que l'utilisateur trouvé correspond bien à l'auth_user_id recherché
      if (authUserIdFromTable != targetId) {
        debugPrint(
          'DatabaseService.ensureUserProfileExists: WARNING - Found user but auth_user_id does not match!',
        );
        debugPrint('  - Expected auth_user_id: $targetId');
        debugPrint('  - Found auth_user_id: $authUserIdFromTable');
        debugPrint(
          '  - This is likely a different user. Will try to create new profile.',
        );
        // Ne pas retourner cet utilisateur, continuer pour créer un nouveau profil
      } else {
        // Vérifier que l'ID de la table existe bien
        if (userIdFromTable == null) {
          debugPrint(
            'DatabaseService.ensureUserProfileExists: WARNING - users.id is null!',
          );
          return null;
        }

        return existing;
      }
    }

    // Si l'utilisateur n'existe pas, on ne peut le créer que si c'est l'utilisateur actuellement authentifié
    if (currentAuthUser == null || currentAuthUser.id != targetId) {
      debugPrint(
        'DatabaseService.ensureUserProfileExists: Cannot create profile for different user',
      );
      return null;
    }

    final metadata = currentAuthUser.userMetadata ?? {};
    final generatedEmail = 'placeholder-${currentAuthUser.id}@fastgo.local';
    final generatedPhone =
        '+000${currentAuthUser.id.replaceAll('-', '').substring(0, 10)}';

    final name =
        (metadata['name'] ?? currentAuthUser.email ?? 'Client').toString();
    final role = (metadata['role'] ?? 'client').toString();
    final email = currentAuthUser.email ?? generatedEmail;
    final phone = currentAuthUser.phone ?? generatedPhone;

    try {
      debugPrint(
        'DatabaseService.ensureUserProfileExists: Creating user profile for auth_user_id: $targetId',
      );
      final inserted = await _supabase
          .from('users')
          .insert({
            'auth_user_id': currentAuthUser.id,
            'name': name,
            'email': email,
            'phone': phone,
            'role': role,
            'loyalty_points': 0,
            'badges': [],
            'is_online': false,
            'is_active': true,
          })
          .select()
          .maybeSingle();

      if (inserted != null) {
        debugPrint(
          'DatabaseService.ensureUserProfileExists: User profile created with ID: ${inserted['id']}',
        );
        return inserted;
      }

      // Si l'insertion ne retourne rien, essayer de récupérer le profil
      final retrieved = await getUserProfile(targetId);
      if (retrieved != null) {
        debugPrint(
          'DatabaseService.ensureUserProfileExists: User profile retrieved with ID: ${retrieved['id']}',
        );
        return retrieved;
      }

      debugPrint(
        'DatabaseService.ensureUserProfileExists: Failed to create or retrieve user profile',
      );
      return null;
    } catch (e) {
      debugPrint('DatabaseService.ensureUserProfileExists error: $e');
      // En cas d'erreur (par exemple, contrainte unique), essayer de récupérer le profil
      try {
        final retrieved = await getUserProfile(targetId);
        if (retrieved != null) {
          debugPrint(
            'DatabaseService.ensureUserProfileExists: User profile found after error with ID: ${retrieved['id']}',
          );
          return retrieved;
        }
      } catch (retrieveError) {
        debugPrint(
          'DatabaseService.ensureUserProfileExists: Error retrieving profile after insert error: $retrieveError',
        );
      }
      return null;
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from('users').update(updates).eq('auth_user_id', userId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }

  // =====================================================
  // LOYALTY / REWARDS
  // =====================================================

  Future<void> updateUserLoyaltyPoints(String userId, int points) async {
    try {
      await _supabase
          .from('users')
          .update({'loyalty_points': points}).eq('auth_user_id', userId);
    } catch (e) {
      debugPrint('DatabaseService.updateUserLoyaltyPoints error: $e');
      rethrow;
    }
  }

  // =====================================================
  // GROUP PAYMENTS
  // =====================================================

  Future<GroupPaymentSession?> getGroupPaymentSessionByOrderId(
    String orderId,
  ) async {
    final raw = await _supabase
        .from('group_payments')
        .select(
          'id, group_id, order_id, total_amount, paid_amount, status, initiated_by, created_at, updated_at, participants:group_payment_participants(*)',
        )
        .eq('order_id', orderId)
        .maybeSingle();

    if (raw == null) return null;
    return _mapGroupPaymentSession(raw);
  }

  Future<GroupPaymentSession> ensureGroupPaymentSession({
    required String orderId,
    required double totalAmount,
    required List<PaymentParticipant> participants,
    String? groupId,
    String? initiatorUserId,
  }) async {
    String? initiatorDbId;
    if (initiatorUserId != null && initiatorUserId.isNotEmpty) {
      await ensureUserProfileExists(userId: initiatorUserId);
      initiatorDbId = await _resolveUserTableId(initiatorUserId);
    } else {
      final currentAuth = _supabase.auth.currentUser;
      if (currentAuth != null) {
        await ensureUserProfileExists(userId: currentAuth.id);
        initiatorDbId = await _resolveUserTableId(currentAuth.id);
      }
    }

    final existing = await getGroupPaymentSessionByOrderId(orderId);

    String groupPaymentId;
    if (existing == null) {
      final inserted = await _supabase
          .from('group_payments')
          .insert({
            'order_id': orderId,
            'group_id': groupId,
            'total_amount': totalAmount,
            'paid_amount': 0,
            'status': 'pending',
            'initiated_by': initiatorDbId,
          })
          .select('id')
          .maybeSingle();

      groupPaymentId = inserted?['id']?.toString() ?? '';

      if (groupPaymentId.isEmpty) {
        throw Exception(
          'Impossible de créer la session de paiement groupé pour la commande $orderId',
        );
      }

      if (participants.isNotEmpty) {
        await _insertGroupPaymentParticipants(
          groupPaymentId,
          participants,
        );
      }
    } else {
      groupPaymentId = existing.id;

      // Mettre à jour le montant total si nécessaire
      if ((existing.totalAmount - totalAmount).abs() > 0.01) {
        await _supabase.from('group_payments').update({
          'total_amount': totalAmount,
          'initiated_by': initiatorDbId ?? existing.initiatedBy,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', groupPaymentId);
      }

      // Insérer les nouveaux participants ou mettre à jour les montants
      if (participants.isNotEmpty) {
        await _syncGroupPaymentParticipants(
          groupPaymentId,
          existing.participants,
          participants,
        );
      }
    }

    final refreshed = await getGroupPaymentSessionByOrderId(orderId);
    if (refreshed == null) {
      throw Exception(
        'La session de paiement groupé est introuvable pour la commande $orderId',
      );
    }
    return refreshed;
  }

  Future<void> updateGroupPaymentParticipant({
    required String participantId,
    String? phone,
    String? operator,
    double? paidAmount,
    GroupPaymentParticipantStatus? status,
    String? transactionId,
    Map<String, dynamic>? paymentResult,
  }) async {
    final update = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (phone != null) update['phone'] = phone;
    if (operator != null) update['operator'] = operator;
    if (paidAmount != null) update['paid_amount'] = paidAmount;
    if (status != null) {
      update['status'] = _serializeParticipantStatus(status);
    }
    if (transactionId != null) update['transaction_id'] = transactionId;
    if (paymentResult != null) update['payment_result'] = paymentResult;

    await _supabase
        .from('group_payment_participants')
        .update(update)
        .eq('id', participantId);
  }

  Future<void> updateGroupPaymentStatus(
    String groupPaymentId, {
    GroupPaymentStatus? status,
    double? paidAmount,
  }) async {
    final update = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status != null) {
      update['status'] = _serializeGroupPaymentStatus(status);
    }
    if (paidAmount != null) {
      update['paid_amount'] = paidAmount;
    }

    if (update.length > 1) {
      await _supabase
          .from('group_payments')
          .update(update)
          .eq('id', groupPaymentId);
    }
  }

  Future<void> refreshGroupPaymentTotals(String groupPaymentId) async {
    final participants = await _supabase
        .from('group_payment_participants')
        .select('amount, paid_amount, status')
        .eq('group_payment_id', groupPaymentId);

    double paidAmount = 0;
    bool allPaid = participants.isNotEmpty;
    bool hasPayments = false;

    for (final raw in participants) {
      final status = raw['status']?.toString() ?? 'pending';
      final amount = _toDouble(raw['amount']);
      final paid = _toDouble(raw['paid_amount']);

      if (status == 'paid') {
        paidAmount += paid > 0 ? paid : amount;
        hasPayments = true;
      } else if (status == 'processing') {
        hasPayments = true;
        allPaid = false;
      } else if (status == 'pending') {
        allPaid = false;
      } else if (status == 'failed') {
        allPaid = false;
      }
    }

    final newStatus = allPaid
        ? GroupPaymentStatus.completed
        : hasPayments
            ? GroupPaymentStatus.inProgress
            : GroupPaymentStatus.pending;

    await updateGroupPaymentStatus(
      groupPaymentId,
      status: newStatus,
      paidAmount: paidAmount,
    );
  }

  GroupPaymentSession? _mapGroupPaymentSession(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return GroupPaymentSession.fromMap(_normalizeRecord(raw));
    }
    return GroupPaymentSession.fromMap(
      Map<String, dynamic>.from(raw as Map<dynamic, dynamic>),
    );
  }

  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    if (normalized['participants'] is List) {
      normalized['participants'] = (normalized['participants'] as List)
          .map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList();
    }
    return normalized;
  }

  Future<void> _insertGroupPaymentParticipants(
    String groupPaymentId,
    List<PaymentParticipant> participants,
  ) async {
    if (participants.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final participant in participants) {
      if (participant.userId.isNotEmpty) {
        await ensureUserProfileExists(userId: participant.userId);
      }
      final userDbId = await _resolveUserTableId(participant.userId);
      rows.add({
        'group_payment_id': groupPaymentId,
        'user_id': userDbId,
        'name': participant.name,
        'email': participant.email,
        'phone': participant.phoneNumber,
        'operator': participant.operator,
        'amount': participant.amount,
        'status': 'pending',
      });
    }

    await _supabase.from('group_payment_participants').insert(rows);
  }

  Future<void> _syncGroupPaymentParticipants(
    String groupPaymentId,
    List<GroupPaymentParticipant> existing,
    List<PaymentParticipant> requested,
  ) async {
    final existingMap = <String, GroupPaymentParticipant>{};
    for (final participant in existing) {
      existingMap[_participantKey(
        participant.userId,
        participant.email,
        participant.name,
      )] = participant;
    }

    final List<Map<String, dynamic>> inserts = [];
    final List<Map<String, dynamic>> updates = [];

    for (final participant in requested) {
      if (participant.userId.isNotEmpty) {
        await ensureUserProfileExists(userId: participant.userId);
      }
      final userDbId = await _resolveUserTableId(participant.userId);
      final key =
          _participantKey(userDbId, participant.email, participant.name);

      final match = existingMap[key];
      if (match == null) {
        inserts.add({
          'group_payment_id': groupPaymentId,
          'user_id': userDbId,
          'name': participant.name,
          'email': participant.email,
          'phone': participant.phoneNumber,
          'operator': participant.operator,
          'amount': participant.amount,
          'status': 'pending',
        });
      } else if ((match.amount - participant.amount).abs() > 0.01) {
        updates.add({
          'id': match.id,
          'group_payment_id': groupPaymentId,
          'user_id': userDbId ?? match.userId,
          'name': participant.name,
          'email': participant.email,
          'phone': participant.phoneNumber,
          'operator': participant.operator,
          'status': _serializeParticipantStatus(match.status),
          'amount': participant.amount,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    if (inserts.isNotEmpty) {
      await _supabase.from('group_payment_participants').insert(inserts);
    }

    if (updates.isNotEmpty) {
      await _supabase.from('group_payment_participants').upsert(updates);
    }
  }

  String _participantKey(String? userId, String? email, String name) {
    if (userId != null && userId.isNotEmpty) return 'id_$userId';
    if (email != null && email.isNotEmpty) {
      return 'email_${email.toLowerCase()}';
    }
    return 'name_${name.toLowerCase()}';
  }

  String _serializeGroupPaymentStatus(GroupPaymentStatus status) {
    switch (status) {
      case GroupPaymentStatus.completed:
        return 'completed';
      case GroupPaymentStatus.inProgress:
        return 'in_progress';
      case GroupPaymentStatus.cancelled:
        return 'cancelled';
      case GroupPaymentStatus.pending:
        return 'pending';
    }
  }

  String _serializeParticipantStatus(GroupPaymentParticipantStatus status) {
    switch (status) {
      case GroupPaymentParticipantStatus.processing:
        return 'processing';
      case GroupPaymentParticipantStatus.paid:
        return 'paid';
      case GroupPaymentParticipantStatus.failed:
        return 'failed';
      case GroupPaymentParticipantStatus.cancelled:
        return 'cancelled';
      case GroupPaymentParticipantStatus.pending:
        return 'pending';
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<String?> _resolveUserTableId(String? authUserId) async {
    if (authUserId == null || authUserId.isEmpty) return null;
    try {
      final profile = await getUserProfile(authUserId);
      return profile?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<LoyaltyReward>> fetchLoyaltyRewards({
    bool onlyActive = true,
  }) async {
    try {
      var query = _supabase.from('loyalty_rewards').select();
      if (onlyActive) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('cost', ascending: true);

      return (response as List<dynamic>)
          .map((raw) => LoyaltyReward.fromMap(raw as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.fetchLoyaltyRewards: table absente, retour d\'une liste vide.',
        );
        return [];
      }
      debugPrint('DatabaseService.fetchLoyaltyRewards error: $e');
      rethrow;
    }
  }

  Future<List<LoyaltyTransaction>> fetchLoyaltyTransactions(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('loyalty_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((raw) => LoyaltyTransaction.fromMap(raw as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.fetchLoyaltyTransactions: table absent, retour à un historique vide.',
        );
        return [];
      }
      debugPrint('DatabaseService.fetchLoyaltyTransactions error: $e');
      return [];
    }
  }

  Future<String?> createLoyaltyTransaction({
    required String userId,
    required LoyaltyTransactionType type,
    required int points,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final payload = {
        'user_id': userId,
        'transaction_type': type.name,
        'points': points,
        'description': description,
        'metadata': metadata,
      };

      final response = await _supabase
          .from('loyalty_transactions')
          .insert(payload)
          .select('id')
          .maybeSingle();

      return response?['id']?.toString();
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.createLoyaltyTransaction: table absente, transaction ignorée.',
        );
        return null;
      }
      debugPrint('DatabaseService.createLoyaltyTransaction error: $e');
      return null;
    }
  }

  Future<void> recordRewardRedemption({
    required String userId,
    required String rewardId,
    required int cost,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('reward_redemptions').insert({
        'user_id': userId,
        'reward_id': rewardId,
        'cost': cost,
        'metadata': metadata,
      });
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          'DatabaseService.recordRewardRedemption: table absente, enregistrement ignoré.',
        );
        return;
      }
      debugPrint('DatabaseService.recordRewardRedemption error: $e');
    }
  }

  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _supabase.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('auth_user_id', userId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // =====================================================
  // MENU MANAGEMENT
  // =====================================================

  /// Récupère les catégories (méthode optimisée avec sélection de champs spécifiques)
  Future<List<Map<String, dynamic>>> getMenuCategories({
    bool includeInactive = false,
  }) async {
    try {
      // Champs essentiels seulement
      const fieldsString =
          'id, name, display_name, emoji, description, sort_order, is_active';

      var queryBuilder = _supabase.from('menu_categories').select(fieldsString);

      if (!includeInactive) {
        queryBuilder = queryBuilder.eq('is_active', true);
      }

      final query = queryBuilder.order('sort_order');

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des catégories: $e');
    }
  }

  /// Récupère les menu items (méthode optimisée avec sélection de champs spécifiques)
  Future<List<Map<String, dynamic>>> getMenuItems({
    String? categoryId,
    int? limit,
    int? offset,
  }) async {
    try {
      // Champs essentiels seulement (réduit la taille de la réponse de ~40-50%)
      const fieldsString = '''
        id, name, description, price, image_url, category_id,
        is_available, is_popular, is_vegetarian, is_vegan,
        ingredients, calories, preparation_time, sort_order,
        rating, review_count, is_vip_exclusive
      ''';

      // Construire la requête avec jointure optimisée
      var queryBuilder = _supabase.from('menu_items').select('''
            $fieldsString,
            menu_categories!left(id, name, display_name, emoji)
          ''');

      // Appliquer les filtres
      queryBuilder = queryBuilder.eq('is_available', true);

      // Filtrer par catégorie si spécifié
      if (categoryId != null && categoryId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      // Appliquer l'ordre
      final orderedQuery = queryBuilder.order('sort_order');

      // Pagination si spécifiée
      dynamic finalQuery = orderedQuery;
      if (limit != null && offset != null) {
        final safeLimit = limit.clamp(1, 100);
        final safeOffset = offset.clamp(0, double.infinity).toInt();
        finalQuery = orderedQuery.range(safeOffset, safeOffset + safeLimit - 1);
      }

      final response = await finalQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error in getMenuItems: $e');
      throw Exception('Erreur lors de la récupération du menu: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomizationOptions(
    String menuItemId,
  ) async {
    try {
      final response = await _supabase
          .from('menu_item_customizations')
          .select('''
            *,
            customization_options!inner(*)
          ''')
          .eq('menu_item_id', menuItemId)
          .eq('customization_options.is_active', true)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des options: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCustomizationOptions() async {
    try {
      final response =
          await _supabase.from('menu_item_customizations').select('''
            *,
            customization_options!inner(*)
          ''').order('menu_item_id').order('sort_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors du chargement global des options: $e');
    }
  }

  // =====================================================
  // ORDER MANAGEMENT
  // =====================================================

  Future<String> createOrder(Map<String, dynamic> orderData) async {
    try {
      // 🛡️ Sanitizer les données avant insertion
      final sanitizedData = SecurityHelper.sanitizeData(
        orderData,
        excludeFields: [
          'total',
          'subtotal',
          'delivery_fee',
          'discount',
        ], // Exclure les champs numériques
      );

      final response = await _supabase
          .from('orders')
          .insert(sanitizedData)
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      if (e is SecurityException) {
        throw Exception('Erreur de sécurité: ${e.message}');
      }
      throw Exception('Erreur lors de la création de la commande: $e');
    }
  }

  Future<void> addOrderItems(
    String orderId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final itemsWithOrderId = items
          .map(
            (item) => {
              ...item,
              'order_id': orderId,
            },
          )
          .toList();

      await _supabase.from('order_items').insert(itemsWithOrderId);
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout des articles: $e');
    }
  }

  /// Récupère les commandes utilisateur (méthode optimisée avec pagination)
  Future<List<Map<String, dynamic>>> getUserOrders(
    String userId, {
    int? limit,
    int? offset,
    String? status,
  }) async {
    try {
      // Champs essentiels seulement
      const fieldsString = '''
        id, status, subtotal, delivery_fee, total, discount,
        delivery_address, payment_method, payment_status,
        order_time, created_at, updated_at, estimated_delivery_time
      ''';

      var queryBuilder = _supabase.from('orders').select('''
            $fieldsString,
            order_items(id, menu_item_id, menu_item_name, quantity, unit_price, total_price, customizations)
          ''');

      // Appliquer les filtres
      queryBuilder = queryBuilder.eq('user_id', userId);

      // Filtre par statut si spécifié
      if (status != null && status.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      // Appliquer l'ordre
      final orderedQuery = queryBuilder.order('created_at', ascending: false);

      // Pagination si spécifiée
      dynamic finalQuery = orderedQuery;
      if (limit != null && offset != null) {
        final safeLimit = limit.clamp(1, 50);
        final safeOffset = offset.clamp(0, double.infinity).toInt();
        finalQuery = orderedQuery.range(safeOffset, safeOffset + safeLimit - 1);
      }

      final response = await finalQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des commandes: $e');
    }
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? deliveryPersonId,
  }) async {
    try {
      final updates = {'status': status};
      if (deliveryPersonId != null) {
        updates['delivery_person_id'] = deliveryPersonId;
      }

      await _supabase.from('orders').update(updates).eq('id', orderId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('orders').update(updates).eq('id', orderId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la commande: $e');
    }
  }

  // =====================================================
  // DELIVERY MANAGEMENT
  // =====================================================

  Future<List<Map<String, dynamic>>> getActiveDeliveries(
    String deliveryId,
  ) async {
    try {
      final response = await _supabase
          .from('active_deliveries')
          .select('''
            *,
            orders!inner(*, order_items(*))
          ''')
          .eq('delivery_id', deliveryId)
          .inFilter(
            'status',
            ['assigned', 'accepted', 'picked_up', 'on_the_way'],
          )
          .order('assigned_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des livraisons: $e');
    }
  }

  Future<void> updateDeliveryLocation({
    required String orderId,
    required String deliveryId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    try {
      await _supabase.from('delivery_locations').insert({
        'order_id': orderId,
        'delivery_id': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la position: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeliveryLocations(
    String orderId,
  ) async {
    try {
      final response = await _supabase
          .from('delivery_locations')
          .select()
          .eq('order_id', orderId)
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des positions: $e');
    }
  }

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des notifications: $e');
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', notificationId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la notification: $e');
    }
  }

  // =====================================================
  // SOCIAL FEATURES
  // =====================================================

  Future<List<Map<String, dynamic>>> getSocialPosts({int limit = 20}) async {
    try {
      final response = await _supabase
          .from('social_posts')
          .select('''
            *,
            users!inner(name, email)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des posts: $e');
    }
  }

  Future<String> createSocialPost({
    required String userId,
    required String content,
    required String postType,
    Map<String, dynamic>? metadata,
    String? imageUrl,
  }) async {
    try {
      final response = await _supabase
          .from('social_posts')
          .insert({
            'user_id': userId,
            'content': content,
            'post_type': postType,
            'metadata': metadata,
            'image_url': imageUrl,
          })
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création du post: $e');
    }
  }

  Future<bool> likeSocialPost(String postId, String userId) async {
    try {
      await _supabase.from('social_post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      return true;
    } catch (e) {
      // Si l'utilisateur a déjà liké, on supprime le like
      try {
        await _supabase
            .from('social_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
        return false;
      } catch (e2) {
        throw Exception('Erreur lors du like: $e');
      }
    }
  }

  Future<String> commentOnSocialPost({
    required String postId,
    required String userId,
    required String content,
  }) async {
    try {
      final response = await _supabase
          .from('social_post_comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': content,
          })
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du commentaire: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSocialGroups(String userId) async {
    try {
      final response = await _supabase.from('group_members').select('''
            *,
            social_groups!inner(*)
          ''').eq('user_id', userId).eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des groupes: $e');
    }
  }

  Future<String> createSocialGroup({
    required String name,
    required String description,
    required String groupType,
    required String creatorId,
  }) async {
    try {
      final inviteCode =
          DateTime.now().millisecondsSinceEpoch.toString().substring(8);

      final response = await _supabase
          .from('social_groups')
          .insert({
            'name': name,
            'description': description,
            'group_type': groupType,
            'creator_id': creatorId,
            'invite_code': inviteCode,
            'is_private': false,
            'max_members': 50,
            'member_count': 1,
            'is_active': true,
          })
          .select('id')
          .single();

      // Add creator as member
      await _supabase.from('group_members').insert({
        'group_id': response['id'],
        'user_id': creatorId,
        'role': 'creator',
        'is_active': true,
      });

      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création du groupe: $e');
    }
  }

  Future<void> joinGroup(String groupId, String userId) async {
    try {
      await _supabase.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'is_active': true,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'adhésion au groupe: $e');
    }
  }

  // =====================================================
  // GROUP ORDERS
  // =====================================================

  Future<String> createGroupOrder({
    required String groupId,
    required String initiatorId,
    required String deliveryAddress,
    DateTime? deadline,
  }) async {
    try {
      final response = await _supabase
          .from('group_orders')
          .insert({
            'group_id': groupId,
            'initiator_id': initiatorId,
            'delivery_address': deliveryAddress,
            'deadline_at': deadline?.toIso8601String(),
            'status': 'collecting',
          })
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      throw Exception('Erreur lors de la création de la commande groupe: $e');
    }
  }

  Future<void> addToGroupOrder({
    required String groupOrderId,
    required String userId,
    required String menuItemId,
    required int quantity,
    required double unitPrice,
    Map<String, dynamic>? customizations,
    String? specialInstructions,
  }) async {
    try {
      await _supabase.from('group_order_items').insert({
        'group_order_id': groupOrderId,
        'user_id': userId,
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'customizations': customizations,
        'special_instructions': specialInstructions,
        'unit_price': unitPrice,
        'total_price': unitPrice * quantity,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout à la commande groupe: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupOrders(String groupId) async {
    try {
      final response = await _supabase.from('group_orders').select('''
            *,
            group_order_items(*, menu_items(*))
          ''').eq('group_id', groupId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des commandes groupe: $e',
      );
    }
  }

  Future<void> updateGroupOrderStatus(
    String groupOrderId,
    String status,
  ) async {
    try {
      await _supabase
          .from('group_orders')
          .update({'status': status}).eq('id', groupOrderId);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // =====================================================
  // PROMOTIONS
  // =====================================================

  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des promotions: $e');
    }
  }

  Future<Map<String, dynamic>?> validatePromoCode(String promoCode) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('promotions')
          .select()
          .eq('promo_code', promoCode)
          .eq('is_active', true)
          .gte('end_date', now)
          .lte('start_date', now)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Erreur lors de la validation du code: $e');
    }
  }

  // =====================================================
  // ANALYTICS
  // =====================================================

  Future<void> trackEvent({
    required String eventType,
    required Map<String, dynamic> eventData,
    String? userId,
    String? sessionId,
  }) async {
    try {
      await _supabase.from('analytics_events').insert({
        'user_id': userId,
        'event_type': eventType,
        'event_data': eventData,
        'session_id': sessionId,
      });
    } catch (e) {
      // Analytics errors should not break the app
      debugPrint('Erreur analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMenuStats() async {
    try {
      final response = await _supabase
          .from('menu_stats')
          .select()
          .order('total_revenue', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des statistiques: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRevenueStats() async {
    try {
      final response = await _supabase
          .from('revenue_stats')
          .select()
          .order('date', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des revenus: $e');
    }
  }

  // =====================================================
  // REALTIME SUBSCRIPTIONS
  // =====================================================

  RealtimeChannel subscribeToOrderUpdates(
    String orderId,
    Function(Map<String, dynamic>) onUpdate,
  ) {
    return _supabase
        .channel('order_updates_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToDeliveryLocations(
    String orderId,
    Function(Map<String, dynamic>) onLocationUpdate,
  ) {
    return _supabase
        .channel('delivery_locations_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) => onLocationUpdate(payload.newRecord),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToNotifications(
    String userId,
    Function(Map<String, dynamic>) onNotification,
  ) {
    return _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNotification(payload.newRecord),
        )
        .subscribe();
  }

  // Get menu item by ID
  Future<Map<String, dynamic>?> getMenuItemById(String id) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting menu item by ID: $e');
      return null;
    }
  }

  // Create menu item
  Future<void> createMenuItem(Map<String, dynamic> menuItemData) async {
    try {
      await _supabase.from('menu_items').insert(menuItemData);
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'élément de menu: $e');
    }
  }

  // Create menu category
  Future<void> createMenuCategory(Map<String, dynamic> categoryData) async {
    try {
      await _supabase.from('menu_categories').insert(categoryData);
    } catch (e) {
      throw Exception('Erreur lors de la création de la catégorie: $e');
    }
  }
}
