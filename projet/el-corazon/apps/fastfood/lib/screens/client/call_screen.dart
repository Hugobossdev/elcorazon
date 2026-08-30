import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/call_service.dart';
import 'package:elcora_fast/services/agora_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';

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
      // Nouvel appel sortant. Ni destinataire ni canal ne sont fournis : le
      // serveur déduit le premier de la course, dérive le second de l'appel.
      // Le refus (aucune livraison en cours, appel déjà ouvert) vient de lui.
      await _callService.initialize(userId: currentUser.id);
      final call = await _callService.initiateCall(orderId: widget.orderId);

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
    if (_currentCall == null) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.textLight),
              SizedBox(height: DesignConstants.spacingM),
              Text(
                'Établissement de l’appel…',
                style: TextStyle(color: AppColors.textLight),
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
    final nom = (isIncoming ? widget.callerName : widget.receiverName) ??
        'Votre livreur';

    return PopScope(
      // Un appel en cours ne se quitte pas par le bouton retour : on
      // raccroche. Sortir de l'écran laisserait la communication ouverte,
      // audible, et sans moyen d'y revenir.
      canPop: !isConnected,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) await _endCall();
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: isConnected
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textLight,
                          tooltip: 'Retour',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _avatar(nom, isRinging),
                    const SizedBox(height: DesignConstants.spacingXL),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignConstants.spacingXL,
                      ),
                      child: Text(
                        nom,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd(
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignConstants.spacingS),
                    Text(
                      _getCallStatusText(callState, isIncoming),
                      style: AppTypography.bodyLg(
                        color: AppColors.textLight.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: DesignConstants.spacingM),
                      _minuteur(),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: DesignConstants.spacingXL,
                  left: DesignConstants.edgeMargin,
                  right: DesignConstants.edgeMargin,
                ),
                child: _controles(
                  isIncoming: isIncoming,
                  isConnected: isConnected,
                  isRinging: isRinging,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// L'avatar, entouré d'un halo qui bat tant que ça sonne.
  ///
  /// Le halo n'est pas décoratif : c'est le seul signe, sur un écran par
  /// ailleurs figé, que l'appel est encore en cours d'établissement.
  Widget _avatar(String nom, bool sonne) {
    final initiale = nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textLight.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.textLight.withValues(alpha: sonne ? 0.4 : 0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initiale,
          style: AppTypography.displayLg(color: AppColors.textLight)
              .copyWith(fontSize: 56),
        ),
      ),
    );
  }

  /// La durée écoulée depuis la **connexion réelle**.
  ///
  /// La maquette démarre son minuteur à 45 secondes par un simple
  /// `setInterval` : ici il part de `_callStartTime`, posé quand l'appel passe
  /// à `connected`. Une durée d'appel est une information qu'on relit sur sa
  /// facture — elle ne s'invente pas.
  Widget _minuteur() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          size: DesignConstants.iconSizeSmall,
          color: AppColors.textLight.withValues(alpha: 0.7),
        ),
        const SizedBox(width: DesignConstants.spacingS),
        Text(
          _formatDuration(_callDuration),
          style: AppTypography.headlineSm(color: AppColors.textLight).copyWith(
            fontWeight: FontWeight.w400,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _controles({
    required bool isIncoming,
    required bool isConnected,
    required bool isRinging,
  }) {
    if (isIncoming && isRinging) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bouton(
            icone: Icons.call_end_rounded,
            libelle: 'Refuser',
            fond: AppColors.error,
            onPressed: _rejectCall,
            grand: true,
          ),
          _bouton(
            icone: Icons.call_rounded,
            libelle: 'Répondre',
            fond: AppColors.success,
            onPressed: _acceptCall,
            grand: true,
          ),
        ],
      );
    }

    if (isConnected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bouton(
            icone: _agoraService.isMuted
                ? Icons.mic_off_rounded
                : Icons.mic_rounded,
            libelle: _agoraService.isMuted ? 'Muet' : 'Micro',
            // Le rouge signale l'état **actif** de la coupure, pas une erreur :
            // c'est la convention de tous les écrans d'appel.
            fond: _agoraService.isMuted
                ? AppColors.errorLight
                : AppColors.textLight.withValues(alpha: 0.15),
            encre: _agoraService.isMuted
                ? AppColors.error
                : AppColors.textLight,
            onPressed: () async {
              await _agoraService.toggleMute();
              if (mounted) setState(() {});
            },
          ),
          _bouton(
            icone: Icons.call_end_rounded,
            libelle: 'Raccrocher',
            fond: AppColors.error,
            onPressed: _endCall,
            grand: true,
          ),
          _bouton(
            icone: _agoraService.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            libelle: 'Haut-parleur',
            fond: _agoraService.isSpeakerOn
                ? AppColors.secondaryContainer
                : AppColors.textLight.withValues(alpha: 0.15),
            encre: _agoraService.isSpeakerOn
                ? AppColors.textPrimary
                : AppColors.textLight,
            onPressed: () async {
              await _agoraService.toggleSpeaker();
              if (mounted) setState(() {});
            },
          ),
        ],
      );
    }

    if (isRinging) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          _bouton(
            icone: Icons.call_end_rounded,
            libelle: 'Annuler',
            fond: AppColors.error,
            onPressed: _endCall,
            grand: true,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// Un bouton d'appel, **avec son libellé**.
  ///
  /// La maquette les nomme tous — « Mute », « End », « Speaker ». Une rondelle
  /// d'icône seule laisse deviner ce qu'elle coupe, et on ne devine pas
  /// pendant une conversation.
  Widget _bouton({
    required IconData icone,
    required String libelle,
    required Color fond,
    required VoidCallback onPressed,
    Color encre = AppColors.textLight,
    bool grand = false,
  }) {
    final cote = grand ? 68.0 : 56.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cote,
          height: cote,
          child: Material(
            color: fond,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icone, color: encre, size: grand ? 30 : 26),
            ),
          ),
        ),
        const SizedBox(height: DesignConstants.spacingS),
        Text(
          libelle,
          style: AppTypography.labelLg(
            color: AppColors.textLight.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  String _getCallStatusText(CallState state, bool isIncoming) {
    switch (state) {
      case CallState.calling:
        return isIncoming ? 'Appel entrant…' : 'Appel en cours…';
      case CallState.ringing:
        return isIncoming ? 'Sonnerie…' : 'Ça sonne…';
      case CallState.connected:
        return 'En communication';
      case CallState.ended:
        return 'Appel terminé';
      case CallState.rejected:
        return 'Appel refusé';
      case CallState.missed:
        return 'Appel manqué';
      case CallState.failed:
        return 'L’appel n’a pas abouti';
      default:
        return '';
    }
  }
}
