import 'package:elcorazon_core/src/models/user.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/auth/token_storage.dart';

/// Accès à `/api/v1/auth/*` — un seul endroit qui connaît la forme exacte du
/// contrat (`backend/apps/accounts/urls.py`, `views.py`, `serializers.py`).
class AuthRepository {
  AuthRepository({required this.apiClient, required this.tokenStorage});

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await apiClient.post(
      '/auth/register/',
      data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return _persistAndReturnUser(response.data as Map<String, dynamic>);
  }

  Future<User> login({required String email, required String password}) async {
    final response = await apiClient.post(
      '/auth/login/',
      data: {'email': email, 'password': password},
    );
    return _persistAndReturnUser(response.data as Map<String, dynamic>);
  }

  /// Toujours silencieuse en cas d'échec réseau : rester « connecté »
  /// localement parce que l'appel serveur a échoué serait pire que
  /// simplement effacer les jetons localement. Le serveur, lui, répond
  /// toujours 204 même à un jeton déjà révoqué (idempotent par conception).
  Future<void> logout() async {
    final refresh = await tokenStorage.getRefreshToken();
    if (refresh != null) {
      try {
        await apiClient.post('/auth/logout/', data: {'refresh': refresh});
      } catch (_) {
        // Volontairement ignoré — voir le commentaire de méthode.
      }
    }
    await tokenStorage.clearTokens();
  }

  Future<User> me() async {
    final response = await apiClient.get('/auth/me/');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Révoque toutes les sessions, y compris l'appelante : le couple de
  /// jetons renvoyé ici doit immédiatement remplacer l'ancien (voir
  /// `test_revocation_des_sessions` côté serveur).
  /// Met à jour son propre nom et son téléphone (`PATCH /auth/me/`).
  ///
  /// Deux champs, et pas un de plus : ni l'e-mail — il identifie le compte —,
  /// ni le type de compte, qu'un client pourrait sinon s'écrire pour se donner
  /// des droits. Le compte modifié est celui du jeton, il ne se désigne pas.
  Future<User> updateProfile({String? fullName, String? phone}) async {
    final response = await apiClient.patch(
      '/auth/me/',
      data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.post(
      '/auth/password/change/',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    return _persistAndReturnUser(response.data as Map<String, dynamic>);
  }

  Future<void> registerDevice({required String token, required String platform}) async {
    await apiClient.post('/auth/devices/', data: {'token': token, 'platform': platform});
  }

  Future<void> unregisterDevice(String token) async {
    await apiClient.delete('/auth/devices/', data: {'token': token});
  }

  Future<User> _persistAndReturnUser(Map<String, dynamic> body) async {
    await tokenStorage.saveTokens(
      accessToken: body['access'] as String,
      refreshToken: body['refresh'] as String,
    );
    return User.fromJson(body['user'] as Map<String, dynamic>);
  }
}
