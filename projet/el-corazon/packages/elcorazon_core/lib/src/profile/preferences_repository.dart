import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/profile/customer_preferences.dart';

/// Accès à `/api/v1/profiles/preferences/` — voir
/// `backend/apps/profiles/{serializers,views}.py`.
///
/// La ressource est **singulière** : elle appartient au compte authentifié et
/// n'a pas d'identifiant dans l'URL. Le serveur la crée à la première lecture
/// (`get_or_create`), si bien qu'un compte qui n'a jamais ouvert cet écran
/// répond quand même — avec les défauts du modèle, pas avec un 404.
class PreferencesRepository {
  PreferencesRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<CustomerPreferences> read() async {
    final response = await apiClient.get('/profiles/preferences/');
    return CustomerPreferences.fromJson(response.data as Map<String, dynamic>);
  }

  /// Écrit les consentements et rend l'état **que le serveur a retenu**.
  ///
  /// Rendre la réponse plutôt que la valeur envoyée : c'est ce qui permet à
  /// l'écran d'afficher ce qui est réellement enregistré, et non ce qu'il
  /// espérait enregistrer.
  Future<CustomerPreferences> update(CustomerPreferences preferences) async {
    final response = await apiClient.patch(
      '/profiles/preferences/',
      data: preferences.toJson(),
    );
    return CustomerPreferences.fromJson(response.data as Map<String, dynamic>);
  }
}
