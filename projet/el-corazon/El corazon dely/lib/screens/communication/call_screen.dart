import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../services/agora_call_service.dart';
import '../../models/order.dart';
import '../../services/app_service.dart';

/// Écran d'appel vocal/vidéo
class CallScreen extends StatefulWidget {
  final Order order;
  final CallType callType;
  final bool isIncoming;
  final String? callerName;

  const CallScreen({
    super.key,
    required this.order,
    required this.callType,
    this.isIncoming = false,
    this.callerName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraCallService _agoraService = AgoraCallService();
  StreamSubscription<CallEvent>? _callEventSubscription;
  StreamSubscription<int?>? _remoteUidSubscription;
  
  bool _isConnecting = true;
  bool _isCallActive = false;
  int? _remoteUid;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    _remoteUidSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      // Initialiser Agora si nécessaire
      if (!_agoraService.isInitialized) {
        final initialized = await _agoraService.initialize();
        if (!initialized) {
          setState(() {
            _errorMessage = 'Impossible d\'initialiser Agora';
            _isConnecting = false;
          });
          return;
        }
      }

      // Générer l'ID de canal et l'UID
      final channelId = AgoraCallService.generateChannelId(widget.order.id);
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isConnecting = false;
        });
        return;
      }

      final uid = AgoraCallService.generateUid(currentUser.id);

      // Écouter les événements d'appel
      _callEventSubscription = _agoraService.callEventStream.listen((event) {
        _handleCallEvent(event);
      });

      _remoteUidSubscription = _agoraService.remoteUidStream.listen((uid) {
        setState(() {
          _remoteUid = uid;
          if (uid != null) {
            _isCallActive = true;
            _isConnecting = false;
          }
        });
      });

      // Rejoindre le canal
      final success = await _agoraService.joinChannel(
        channelId: channelId,
        callType: widget.callType,
        uid: uid,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Impossible de rejoindre l\'appel';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isConnecting = false;
      });
    }
  }

  void _handleCallEvent(CallEvent event) {
    switch (event.type) {
      case CallEventType.joined:
        setState(() {
          _isConnecting = false;
          _isCallActive = true;
        });
        break;
      case CallEventType.userJoined:
        setState(() {
          _isCallActive = true;
          _isConnecting = false;
        });
        break;
      case CallEventType.userLeft:
        setState(() {
          _isCallActive = false;
        });
        _endCall();
        break;
      case CallEventType.left:
        Navigator.of(context).pop();
        break;
      case CallEventType.disconnected:
        setState(() {
          _errorMessage = 'Connexion perdue';
        });
        break;
      case CallEventType.error:
        setState(() {
          _errorMessage = event.message ?? 'Erreur inconnue';
          _isConnecting = false;
        });
        break;
      case CallEventType.connected:
        setState(() {
          _isCallActive = true;
        });
        break;
    }
  }

  Future<void> _endCall() async {
    await _agoraService.leaveChannel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête avec bouton retour
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _endCall,
                  ),
                  const Spacer(),
                  if (widget.callType == CallType.video)
                    IconButton(
                      icon: const Icon(Icons.switch_camera, color: Colors.white),
                      onPressed: () => _agoraService.switchCamera(),
                    ),
                ],
              ),
            ),

            // Contenu principal
            Expanded(
              child: Center(
                child: _buildCallContent(),
              ),
            ),

            // Contrôles d'appel
            if (_isCallActive || _isConnecting)
              _buildCallControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCallContent() {
    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _endCall,
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    if (_isConnecting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            widget.isIncoming ? 'Appel entrant...' : 'Connexion...',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            widget.callerName ?? 'Client',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    }

    // Vue d'appel active
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar ou vidéo
        if (widget.callType == CallType.video)
          Expanded(
            child: _buildVideoView(),
          )
        else
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[700],
            ),
            child: Center(
              child: Text(
                (widget.callerName ?? 'C').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),
        Text(
          widget.callerName ?? 'Client',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.callType == CallType.video ? 'Appel vidéo' : 'Appel vocal',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        if (_remoteUid != null) ...[
          const SizedBox(height: 8),
          Text(
            'UID: $_remoteUid',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoView() {
    return Stack(
      children: [
        // Vue distante (plein écran)
        if (_remoteUid != null && _agoraService.engine != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _agoraService.engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(
                channelId: _agoraService.currentChannelId ?? '',
                localUid: _agoraService.localUid ?? 0,
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // Vue locale (petite fenêtre en haut à droite)
        if (widget.callType == CallType.video && _agoraService.localUid != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _agoraService.engine != null
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _agoraService.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Micro
          _buildControlButton(
            icon: _agoraService.isMuted ? Icons.mic_off : Icons.mic,
            color: _agoraService.isMuted ? Colors.red : Colors.white,
            onPressed: () => _agoraService.toggleMute(),
          ),

          // Vidéo (si appel vidéo)
          if (widget.callType == CallType.video)
            _buildControlButton(
              icon: _agoraService.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              color: _agoraService.isVideoEnabled ? Colors.white : Colors.red,
              onPressed: () => _agoraService.toggleVideo(),
            ),

          // Haut-parleur
          _buildControlButton(
            icon: _agoraService.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            color: _agoraService.isSpeakerOn ? Colors.white : Colors.grey,
            onPressed: () => _agoraService.toggleSpeaker(),
          ),

          // Raccrocher
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            backgroundColor: Colors.red,
            onPressed: _endCall,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color? backgroundColor,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 64 : 56,
      height: isLarge ? 64 : 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: isLarge ? 32 : 24),
        onPressed: onPressed,
      ),
    );
  }
}

// Widget AgoraVideoView
// Note: Dans agora_rtc_engine 6.3.2+, utilisez VideoViewWidget directement
// Si VideoViewWidget n'est pas disponible, cette version utilise un placeholder
// TODO: Vérifier la documentation Agora pour la bonne utilisation de VideoViewWidget
class AgoraVideoView extends StatelessWidget {
  final VideoViewController controller;

  const AgoraVideoView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Pour agora_rtc_engine 6.3.2+, VideoViewWidget devrait être importé automatiquement
    // Si vous obtenez une erreur, vérifiez votre version d'Agora et la documentation
    // Documentation: https://docs.agora.io/en/video-calling/get-started/get-started-sdk?platform=flutter
    
    // Solution temporaire: utiliser un placeholder
    // Remplacez ceci par VideoViewWidget(controller: controller) une fois la dépendance correctement configurée
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white, size: 48),
      ),
    );
    
    // Code correct (à décommenter une fois VideoViewWidget disponible):
    // return VideoViewWidget(controller: controller);
  }
}

