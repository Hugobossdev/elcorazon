import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:elcorazon_core/src/models/user.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/api_exception.dart';
import 'package:elcorazon_core/src/auth/auth_repository.dart';
import 'package:elcorazon_core/src/auth/token_storage.dart';

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

  Future<User> login({required String email, required String password}) {
    return _openSession(
      (repository) => repository.login(email: email, password: password),
    );
  }

  /// Présente le code reçu par courriel et ouvre la session.
  ///
  /// La garde de rôle s'y applique **exactement comme à la connexion**, et
  /// pour la même raison : c'est une seconde porte vers un couple de jetons.
  /// Une garde posée sur `login` seule laisserait passer par celle-ci un
  /// compte du mauvais type — un client qui saisirait son code dans
  /// l'application livreur, par exemple.
  Future<User> verifyAccount({required String email, required String code}) {
    return _openSession(
      (repository) => repository.verifyAccount(email: email, code: code),
    );
  }

  /// Repose le mot de passe avec le code reçu, et ouvre la session.
  ///
  /// Le serveur vient de révoquer toutes les sessions ouvertes ailleurs ; les
  /// jetons rendus ici sont les seuls valides, et `AuthRepository` les a déjà
  /// écrits dans le stockage sécurisé.
  Future<User> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _openSession(
      (repository) => repository.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
  }

  /// Relit le compte depuis `/auth/me/` sans toucher aux jetons.
  ///
  /// Sert après une action qui change l'état du compte côté serveur — une
  /// vérification faite depuis un autre appareil, un compte désactivé pendant
  /// que l'application tournait. Une panne réseau n'y déconnecte personne :
  /// l'état précédent est conservé, parce qu'un appel raté ne prouve rien sur
  /// la validité de la session.
  Future<void> reload() async {
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
      await ref.read(tokenStorageProvider).clearTokens();
      state = const AsyncData(null);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await ref.read(tokenStorageProvider).clearTokens();
        state = const AsyncData(null);
      }
    }
  }

  /// Le corps commun de [login], [verifyAccount] et [resetPassword].
  ///
  /// Les trois obtiennent un couple de jetons puis appliquent la même garde de
  /// rôle. L'écrire trois fois n'aurait pas seulement été redondant : c'est la
  /// façon dont on finit par en oublier une, et une porte sans garde suffit à
  /// rendre les deux autres décoratives.
  Future<User> _openSession(Future<User> Function(AuthRepository) ouvrir) async {
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    try {
      final user = await ouvrir(repository);
      if (!_isAllowed(user)) {
        // Les jetons viennent d'être écrits — les révoquer, pas seulement
        // refuser l'état local, sinon ils restent utilisables par ailleurs.
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
      // `/auth/register/` ne crée que des comptes `customer` (imposé serveur,
      // §1 du contrat) : la garde de rôle ne s'y applique donc pas, et cette
      // méthode n'a d'usage que dans l'app cliente.
      //
      // Un livreur ne passe **pas** par ici : il dépose une candidature
      // (`DeliveryRepository.apply`, `POST /delivery/apply/`), qui ne rend
      // aucun jeton, puis ouvre sa session avec [verifyAccount]. Le compte du
      // personnel, lui, reste créé par un pair.
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
