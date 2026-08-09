import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:elcora_dely/config/api_config.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Service de gestion des appels vocaux/vidéo avec Agora
class AgoraCallService extends ChangeNotifier {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  RtcEngine? _engine;

  // Getter pour accéder au moteur (nécessaire pour VideoView)
  RtcEngine? get engine => _engine;

  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = false;
  bool _isFrontCamera = true;
  String? _currentChannelId;
  int? _localUid;
  int? _remoteUid;
  CallType _currentCallType = CallType.voice;

  // Identifiant d'application Agora, lu depuis `.env` au démarrage.
  //
  // Ce n'est plus une constante de compilation : la clé se configure par
  // environnement, elle ne se recompile pas.
  static String get agoraAppId => ApiConfig.agoraAppId;

  // Streams pour les événements d'appel
  final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();
  final StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();
  final StreamController<bool> _callStateController =
      StreamController<bool>.broadcast();

  Stream<CallEvent> get callEventStream => _callEventController.stream;
  Stream<int?> get remoteUidStream => _remoteUidController.stream;
  Stream<bool> get callStateStream => _callStateController.stream;

  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  String? get currentChannelId => _currentChannelId;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUid;
  CallType get currentCallType => _currentCallType;

  /// S'assure que le service est initialisé
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Initialise le moteur Agora RTC
  Future<bool> initialize() async {
    if (_isInitialized) {
      Journal.trace('✅ AgoraCallService: Déjà initialisé');
      return true;
    }

    try {
      // Créer le moteur
      _engine = createAgoraRtcEngine();

      await _engine!.initialize(
        RtcEngineContext(
          appId: agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Configurer les handlers d'événements
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            Journal.trace(
              '✅ AgoraCallService: Canal rejoint avec succès - UID: ${connection.localUid}',
            );
            _isInCall = true;
            _localUid = connection.localUid;
            _callStateController.add(true);
            _callEventController.add(CallEvent.joined());
            notifyListeners();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            Journal.trace(
              '✅ AgoraCallService: Utilisateur distant rejoint - UID: $remoteUid',
            );
            _remoteUid = remoteUid;
            _remoteUidController.add(remoteUid);
            _callEventController.add(CallEvent.userJoined());
            notifyListeners();
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                Journal.trace(
                  '⚠️ AgoraCallService: Utilisateur distant déconnecté - UID: $remoteUid, Raison: $reason',
                );
                _remoteUid = null;
                _remoteUidController.add(null);
                _callEventController.add(CallEvent.userLeft());
                notifyListeners();
              },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            Journal.trace('✅ AgoraCallService: Canal quitté');
            _isInCall = false;
            _remoteUid = null;
            _currentChannelId = null;
            _callStateController.add(false);
            _callEventController.add(CallEvent.left());
            notifyListeners();
          },
          onError: (ErrorCodeType err, String msg) {
            Journal.trace(
              '❌ AgoraCallService: Erreur - Code: $err, Message: $msg',
            );
            _callEventController.add(CallEvent.error(msg));
            notifyListeners();
          },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                Journal.trace(
                  '🔄 AgoraCallService: État de connexion changé - État: $state, Raison: $reason',
                );
                if (state == ConnectionStateType.connectionStateDisconnected) {
                  _callEventController.add(CallEvent.disconnected());
                } else if (state ==
                    ConnectionStateType.connectionStateConnected) {
                  _callEventController.add(CallEvent.connected());
                }
                notifyListeners();
              },
        ),
      );

      // Activer l'audio par défaut
      await _engine!.enableAudio();
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      _isInitialized = true;
      Journal.trace('✅ AgoraCallService: Initialisé avec succès');
      notifyListeners();
      return true;
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur d\'initialisation - $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Demande les permissions nécessaires
  Future<bool> requestPermissions({bool includeVideo = false}) async {
    try {
      // Permission microphone (toujours nécessaire)
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        Journal.trace('❌ AgoraCallService: Permission microphone refusée');
        return false;
      }

      // Permission caméra (si appel vidéo)
      if (includeVideo) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          Journal.trace('❌ AgoraCallService: Permission caméra refusée');
          return false;
        }
      }

      Journal.trace('✅ AgoraCallService: Permissions accordées');
      return true;
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur demande permissions - $e');
      return false;
    }
  }

  /// Rejoint un canal d'appel
  Future<bool> joinChannel({
    required String channelId,
    required CallType callType,
    int? uid,
    String? token, // Token Agora (optionnel pour les tests)
  }) async {
    await _ensureInitialized();

    if (!_isInitialized || _engine == null) {
      Journal.trace('❌ AgoraCallService: Non initialisé');
      return false;
    }

    try {
      // Demander les permissions
      final hasPermissions = await requestPermissions(
        includeVideo: callType == CallType.video,
      );
      if (!hasPermissions) {
        _callEventController.add(CallEvent.error('Permissions refusées'));
        return false;
      }

      _currentChannelId = channelId;
      _currentCallType = callType;
      _localUid = uid;

      // Configurer selon le type d'appel
      if (callType == CallType.video) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
        _isVideoEnabled = true;
      } else {
        await _engine!.disableVideo();
        _isVideoEnabled = false;
      }

      // Options du canal
      const channelMediaOptions = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      );

      // Rejoindre le canal
      await _engine!.joinChannel(
        token:
            token ??
            '', // Utiliser un token vide pour les tests, ou obtenir depuis votre serveur
        channelId: channelId,
        uid: uid ?? 0,
        options: channelMediaOptions,
      );

      Journal.trace(
        '✅ AgoraCallService: Tentative de rejoindre le canal $channelId',
      );
      return true;
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur rejoindre canal - $e');
      _callEventController.add(CallEvent.error(e.toString()));
      return false;
    }
  }

  /// Quitte le canal actuel
  Future<void> leaveChannel() async {
    if (_engine == null || !_isInCall) return;

    try {
      await _engine!.leaveChannel();
      _isInCall = false;
      _currentChannelId = null;
      _localUid = null;
      _remoteUid = null;
      _isVideoEnabled = false;
      notifyListeners();
      Journal.trace('✅ AgoraCallService: Canal quitté');
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur quitter canal - $e');
    }
  }

  /// Active/désactive le micro
  Future<void> toggleMute() async {
    if (_engine == null) return;

    try {
      _isMuted = !_isMuted;
      await _engine!.muteLocalAudioStream(_isMuted);
      notifyListeners();
      Journal.trace(
        '✅ AgoraCallService: ${_isMuted ? "Micro coupé" : "Micro activé"}',
      );
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur toggle mute - $e');
    }
  }

  /// Active/désactive le haut-parleur
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;

    try {
      _isSpeakerOn = !_isSpeakerOn;
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
      notifyListeners();
      Journal.trace(
        '✅ AgoraCallService: ${_isSpeakerOn ? "Haut-parleur activé" : "Haut-parleur désactivé"}',
      );
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur toggle speaker - $e');
    }
  }

  /// Active/désactive la vidéo
  Future<void> toggleVideo() async {
    if (_engine == null || _currentCallType != CallType.video) return;

    try {
      _isVideoEnabled = !_isVideoEnabled;
      await _engine!.enableLocalVideo(_isVideoEnabled);
      await _engine!.muteLocalVideoStream(!_isVideoEnabled);
      notifyListeners();
      Journal.trace(
        '✅ AgoraCallService: ${_isVideoEnabled ? "Vidéo activée" : "Vidéo désactivée"}',
      );
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur toggle video - $e');
    }
  }

  /// Change de caméra (avant/arrière)
  Future<void> switchCamera() async {
    if (_engine == null || !_isVideoEnabled) return;

    try {
      await _engine!.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
      Journal.trace(
        '✅ AgoraCallService: Caméra changée - ${_isFrontCamera ? "Avant" : "Arrière"}',
      );
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur switch camera - $e');
    }
  }

  /// Génère un ID de canal unique basé sur l'ID de commande
  static String generateChannelId(String orderId) {
    // Utiliser l'ID de commande comme base pour le canal
    // Format: order_{orderId}
    return 'order_$orderId';
  }

  /// Génère un UID unique pour l'utilisateur
  static int generateUid(String userId) {
    // Convertir l'ID utilisateur en un entier (hash simple)
    return userId.hashCode.abs() % 2147483647; // Max UID Agora
  }

  /// Nettoie les ressources
  Future<void> cleanup() async {
    try {
      await leaveChannel();

      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }

      unawaited(_callEventController.close());
      unawaited(_remoteUidController.close());
      unawaited(_callStateController.close());

      _isInitialized = false;
      _isInCall = false;
      _currentChannelId = null;
      _localUid = null;
      _remoteUid = null;

      Journal.trace('✅ AgoraCallService: Ressources nettoyées');
    } catch (e) {
      Journal.trace('❌ AgoraCallService: Erreur nettoyage - $e');
    }
  }
}

/// Type d'appel
enum CallType { voice, video }

/// Événements d'appel
class CallEvent {
  final CallEventType type;
  final String? message;

  CallEvent(this.type, [this.message]);

  factory CallEvent.joined() => CallEvent(CallEventType.joined);
  factory CallEvent.left() => CallEvent(CallEventType.left);
  factory CallEvent.userJoined() => CallEvent(CallEventType.userJoined);
  factory CallEvent.userLeft() => CallEvent(CallEventType.userLeft);
  factory CallEvent.connected() => CallEvent(CallEventType.connected);
  factory CallEvent.disconnected() => CallEvent(CallEventType.disconnected);
  factory CallEvent.error(String message) =>
      CallEvent(CallEventType.error, message);
}

enum CallEventType {
  joined,
  left,
  userJoined,
  userLeft,
  connected,
  disconnected,
  error,
}
