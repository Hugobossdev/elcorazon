import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:elcora_fast/main.dart' show adresseWebSocket, apiClient;
import 'package:elcora_fast/services/agora_service.dart';

/// État d'un appel, côté écran.
enum CallState { idle, calling, ringing, connected, ended, rejected, missed, failed }

/// Type d'appel
enum CallType { voice, video }

/// Direction de l'appel
enum CallDirection { outgoing, incoming }

/// Appel tel que l'écran le manipule — projection de `eccore.Call`.
class Call {
  Call({
    required this.id,
    required this.orderId,
    required this.callerId,
    required this.receiverId,
    required this.direction,
    required this.createdAt,
    this.callerName,
    this.receiverName,
    this.type = CallType.voice,
    this.state = CallState.idle,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.channelId,
  });

  /// Depuis le contrat Django. [myUserId] décide de la direction : le même
  /// appel est « sortant » pour l'un et « entrant » pour l'autre, et le serveur
  /// n'a pas à trancher pour les deux.
  factory Call.fromRemote(eccore.Call call, {required String myUserId}) {
    final outgoing = call.callerId == myUserId;
    return Call(
      id: call.id,
      orderId: call.orderId,
      callerId: call.callerId,
      receiverId: call.calleeId,
      callerName: call.callerName,
      receiverName: call.calleeName,
      type: call.kind == 'video' ? CallType.video : CallType.voice,
      direction: outgoing ? CallDirection.outgoing : CallDirection.incoming,
      state: _stateFromRemote(call.status),
      createdAt: call.createdAt,
      startedAt: call.answeredAt,
      endedAt: call.endedAt,
      duration: call.durationSeconds,
      channelId: call.channelName,
    );
  }

  static CallState _stateFromRemote(String status) {
    switch (status) {
      case 'ringing':
        return CallState.ringing;
      case 'accepted':
        return CallState.connected;
      case 'declined':
        return CallState.rejected;
      case 'ended':
        return CallState.ended;
      case 'missed':
        return CallState.missed;
      default:
        return CallState.idle;
    }
  }

  final String id;
  final String orderId;
  final String callerId;
  final String receiverId;
  final String? callerName;
  final String? receiverName;
  final CallType type;
  final CallDirection direction;
  final CallState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration;

  /// Canal RTC — **dérivé par le serveur**. L'app le composait
  /// (`order_{id}_call`), ce qui laissait rejoindre la conversation de
  /// n'importe quelle commande dont on connaissait l'identifiant.
  final String? channelId;
}

/// Appels client ↔ livreur — `/api/v1/calls/` et `ws/me/` (Phase 6).
///
/// Trois choses ont changé de camp par rapport à l'implémentation Supabase, et
/// toutes les trois pour la même raison — elles ne sont pas vérifiables sur un
/// téléphone :
///
/// * **Le destinataire** vient de la course de la commande. Le client en
///   fournissait l'identifiant : n'importe quel compte pouvait faire sonner
///   n'importe quel autre.
/// * **Le canal RTC** est dérivé de l'appel par le serveur, et différent à
///   chaque nouvel appel.
/// * **Le jeton RTC** est signé côté serveur. Le certificat Agora vivait dans
///   le `.env` de l'app, donc dans un binaire distribué : l'extraire suffisait
///   à fabriquer ses propres jetons et à rejoindre n'importe quel canal.
///
/// La sonnerie arrive par `ws/me/`, la **file personnelle** du compte : un
/// appel entrant doit joindre son destinataire où qu'il soit dans l'app, ce
/// qu'un canal par commande ne permet pas.
class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final eccore.CallRepository _calls = eccore.CallRepository(apiClient: apiClient);
  final AgoraService _agoraService = AgoraService();

  Call? _currentCall;
  String? _userId;

  eccore.RealtimeChannel? _channel;
  StreamSubscription<eccore.RealtimeEvent>? _subscription;

  final StreamController<Call> _callStateController = StreamController<Call>.broadcast();
  final StreamController<Call> _incomingCallController = StreamController<Call>.broadcast();

  Stream<Call> get callStateStream => _callStateController.stream;
  Stream<Call> get incomingCallStream => _incomingCallController.stream;

  Call? get currentCall => _currentCall;
  bool get isInCall =>
      _currentCall != null &&
      (_currentCall!.state == CallState.connected ||
          _currentCall!.state == CallState.ringing ||
          _currentCall!.state == CallState.calling);

  /// Ouvre la file personnelle : c'est elle qui fait sonner le téléphone.
  Future<void> initialize({required String userId}) async {
    if (_userId == userId && _channel != null) return;

    _userId = userId;
    await _closeChannel();

    final wsUrl = adresseWebSocket(dotenv.env['API_BASE_URL'], '/ws/me/');

    final channel = eccore.RealtimeChannel(wsUrl: wsUrl, tokenStorage: eccore.TokenStorage());
    _channel = channel;
    _subscription = channel.connect().listen(_onEvent);

    eccore.Journal.trace('CallService: file personnelle ouverte');
  }

  /// Les événements ne portent que l'essentiel ; l'appel complet est relu pour
  /// que l'écran travaille sur l'état du serveur et non sur un delta.
  Future<void> _onEvent(eccore.RealtimeEvent event) async {
    if (!event.type.startsWith('call.')) return;

    final callId = event.payload['call'] as String?;
    if (callId == null || _userId == null) return;

    try {
      final remote = await _calls.history();
      final match = remote.where((call) => call.id == callId);
      if (match.isEmpty) return;

      final call = Call.fromRemote(match.first, myUserId: _userId!);
      _currentCall = call.state == CallState.connected || call.state == CallState.ringing
          ? call
          : null;

      if (event.type == 'call.incoming') {
        _incomingCallController.add(call);
      } else {
        _callStateController.add(call);
      }
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: relecture impossible — ${e.code}');
    }
  }

  /// Appelle l'autre partie de la commande. Ni destinataire ni canal ne sont
  /// déclarés : le serveur les tient.
  Future<Call?> initiateCall({
    required String orderId,
    CallType type = CallType.voice,
  }) async {
    if (_userId == null) return null;

    try {
      final remote = await _calls.place(
        orderId: orderId,
        kind: type == CallType.video ? 'video' : 'voice',
      );
      final call = Call.fromRemote(remote, myUserId: _userId!);

      if (!await _joinChannel(call)) {
        await endCall();
        return null;
      }

      _currentCall = call;
      notifyListeners();
      return call;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: appel refusé — ${e.code} (${e.detail})');
      return null;
    }
  }

  Future<bool> acceptCall(Call call) async {
    try {
      final remote = await _calls.accept(call.id);
      final accepted = Call.fromRemote(remote, myUserId: _userId ?? '');

      if (!await _joinChannel(accepted)) return false;

      _currentCall = accepted;
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: décrochage refusé — ${e.code}');
      return false;
    }
  }

  Future<void> rejectCall(Call call) async {
    try {
      await _calls.decline(call.id);
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: refus impossible — ${e.code}');
    }
    _currentCall = null;
    notifyListeners();
  }

  Future<void> endCall() async {
    final call = _currentCall;
    if (call == null) return;

    try {
      await _calls.end(call.id);
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: raccrochage impossible — ${e.code}');
    }

    await _agoraService.leaveChannel();
    _currentCall = null;
    notifyListeners();
  }

  /// Rejoint le canal avec le jeton du serveur.
  ///
  /// Le jeton est demandé **au moment de rejoindre**, pas à la création :
  /// le destinataire n'en a pas tant qu'il n'a pas décroché, et le serveur en
  /// refuse un sur un appel terminé.
  Future<bool> _joinChannel(Call call) async {
    try {
      final credentials = await _calls.rtcCredentials(call.id);
      await _agoraService.initialize();
      return _agoraService.joinChannel(
        credentials.channelName,
        uid: credentials.uid,
        token: credentials.token,
      );
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: jeton RTC refusé — ${e.code}');
      return false;
    }
  }

  /// Historique des appels d'une commande.
  Future<List<Call>> getCallHistory(String orderId) async {
    if (_userId == null) return [];

    try {
      final remote = await _calls.history();
      return remote
          .where((call) => call.orderId == orderId)
          .map((call) => Call.fromRemote(call, myUserId: _userId!))
          .toList();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: historique indisponible — ${e.code}');
      return [];
    }
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    await _channel?.close();
    _subscription = null;
    _channel = null;
  }

  @override
  void dispose() {
    _closeChannel();
    _callStateController.close();
    _incomingCallController.close();
    super.dispose();
  }
}
