import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de stockage sécurisé des tokens d'authentification
/// Utilise FlutterSecureStorage pour un stockage sécurisé au niveau du système
class SecureTokenStorageService {
  static final SecureTokenStorageService _instance = SecureTokenStorageService._internal();
  factory SecureTokenStorageService() => _instance;
  SecureTokenStorageService._internal();

  // Utiliser FlutterSecureStorage pour le stockage sécurisé
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Clés pour les tokens
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _tokenExpiryKey = 'auth_token_expiry';
  static const String _tokenRotationKey = 'auth_token_rotation';

  // =====================================================
  // STOCKAGE DES TOKENS
  // =====================================================

  /// Sauvegarder le token d'accès de manière sécurisée
  Future<void> saveAccessToken(String token) async {
    try {
      // Vérifier si le token est valide
      if (!isValidJWT(token)) {
        throw Exception('Token invalide: format JWT incorrect');
      }

      // Sauvegarder dans le stockage sécurisé
      await _secureStorage.write(key: _accessTokenKey, value: token);

      // Sauvegarder la date d'expiration
      final expiryDate = getTokenExpiry(token);
      if (expiryDate != null) {
        await _saveTokenExpiry(expiryDate);
      }

      debugPrint('✅ Access token sauvegardé de manière sécurisée');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du token: $e');
      rethrow;
    }
  }

  /// Sauvegarder le refresh token de manière sécurisée
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
      debugPrint('✅ Refresh token sauvegardé de manière sécurisée');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du refresh token: $e');
      rethrow;
    }
  }

  /// Sauvegarder les tokens (access et refresh)
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    try {
      await saveAccessToken(accessToken);
      if (refreshToken != null) {
        await saveRefreshToken(refreshToken);
      }
      await _updateTokenRotation();
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des tokens: $e');
      rethrow;
    }
  }

  // =====================================================
  // RÉCUPÉRATION DES TOKENS
  // =====================================================

  /// Récupérer le token d'accès
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du token: $e');
      return null;
    }
  }

  /// Récupérer le refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération du refresh token: $e');
      return null;
    }
  }

  // =====================================================
  // VALIDATION DES TOKENS
  // =====================================================

  /// Vérifier si le token d'accès est valide (existe et n'est pas expiré)
  Future<bool> isAccessTokenValid() async {
    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      return isTokenValid(token);
    } catch (e) {
      debugPrint('❌ Erreur lors de la validation du token: $e');
      return false;
    }
  }

  /// Vérifier si un token JWT est valide (format et expiration)
  static bool isTokenValid(String token) {
    if (token.isEmpty) return false;

    try {
      // Vérifier le format JWT
      if (!isValidJWT(token)) {
        return false;
      }

      // Vérifier l'expiration
      if (JwtDecoder.isExpired(token)) {
        debugPrint('⚠️ Token expiré');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la validation du token: $e');
      return false;
    }
  }

  /// Vérifier si un token est un JWT valide
  static bool isValidJWT(String token) {
    try {
      JwtDecoder.decode(token);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtenir la date d'expiration d'un token
  static DateTime? getTokenExpiry(String token) {
    try {
      if (!isValidJWT(token)) return null;

      final decodedToken = JwtDecoder.decode(token);
      final exp = decodedToken['exp'];

      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'expiration: $e');
      return null;
    }
  }

  /// Obtenir le temps restant avant expiration du token
  static Duration? getTimeUntilExpiry(String token) {
    final expiry = getTokenExpiry(token);
    if (expiry == null) return null;

    final now = DateTime.now();
    if (expiry.isBefore(now)) {
      return Duration.zero;
    }

    return expiry.difference(now);
  }

  // =====================================================
  // SUPPRESSION DES TOKENS
  // =====================================================

  /// Supprimer tous les tokens
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _clearTokenExpiry();
      await _clearTokenRotation();
      debugPrint('✅ Tokens supprimés');
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression des tokens: $e');
      rethrow;
    }
  }

  /// Supprimer uniquement le token d'accès
  Future<void> clearAccessToken() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _clearTokenExpiry();
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression du token: $e');
      rethrow;
    }
  }

  /// Supprimer uniquement le refresh token
  Future<void> clearRefreshToken() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression du refresh token: $e');
      rethrow;
    }
  }

  // =====================================================
  // ROTATION DES TOKENS
  // =====================================================

  /// Vérifier si le token doit être renouvelé (rotation)
  Future<bool> shouldRotateToken() async {
    try {
      final token = await getAccessToken();
      if (token == null) return false;

      // Vérifier si le token expire bientôt (dans les 5 minutes)
      final timeUntilExpiry = getTimeUntilExpiry(token);
      if (timeUntilExpiry == null) return false;

      if (timeUntilExpiry.inMinutes < 5) {
        return true;
      }

      // Vérifier la dernière rotation
      final lastRotation = await _getTokenRotation();
      if (lastRotation == null) return false;

      // Renouveler si la dernière rotation remonte à plus de 24 heures
      final hoursSinceRotation = DateTime.now().difference(lastRotation).inHours;
      return hoursSinceRotation >= 24;
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification de la rotation: $e');
      return false;
    }
  }

  /// Mettre à jour la date de rotation du token
  Future<void> _updateTokenRotation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenRotationKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de la rotation: $e');
    }
  }

  /// Obtenir la date de dernière rotation
  Future<DateTime?> _getTokenRotation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rotationString = prefs.getString(_tokenRotationKey);
      if (rotationString == null) return null;
      return DateTime.parse(rotationString);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de la rotation: $e');
      return null;
    }
  }

  /// Supprimer la date de rotation
  Future<void> _clearTokenRotation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenRotationKey);
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression de la rotation: $e');
    }
  }

  // =====================================================
  // GESTION DE L'EXPIRATION
  // =====================================================

  /// Sauvegarder la date d'expiration du token
  Future<void> _saveTokenExpiry(DateTime expiryDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenExpiryKey, expiryDate.toIso8601String());
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde de l\'expiration: $e');
    }
  }

  /// Obtenir la date d'expiration du token
  Future<DateTime?> getTokenExpiryDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_tokenExpiryKey);
      if (expiryString == null) return null;
      return DateTime.parse(expiryString);
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'expiration: $e');
      return null;
    }
  }

  /// Supprimer la date d'expiration
  Future<void> _clearTokenExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenExpiryKey);
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression de l\'expiration: $e');
    }
  }

  // =====================================================
  // DÉCODAGE DU TOKEN
  // =====================================================

  /// Décoder le payload d'un token JWT
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      if (!isValidJWT(token)) return null;
      return JwtDecoder.decode(token);
    } catch (e) {
      debugPrint('❌ Erreur lors du décodage du token: $e');
      return null;
    }
  }

  /// Obtenir l'ID utilisateur depuis le token
  static String? getUserIdFromToken(String token) {
    try {
      final decoded = decodeToken(token);
      return decoded?['sub']?.toString() ?? decoded?['user_id']?.toString();
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'ID utilisateur: $e');
      return null;
    }
  }

  /// Obtenir l'email utilisateur depuis le token
  static String? getEmailFromToken(String token) {
    try {
      final decoded = decodeToken(token);
      return decoded?['email']?.toString();
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération de l\'email: $e');
      return null;
    }
  }

  /// Obtenir les permissions depuis le token
  static List<String>? getPermissionsFromToken(String token) {
    try {
      final decoded = decodeToken(token);
      final permissions = decoded?['permissions'];
      if (permissions is List) {
        return permissions.map((p) => p.toString()).toList();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des permissions: $e');
      return null;
    }
  }

  // =====================================================
  // MIGRATION DEPUIS SHAREDPREFERENCES
  // =====================================================

  /// Migrer les tokens depuis SharedPreferences vers FlutterSecureStorage
  Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupérer les tokens depuis SharedPreferences
      final oldAccessToken = prefs.getString('auth_access_token');
      final oldRefreshToken = prefs.getString('auth_refresh_token');

      if (oldAccessToken != null) {
        // Migrer vers le stockage sécurisé
        await saveAccessToken(oldAccessToken);
        // Supprimer l'ancien token
        await prefs.remove('auth_access_token');
      }

      if (oldRefreshToken != null) {
        // Migrer vers le stockage sécurisé
        await saveRefreshToken(oldRefreshToken);
        // Supprimer l'ancien token
        await prefs.remove('auth_refresh_token');
      }

      debugPrint('✅ Migration des tokens terminée');
    } catch (e) {
      debugPrint('❌ Erreur lors de la migration: $e');
      rethrow;
    }
  }
}

