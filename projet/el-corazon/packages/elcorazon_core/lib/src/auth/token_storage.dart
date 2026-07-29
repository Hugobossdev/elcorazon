import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Stockage sécurisé du couple de jetons JWT — adapté de
/// `El Corazon fastfood/lib/services/secure_token_storage_service.dart`
/// (construit mais jamais branché côté Supabase ; c'est la même base ici,
/// réutilisée plutôt que réécrite, allégée du suivi de rotation par
/// `SharedPreferences` qui ne sert pas à l'intercepteur — voir
/// [ApiClient._refresh], qui décide du rafraîchissement sur le 401 reçu, pas
/// sur une heuristique de cadence).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'elcorazon_access_token';
  static const _refreshTokenKey = 'elcorazon_refresh_token';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Vrai si un jeton d'accès existe, est un JWT bien formé, et n'est pas
  /// expiré. Ne vérifie jamais la signature (RS256) — ce n'est pas le rôle du
  /// client, seul le serveur la vérifie ; ce contrôle ne sert qu'à décider
  /// s'il vaut la peine d'appeler `/auth/me/` ou de rafraîchir d'abord.
  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }
}
