import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/agora_token_service.dart';

class AgoraService extends ChangeNotifier {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  String? _currentChannelId;
  int? _localUid;
  int? _remoteUid;
  final AgoraTokenService _tokenService = AgoraTokenService();

  // Streams
  final StreamController<bool> _callStateController =
      StreamController<bool>.broadcast();
  final StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();

  Stream<bool> get callStateStream => _callStateController.stream;
  Stream<int?> get remoteUidStream => _remoteUidController.stream;

  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get currentChannelId => _currentChannelId;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUid;

  /// Initialize Agora RTC Engine
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('AgoraService: Already initialized');
      return true;
    }

    try {
      // Create engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: ApiConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Set event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('AgoraService: Joined channel successfully');
            _isInCall = true;
            _localUid = connection.localUid;
            _callStateController.add(true);
            notifyListeners();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('AgoraService: Remote user joined: $remoteUid');
            _remoteUid = remoteUid;
            _remoteUidController.add(remoteUid);
            notifyListeners();
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason,) {
            debugPrint('AgoraService: Remote user offline: $remoteUid');
            _remoteUid = null;
            _remoteUidController.add(null);
            notifyListeners();
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('AgoraService: Left channel');
            _isInCall = false;
            _remoteUid = null;
            _callStateController.add(false);
            notifyListeners();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('AgoraService: Error: $err - $msg');
          },
        ),
      );

      // Enable audio
      await _engine!.enableAudio();
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      _isInitialized = true;
      debugPrint('AgoraService: Initialized successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AgoraService: Error initializing: $e');
      return false;
    }
  }

  /// Join a voice call channel
  Future<bool> joinChannel(String channelId, {int? uid}) async {
    if (!_isInitialized || _engine == null) {
      debugPrint('AgoraService: Not initialized');
      return false;
    }

    try {
      _currentChannelId = channelId;
      _localUid = uid;

      const channelMediaOptions = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      );

      final resolvedToken = await _tokenService.getRtcToken(
            channelId: channelId,
            uid: uid ?? 0,
          ) ??
          '';

      await _engine!.joinChannel(
        token: resolvedToken,
        channelId: channelId,
        uid: uid ?? 0,
        options: channelMediaOptions,
      );

      debugPrint('AgoraService: Joining channel $channelId');
      return true;
    } catch (e) {
      debugPrint('AgoraService: Error joining channel: $e');
      return false;
    }
  }

  /// Leave the current channel
  Future<void> leaveChannel() async {
    if (_engine == null || !_isInCall) return;

    try {
      await _engine!.leaveChannel();
      _currentChannelId = null;
      _localUid = null;
      _remoteUid = null;
      _isInCall = false;
      notifyListeners();
      debugPrint('AgoraService: Left channel');
    } catch (e) {
      debugPrint('AgoraService: Error leaving channel: $e');
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    if (_engine == null) return;

    try {
      _isMuted = !_isMuted;
      await _engine!.muteLocalAudioStream(_isMuted);
      notifyListeners();
      debugPrint('AgoraService: ${_isMuted ? "Muted" : "Unmuted"}');
    } catch (e) {
      debugPrint('AgoraService: Error toggling mute: $e');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;

    try {
      _isSpeakerOn = !_isSpeakerOn;
      await _engine!.setEnableSpeakerphone(_isSpeakerOn);
      notifyListeners();
      debugPrint('AgoraService: Speaker ${_isSpeakerOn ? "ON" : "OFF"}');
    } catch (e) {
      debugPrint('AgoraService: Error toggling speaker: $e');
    }
  }

  /// End call
  Future<void> endCall() async {
    await leaveChannel();
  }

  /// Dispose
  Future<void> cleanup() async {
    await leaveChannel();

    if (_engine != null) {
      await _engine!.release();
      _engine = null;
    }

    _isInitialized = false;
    unawaited(_callStateController.close());
    unawaited(_remoteUidController.close());
    notifyListeners();
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
