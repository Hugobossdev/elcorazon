import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/call_service.dart';
import 'package:elcora_fast/services/agora_service.dart';
import 'package:elcora_fast/services/app_service.dart';

/// Écran d'appel vocal entre client et livreur
class CallScreen extends StatefulWidget {
  final String orderId;
  final String? callerName;
  final String? receiverName;
  final CallDirection direction;
  final Call? existingCall;

  const CallScreen({
    required this.orderId,
    this.callerName,
    this.receiverName,
    this.direction = CallDirection.outgoing,
    this.existingCall,
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  final AgoraService _agoraService = AgoraService();
  Call? _currentCall;
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _callDurationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    if (!mounted) return;

    final appService = Provider.of<AppService>(context, listen: false);
    final currentUser = appService.currentUser;

    if (currentUser == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (widget.existingCall != null) {
      // Appel entrant existant
      _currentCall = widget.existingCall;
      if (widget.direction == CallDirection.incoming) {
        // Attendre que l'utilisateur accepte ou rejette
        return;
      }
    } else {
      // Créer un nouvel appel sortant
      final order = await _getOrderDetails();
      if (!mounted) return;

      if (order == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final receiverId = order['delivery_person_id'] ?? order['user_id'];
      if (receiverId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun livreur assigné à cette commande'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final call = await _callService.initiateCall(
        orderId: widget.orderId,
        callerId: currentUser.id,
        receiverId: receiverId.toString(),
        callerName: currentUser.name,
        receiverName: widget.receiverName,
      );

      if (!mounted) return;

      if (call == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      _currentCall = call;
    }

    // Écouter les mises à jour de l'appel
    _callService.callStateStream.listen((call) {
      if (mounted) {
        setState(() {
          _currentCall = call;
          if (call.state == CallState.connected && _callStartTime == null) {
            _callStartTime = DateTime.now();
            _startCallTimer();
          } else if (call.state == CallState.ended ||
              call.state == CallState.rejected ||
              call.state == CallState.missed) {
            _callDurationTimer?.cancel();
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.of(context).pop();
            });
          }
        });
      }
    });

    setState(() {});
  }

  Future<Map<String, dynamic>?> _getOrderDetails() async {
    if (!mounted) return null;

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final response = await appService.databaseService.supabase
          .from('orders')
          .select('*, delivery_person_id, user_id')
          .eq('id', widget.orderId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Erreur récupération commande: $e');
      return null;
    }
  }

  void _startCallTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callStartTime != null) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime!);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptCall() async {
    if (_currentCall == null) return;

    final accepted = await _callService.acceptCall(_currentCall!);
    if (!accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'accepter l\'appel'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectCall() async {
    if (_currentCall == null) return;
    await _callService.rejectCall(_currentCall!);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    await _callService.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_currentCall == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initialisation de l\'appel...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final callState = _currentCall!.state;
    final isIncoming = widget.direction == CallDirection.incoming;
    final isConnected = callState == CallState.connected;
    final isRinging =
        callState == CallState.ringing || callState == CallState.calling;

    return PopScope(
      canPop: !isConnected,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // La navigation a eu lieu (appel pas connecté), nettoyer l'appel
          await _endCall();
        }
        // Si didPop est false, c'est qu'on a empêché la navigation (appel connecté)
        // On ne fait rien, l'appel continue
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[900],
        body: SafeArea(
          child: Column(
            children: [
              // En-tête avec bouton retour (si pas connecté)
              if (!isConnected)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

              // Contenu principal
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar/Photo
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Nom
                    Text(
                      isIncoming
                          ? (widget.callerName ?? 'Livreur')
                          : (widget.receiverName ?? 'Livreur'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Statut de l'appel
                    Text(
                      _getCallStatusText(callState, isIncoming),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),

                    // Durée de l'appel (si connecté)
                    if (isConnected) ...[
                      const SizedBox(height: 16),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],

                    const SizedBox(height: 64),

                    // Contrôles d'appel
                    if (isIncoming && isRinging) ...[
                      // Boutons pour appel entrant
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Bouton Rejeter
                          _buildCallButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            onPressed: _rejectCall,
                            size: 64,
                          ),
                          const SizedBox(width: 48),
                          // Bouton Accepter
                          _buildCallButton(
                            icon: Icons.call,
                            color: Colors.green,
                            onPressed: _acceptCall,
                            size: 64,
                          ),
                        ],
                      ),
                    ] else if (isConnected) ...[
                      // Contrôles pendant l'appel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mute
                          _buildCallButton(
                            icon: _agoraService.isMuted
                                ? Icons.mic_off
                                : Icons.mic,
                            color: _agoraService.isMuted
                                ? Colors.red
                                : Colors.white.withValues(alpha: 0.2),
                            onPressed: () async {
                              await _agoraService.toggleMute();
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 24),
                          // Speaker
                          _buildCallButton(
                            icon: _agoraService.isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                            color: _agoraService.isSpeakerOn
                                ? Colors.blue
                                : Colors.white.withValues(alpha: 0.2),
                            onPressed: () async {
                              await _agoraService.toggleSpeaker();
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 24),
                          // Raccrocher
                          _buildCallButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            onPressed: _endCall,
                            size: 64,
                          ),
                        ],
                      ),
                    ] else if (isRinging) ...[
                      // Appel sortant en cours
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 24),
                      _buildCallButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onPressed: _endCall,
                        size: 64,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  String _getCallStatusText(CallState state, bool isIncoming) {
    switch (state) {
      case CallState.calling:
        return isIncoming ? 'Appel entrant...' : 'Appel en cours...';
      case CallState.ringing:
        return isIncoming ? 'Sonnerie...' : 'En attente...';
      case CallState.connected:
        return 'En communication';
      case CallState.ended:
        return 'Appel terminé';
      case CallState.rejected:
        return 'Appel rejeté';
      case CallState.missed:
        return 'Appel manqué';
      case CallState.failed:
        return 'Échec de l\'appel';
      default:
        return '';
    }
  }
}
