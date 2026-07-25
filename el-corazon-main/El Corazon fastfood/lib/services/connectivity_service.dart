import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io' show InternetAddress, SocketException;

/// Service pour gérer la connectivité réseau
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _connectivityCheckTimer;

  bool _isOnline = true;
  bool _isInitialized = false;
  ConnectivityResult _currentConnectivityResult = ConnectivityResult.none;
  DateTime? _lastCheckedTime;

  // Stream pour les changements de connectivité
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  ConnectivityResult? get currentConnectivityResult =>
      _currentConnectivityResult;
  DateTime? get lastCheckedTime => _lastCheckedTime;

  /// Initialise le service de connectivité
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Vérifier l'état initial
      await _checkConnectivity();

      // Démarrer l'écoute des changements
      _startConnectivityListener();

      // Démarrer la vérification périodique
      _startPeriodicCheck();

      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ ConnectivityService: Service initialisé');
    } catch (e) {
      debugPrint('❌ ConnectivityService: Erreur d\'initialisation - $e');
      _isInitialized = false;
    }
  }

  /// Vérifie la connectivité actuelle
  Future<bool> checkConnectivity() async {
    return await _checkConnectivity();
  }

  /// Vérifie la connectivité avec vérification Internet réelle
  Future<bool> _checkConnectivity() async {
    try {
      // Vérifier le type de connexion
      final results = await _connectivity.checkConnectivity();

      // Prendre le premier résultat (ou none si la liste est vide)
      _currentConnectivityResult =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      // Vérifier si on a une connexion réseau
      bool hasConnection =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);

      // Si on a une connexion réseau, vérifier l'accès Internet réel
      if (hasConnection) {
        hasConnection = await _hasInternetAccess();
      }

      final wasOnline = _isOnline;
      _isOnline = hasConnection;
      _lastCheckedTime = DateTime.now();

      // Notifier si le statut a changé
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        notifyListeners();
        debugPrint(
          '🔄 ConnectivityService: Statut changé - ${_isOnline ? "En ligne" : "Hors ligne"}',
        );
      }

      return _isOnline;
    } catch (e) {
      debugPrint('❌ ConnectivityService: Erreur lors de la vérification - $e');
      // En cas d'erreur, supposer qu'on est hors ligne
      final wasOnline = _isOnline;
      _isOnline = false;
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        notifyListeners();
      }
      return false;
    }
  }

  /// Vérifie si on a réellement accès à Internet
  Future<bool> _hasInternetAccess() async {
    try {
      // Essayer de se connecter à un serveur DNS fiable (Google DNS)
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Démarre l'écoute des changements de connectivité
  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        debugPrint(
            '🔄 ConnectivityService: Changement de connectivité détecté',);
        // Vérifier la connectivité réelle
        await _checkConnectivity();
      },
      onError: (error) {
        debugPrint('❌ ConnectivityService: Erreur dans l\'écoute - $error');
      },
    );
  }

  /// Démarre la vérification périodique de la connectivité
  void _startPeriodicCheck() {
    _connectivityCheckTimer?.cancel();
    // Vérifier toutes les 30 secondes
    _connectivityCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectivity(),
    );
  }

  /// Force une vérification de la connectivité
  Future<bool> forceCheck() async {
    debugPrint('🔄 ConnectivityService: Vérification forcée');
    return await _checkConnectivity();
  }

  /// Obtient une description du type de connexion
  String getConnectionTypeDescription() {
    switch (_currentConnectivityResult) {
      case ConnectivityResult.mobile:
        return 'Données mobiles';
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Autre';
      case ConnectivityResult.none:
        return 'Aucune connexion';
    }
  }

  /// Libère les ressources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityCheckTimer?.cancel();
    _connectivityController.close();
    super.dispose();
  }
}
