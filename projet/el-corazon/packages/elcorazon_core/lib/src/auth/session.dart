import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'auth_repository.dart';
import 'token_storage.dart';

/// Stockage des jetons — un seul par app (le conteneur Riverpod en tient une
/// seule instance).
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Client HTTP — **doit être surchargé par chaque app** avec sa propre
/// `API_BASE_URL` (voir `.env`). Volontairement sans valeur par défaut : une
/// app qui oublierait la surcharge doit échouer bruyamment au démarrage,
/// pas silencieusement pointer nulle part.
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError(
    'apiClientProvider doit être surchargé (voir API_BASE_URL dans le .env de l\'app).',
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Type de compte que **cette** app accepte (`UserAccountType.customer`,
/// `.courier` ou `.staff`) — **doit être surchargé par chaque app**. Un
/// compte du mauvais type est refusé aussi bien à la connexion qu'à la
/// restauration de session (voir [SessionNotifier]).
final expectedUserTypeProvider = Provider<String>((ref) {
  throw UnimplementedError('expectedUserTypeProvider doit être surchargé par app.');
});

/// Source de vérité de la session — remplace, dans chaque app, la lecture
/// directe de `Supabase.instance.client.auth.currentUser`.
///
/// La garde de rôle vit ici et nulle part ailleurs : elle s'applique aussi
/// bien après [login] qu'après [restoreSession], parce qu'un compte dont le
/// `user_type` a changé côté serveur doit être rejeté au redémarrage tout
/// autant qu'à la connexion — un écran de connexion qui ne ferait la
/// vérification qu'une fois laisserait passer le second cas.
class SessionNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async => null;

  /// Appelé une fois au démarrage de l'app (jamais automatiquement par
  /// [build], pour ne pas mêler l'initialisation du provider et l'accès
  /// réseau qu'elle déclenche).
  Future<void> restoreSession() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null && !await tokenStorage.hasValidAccessToken()) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    try {
      final user = await repository.me();
      if (!_isAllowed(user)) {
        await repository.logout();
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(user);
    } on SessionExpiredException {
      await tokenStorage.clearTokens();
      state = const AsyncData(null);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await tokenStorage.clearTokens();
        state = const AsyncData(null);
      } else {
        // Panne passagère (réseau, 5xx) : ne pas déconnecter sur la seule foi
        // d'un appel qui a échoué pour une raison qui n'a rien à voir avec la
        // validité de la session.
        state = AsyncError(error, StackTrace.current);
      }
    }
  }

  Future<User> login({required String email, required String password}) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    try {
      final user = await repository.login(email: email, password: password);
      if (!_isAllowed(user)) {
        // Les jetons viennent d'être écrits par `repository.login` — les
        // révoquer immédiatement, pas seulement refuser l'état local, sinon
        // ils restent utilisables par ailleurs (un intercepteur qui les
        // relirait, par exemple).
        final error = WrongAccountTypeException(user.userType, ref.read(expectedUserTypeProvider));
        await repository.logout();
        state = AsyncError(error, StackTrace.current);
        throw error;
      }
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      if (state is! AsyncError) {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    try {
      // L'inscription ne crée que des comptes `customer` (imposé serveur,
      // §1 du contrat) : la garde de rôle ne s'applique qu'aux apps qui
      // acceptent ce type — dely et admin n'exposeront simplement pas
      // d'écran d'inscription.
      final user = await repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AsyncData(null);
  }

  bool _isAllowed(User user) => user.userType == ref.read(expectedUserTypeProvider);
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, User?>(SessionNotifier.new);
