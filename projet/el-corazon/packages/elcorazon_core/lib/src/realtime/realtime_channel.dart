import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:elcorazon_core/src/auth/token_storage.dart';
import 'package:elcorazon_core/src/realtime/realtime_event.dart';

/// Canal temps réel générique (`ws/orders/{id}/tracking/`, `.../chat/`, ...) —
/// voir `backend/common/consumers.py AuthorizedConsumer`. Le jeton d'accès est
/// relu à chaque [connect], jamais figé au constructeur : un rafraîchissement
/// survenu entre deux connexions ne doit pas invalider la suivante.
///
/// Une seule reconnexion automatique est tentée **par coupure** — pas de boucle
/// infinie non bornée ; si elle échoue, le flux se ferme et l'appelant doit
/// rappeler [connect] explicitement. Une connexion restée ouverte au moins
/// [stableConnection] regagne son droit à une reprise : sans cela, une livraison
/// de trente minutes perdait définitivement son canal à la **seconde** coupure
/// réseau, fût-elle séparée de la première par vingt minutes sans incident.
///
/// La reprise **rattrape** ce qui a été publié pendant la coupure : elle
/// transmet `?since=` avec le dernier numéro reçu, et le serveur rejoue la suite
/// (`AuthorizedConsumer._catch_up`, quinze minutes de journal). Sans lui, un
/// message de chat émis pendant les trois secondes de reprise était perdu —
/// la conversation n'a pas d'autre historique.
///
/// Un refus d'accès (code `4403`, `common.consumers.CLOSE_FORBIDDEN`) n'est
/// jamais retenté : retenter un accès refusé ne le rendrait pas autorisé.
class RealtimeChannel {
  RealtimeChannel({
    required this.wsUrl,
    required this.tokenStorage,
    this.reconnectDelay = const Duration(seconds: 3),
    this.stableConnection = const Duration(seconds: 30),
  });

  final String wsUrl;
  final TokenStorage tokenStorage;

  /// Attente avant la reprise automatique.
  final Duration reconnectDelay;

  /// Durée au-delà de laquelle une connexion est jugée établie : sa coupure
  /// est alors un nouvel incident, qui a droit à sa propre reprise.
  final Duration stableConnection;

  static const _closeTimeout = Duration(seconds: 2);
  static const _forbiddenCloseCode = 4403;

  WebSocketChannel? _socket;
  StreamController<RealtimeEvent>? _controller;
  StreamSubscription<dynamic>? _subscription;
  bool _closedByCaller = false;
  bool _hasRetried = false;

  /// Le numéro du dernier événement reçu depuis [connect] — ce que la reprise
  /// demande au serveur de rejouer au-delà.
  int? _lastSeq;

  /// Quand la connexion courante a été établie ; `null` tant qu'elle ne l'est
  /// pas.
  DateTime? _openedAt;

  /// La dernière fermeture était-elle un **refus d'accès** (`4403`) ?
  ///
  /// Utile à l'appelant qui supervise sa propre reprise : un refus ne se
  /// rejoue pas au même rythme qu'une coupure réseau — il ne deviendra pas
  /// autorisé en insistant, mais il peut le devenir si un rôle est corrigé
  /// côté serveur. Le distinguer permet d'espacer sans abandonner.
  ///
  /// `false` tant qu'aucune fermeture n'a eu lieu.
  bool get closeCodeWasForbidden => _socket?.closeCode == _forbiddenCloseCode;

  Stream<RealtimeEvent> connect() {
    _closedByCaller = false;
    _hasRetried = false;
    // Un nouvel abonnement repart de zéro : l'appelant n'a rien affiché, et
    // lui rejouer le journal ferait apparaître un passé qu'il n'a pas demandé.
    _lastSeq = null;
    _openedAt = null;
    // Le contrôleur est retenu dans `_controller` et fermé par [close], que
    // `onCancel` câble ici et que `_handleClosure` appelle sur une fermeture
    // définitive. Le lint ne suit pas la fermeture au travers du champ.
    // ignore: close_sinks
    final controller = StreamController<RealtimeEvent>.broadcast(onCancel: close);
    _controller = controller;
    unawaited(_open());
    return controller.stream;
  }

  Future<void> _open() async {
    final token = await tokenStorage.getAccessToken();
    final base = Uri.parse(wsUrl);
    final dernier = _lastSeq;
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        if (token != null && token.isNotEmpty) 'token': token,
        if (dernier != null) 'since': '$dernier',
      },
    );

    final socket = WebSocketChannel.connect(uri);
    _socket = socket;

    try {
      // Une poignée de main refusée ne se manifeste pas sur le flux : elle
      // rejette `ready`. Ne pas l'attendre laissait l'erreur remonter jusqu'à
      // la console du navigateur — « Uncaught (in promise)
      // WebSocketChannelException » — hors de portée de l'appelant, qui
      // n'apprenait jamais que son canal n'existait pas.
      await socket.ready;
    } catch (_) {
      _handleClosure();
      return;
    }

    _openedAt = DateTime.now();
    _subscription = socket.stream.listen(
      _onData,
      onError: (_) => _handleClosure(),
      onDone: _handleClosure,
      cancelOnError: true,
    );
  }

  void _onData(dynamic message) {
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final event = RealtimeEvent.fromJson(json);
      _lastSeq = event.seq;
      _controller?.add(event);
    } catch (_) {
      // Trame illisible — ignorée, ne rompt pas la connexion. C'est aussi le
      // sort de `realtime.gap`, qui n'a pas de numéro.
    }
  }

  void _handleClosure() {
    if (_closedByCaller) return;

    final ouverte = _openedAt;
    _openedAt = null;
    if (ouverte != null && DateTime.now().difference(ouverte) >= stableConnection) {
      // Une connexion établie qui tombe est un incident nouveau, pas l'échec
      // de la reprise précédente.
      _hasRetried = false;
    }

    final code = _socket?.closeCode;
    if (code == _forbiddenCloseCode || _hasRetried) {
      unawaited(_controller?.close());
      return;
    }

    _hasRetried = true;
    Future.delayed(reconnectDelay, () {
      if (!_closedByCaller) unawaited(_open());
    });
  }

  /// Publie un message sur le canal — seul `ws/orders/{id}/chat/` en accepte,
  /// les autres consommateurs sont à sens unique et ignorent ce qui remonte.
  ///
  /// Sans effet tant que la connexion n'est pas ouverte : la trame serait
  /// perdue de toute façon, et jeter ici obligerait chaque appelant à
  /// distinguer « pas encore connecté » de « refusé ». L'appelant qui a besoin
  /// de cette certitude attend un premier événement.
  void send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null || _closedByCaller) return;
    socket.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    _closedByCaller = true;
    await _subscription?.cancel();

    // Fermeture bornée : sur un socket dont la poignée de main a échoué, le
    // puits ne se referme jamais — il n'a jamais été ouvert. `close()` restait
    // alors suspendu pour toujours, et avec lui `RealtimeTrackingService`,
    // dont chaque `trackOrder` commence par fermer le canal précédent : un
    // seul refus interdisait toute connexion ultérieure, y compris celle qui
    // aurait été acceptée.
    await _socket?.sink
        .close()
        .timeout(_closeTimeout, onTimeout: () => null)
        .catchError((Object _) => null);
    _socket = null;

    await _controller?.close();
  }
}
