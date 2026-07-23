import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/services/api/api_client.dart';

/// Authentification via l'API Laravel (Sanctum).
///
/// Gère l'inscription, la connexion, la déconnexion et la récupération du
/// profil. Le jeton renvoyé est stocké par [ApiClient] et rattaché
/// automatiquement aux requêtes suivantes.
class AuthApi {
  AuthApi._internal();
  static final AuthApi _instance = AuthApi._internal();
  factory AuthApi() => _instance;

  final ApiClient _client = ApiClient();

  Future<bool> get isAuthenticated => _client.hasToken;

  /// Inscription (client ou livreur). Retourne l'utilisateur créé.
  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? role,
  }) async {
    final response = await _client.post('/auth/register', body: {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': password,
      if (role != null) 'role': role,
    });

    await _storeToken(response);
    return User.fromMap(response['data'] as Map<String, dynamic>);
  }

  /// Connexion. Retourne l'utilisateur authentifié.
  Future<User> login({
    required String email,
    required String password,
    String? deviceName,
  }) async {
    final response = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
      if (deviceName != null) 'device_name': deviceName,
    });

    await _storeToken(response);
    return User.fromMap(response['data'] as Map<String, dynamic>);
  }

  /// Pont de migration : échange un jeton Supabase contre un jeton Sanctum et
  /// le stocke. À appeler après une connexion Supabase réussie, tant que le
  /// frontend n'est pas entièrement migré. Best-effort : ne lève pas si l'API
  /// est indisponible (les lectures Supabase directes continuent de fonctionner).
  Future<bool> exchangeSupabaseToken(String supabaseAccessToken) async {
    try {
      final response = await _client.post(
        '/auth/exchange',
        bearerOverride: supabaseAccessToken,
      );
      await _storeToken(response);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Profil de l'utilisateur courant.
  Future<User> me() async {
    final response = await _client.get('/me');
    return User.fromMap(response['data'] as Map<String, dynamic>);
  }

  /// Déconnexion (révoque le jeton côté serveur puis local).
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } finally {
      await _client.clearToken();
    }
  }

  /// Change le mot de passe (vérifie l'actuel côté serveur).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post('/auth/change-password', body: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    });
  }

  Future<void> _storeToken(dynamic response) async {
    final token = (response is Map) ? response['token'] as String? : null;
    if (token != null && token.isNotEmpty) {
      await _client.setToken(token);
    }
  }
}
