import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin/services/notification_center_service.dart';

/// Session du back-office, contre `/api/v1/auth/*` (Phase 6).
///
/// Deux changements de fond par rapport à l'implémentation Supabase :
///
/// * **Les permissions viennent du serveur** (`User.permissions`, ADR-005) et
///   c'est lui qui les applique, à chaque appel. L'ancienne version lisait des
///   rôles dans une table et ne s'en servait que pour masquer des écrans : un
///   « Opérateur » privé du module marketing pouvait appeler l'API marketing
///   sans obstacle. Masquer un bouton n'a jamais protégé une donnée.
/// * **Le type de compte est vérifié à l'ouverture de session.** Un compte
///   client qui se connecterait ici est rejeté par `expectedUserTypeProvider`,
///   dans le package — pas par une condition d'écran.
///
/// Il n'y a **qu'une** source de session : le serveur. Le contournement de
/// développement qui vivait ici — une session fabriquée localement, installée
/// au démarrage depuis `main.dart` — a été retiré. Il ouvrait l'interface
/// entière sans jeton, si bien que chaque écran s'affichait vide sur des 401
/// que rien n'expliquait, et il masquait l'écran de connexion à ceux-là mêmes
/// qui devaient le vérifier.
class AdminAuthService extends ChangeNotifier {
  static AdminAuthService? _instance;

  /// Le conteneur Riverpod est celui créé une fois dans `main()`. Même
  /// convention que dans les deux autres apps : les appels `AdminAuthService()`
  /// sans argument retrouvent l'instance déjà construite.
  factory AdminAuthService([ProviderContainer? container]) {
    final existing = _instance;
    if (existing != null) return existing;

    if (container == null) {
      throw StateError(
        'AdminAuthService() a été appelé avant sa première construction avec un '
        'ProviderContainer (voir main.dart).',
      );
    }
    return _instance = AdminAuthService._internal(container);
  }

  AdminAuthService._internal(this._container) {
    _sessionSubscription = _container.listen<AsyncValue<eccore.User?>>(
      eccore.sessionProvider,
      (previous, next) => _onSessionChanged(next),
      fireImmediately: true,
    );
  }

  final ProviderContainer _container;
  late final ProviderSubscription<AsyncValue<eccore.User?>> _sessionSubscription;

  eccore.User? _staff;

  bool _isLoading = false;

  // Déconnexion après inactivité — réglage local, sans rapport avec la
  // validité du jeton, que le serveur tient de son côté.
  Timer? _inactivityTimer;
  DateTime? _lastActivity;
  Duration _inactivityTimeout = const Duration(minutes: 30);
  bool _autoLogoutEnabled = true;

  eccore.User? get currentAdmin => _staff;
  bool get isAuthenticated => currentAdmin != null;
  bool get isLoading => _isLoading;
  Duration get inactivityTimeout => _inactivityTimeout;
  bool get autoLogoutEnabled => _autoLogoutEnabled;

  /// Client HTTP partagé — porte le jeton et son rafraîchissement.
  eccore.ApiClient get apiClient => _container.read(eccore.apiClientProvider);

  /// Permissions accordées par le serveur — la seule source qui vaille.
  List<String> get permissions => currentAdmin?.permissions ?? const [];

  /// Libellé affiché sous le nom du compte.
  ///
  /// Le contrat ne rattache **pas** de nom de rôle à la session, et ce n'est
  /// pas un oubli : le code ne teste jamais un rôle, seulement une permission
  /// (ADR-005). Renommer « Manager » ne doit rien changer, donc ce nom n'a pas
  /// à circuler avec le jeton. Les rôles eux-mêmes se gèrent sur leur écran
  /// dédié (`/administration/roles/`).
  String get roleLabel {
    if (currentAdmin == null) return '';
    final total = permissions.length;
    return total == 0 ? 'Personnel' : 'Personnel · $total permission(s)';
  }

  void _onSessionChanged(AsyncValue<eccore.User?> next) {
    next.whenData((user) {
      _staff = user;
      if (user != null) {
        _startInactivityTimer();
      } else {
        _stopInactivityTimer();
      }
      notifyListeners();
    });
  }

  /// Restaure la session si un jeton valide est stocké.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _container.read(eccore.sessionProvider.notifier).restoreSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ouvre une session. Rend `false` si les identifiants sont refusés **ou** si
  /// le compte n'est pas un compte du personnel.
  Future<bool> loginAdmin(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _container
          .read(eccore.sessionProvider.notifier)
          .login(email: email, password: password);
      return _staff != null;
    } on eccore.WrongAccountTypeException {
      eccore.Journal.trace(
          "AdminAuthService: ce compte n'est pas un compte du personnel",
          );
      return false;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('AdminAuthService: connexion refusée — ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutAdmin() async {
    _stopInactivityTimer();
    await _container.read(eccore.sessionProvider.notifier).logout();
    _staff = null;
    // Les notifications d'un compte ne se montrent pas au suivant. Le centre
    // les relit à chaque ouverture, mais sans ce vidage la boîte afficherait
    // celles du compte précédent le temps de la requête — sur un poste de
    // back-office partagé entre deux services, ce n'est pas anodin.
    NotificationCenterService().clearSession();
    notifyListeners();
  }

  /// Le compte porte-t-il cette permission (`domaine.action`, ADR-005) ?
  ///
  /// Sert à **présenter** l'interface, pas à la protéger : le serveur refuse
  /// l'appel de toute façon. C'est la nuance qui manquait à l'ancienne version.
  bool can(String permission) => permissions.contains(permission);

  /// Dernier e-mail saisi, pour préremplir l'écran de connexion.
  Future<Map<String, dynamic>> getSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('admin_last_email') ?? '',
      'remember': prefs.getBool('admin_remember_email') ?? false,
    };
  }

  Future<void> saveEmailPreference(String email, {required bool remember}) async {
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString('admin_last_email', email);
    } else {
      await prefs.remove('admin_last_email');
    }
    await prefs.setBool('admin_remember_email', remember);
  }

  // ----------------------------------------------------- inactivité

  void setAutoLogoutEnabled(bool enabled) {
    _autoLogoutEnabled = enabled;
    if (enabled && isAuthenticated) {
      _startInactivityTimer();
    } else {
      _stopInactivityTimer();
    }
    notifyListeners();
  }

  void setInactivityTimeout(Duration timeout) {
    _inactivityTimeout = timeout;
    if (isAuthenticated) _startInactivityTimer();
    notifyListeners();
  }

  /// À appeler sur une interaction : repousse la déconnexion automatique.
  void recordActivity() {
    if (!isAuthenticated || !_autoLogoutEnabled) return;
    _lastActivity = DateTime.now();
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    if (!_autoLogoutEnabled) return;

    _lastActivity = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      eccore.Journal.trace('AdminAuthService: déconnexion automatique après inactivité');
      unawaited(logoutAdmin());
    });
  }

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivity = null;
  }

  bool isStillActive() {
    if (!isAuthenticated || !_autoLogoutEnabled) return true;
    if (_lastActivity == null) return false;
    return DateTime.now().difference(_lastActivity!) < _inactivityTimeout;
  }

  @override
  void dispose() {
    _stopInactivityTimer();
    _sessionSubscription.close();
    super.dispose();
  }
}
