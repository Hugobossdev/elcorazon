import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/services/agora_call_service.dart';
import 'package:elcora_dely/services/call_service.dart';

/// Écran d'appel — le média, une fois que la signalisation a tranché.
///
/// ## Ce que cet écran ne fait plus
///
/// Il composait le canal et le `uid`, rejoignait Agora avec un jeton vide, et
/// n'informait le serveur de rien. Il ne fabrique désormais **aucune** de ces
/// valeurs : [CallService] passe l'appel ou le décroche, obtient le canal, le
/// `uid` et le jeton du serveur, et cet écran ne fait qu'afficher ce qui se
/// passe et offrir les gestes.
///
/// ## Deux entrées, un seul écran
///
/// * **sortant** — [appelEntrant] nul : l'appel est placé au montage
///   (`POST /calls/orders/{id}/`), et le client voit sa sonnerie arriver ;
/// * **entrant** — [appelEntrant] renseigné et déjà décroché par le
///   gestionnaire d'appels entrants, qui a demandé le jeton dans la foulée.
///
/// Le raccrochage passe toujours par le service, jamais par un simple
/// `leaveChannel` : quitter le canal sans le dire au serveur laisserait l'appel
/// « en cours » côté client, et bloquerait le rappel suivant sur la même
/// commande (un seul appel actif par commande).
class CallScreen extends StatefulWidget {
  const CallScreen({
    required this.orderId,
    super.key,
    this.appelEntrant,
    this.video = false,
    this.nomInterlocuteur,
  });

  /// Commande sur laquelle porte l'appel — c'est elle qui désigne l'autre
  /// partie, côté serveur.
  final String orderId;

  /// L'appel déjà décroché, quand on arrive par une sonnerie. Nul pour un
  /// appel sortant, qui reste à placer.
  final eccore.Call? appelEntrant;

  final bool video;

  /// Nom affiché en attendant que le serveur rende l'appel complet.
  final String? nomInterlocuteur;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraCallService _media = AgoraCallService();

  late final CallService _appels = context.read<CallService>();
  StreamSubscription<CallEvent>? _evenementsMedia;
  StreamSubscription<eccore.Call>? _changementsDEtat;
  Timer? _horloge;

  eccore.Call? _appel;
  bool _enCoursDOuverture = true;
  bool _distantPresent = false;
  String? _erreur;
  Duration _duree = Duration.zero;

  @override
  void initState() {
    super.initState();
    _appel = widget.appelEntrant;
    _ecouter();
    unawaited(_demarrer());
  }

  @override
  void dispose() {
    _evenementsMedia?.cancel();
    _changementsDEtat?.cancel();
    _horloge?.cancel();
    super.dispose();
  }

  void _ecouter() {
    _evenementsMedia = _media.callEventStream.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case CallEventType.userJoined:
          // L'autre partie est **dans le canal** : c'est le seul moment où la
          // conversation existe vraiment. Le compteur part d'ici, et non du
          // décrochage — le serveur, lui, tient sa propre durée.
          setState(() {
            _distantPresent = true;
            _enCoursDOuverture = false;
          });
          _demarrerLHorloge();
        case CallEventType.userLeft:
          setState(() => _distantPresent = false);
          unawaited(_raccrocher());
        case CallEventType.joined:
          setState(() => _enCoursDOuverture = false);
        case CallEventType.error:
          setState(() => _erreur = event.message ?? 'Erreur du canal audio.');
        case CallEventType.disconnected:
          setState(() => _erreur = 'Connexion perdue. Reconnexion…');
        case CallEventType.connected:
          setState(() => _erreur = null);
        case CallEventType.left:
          break;
      }
    });

    // L'autre partie a refusé ou raccroché : le serveur l'annonce sur la file
    // personnelle, et c'est le seul moyen de l'apprendre — le canal RTC ne
    // distingue pas « a refusé » de « n'a jamais rejoint ».
    _changementsDEtat = _appels.changementsDEtat.listen((appel) {
      if (!mounted || appel.id != _appel?.id) return;
      if (!appel.isActive) {
        _fermer(_libelleDeFin(appel.status));
      } else {
        setState(() => _appel = appel);
      }
    });
  }

  Future<void> _demarrer() async {
    if (widget.appelEntrant != null) {
      // Déjà décroché et déjà dans le canal : le gestionnaire d'appels
      // entrants s'en est chargé avant d'ouvrir cet écran.
      setState(() => _enCoursDOuverture = false);
      return;
    }

    try {
      final appel = await _appels.appeler(orderId: widget.orderId, video: widget.video);
      if (!mounted) return;
      setState(() {
        _appel = appel;
        _enCoursDOuverture = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      // Le `detail` du serveur est la phrase à lire : « Aucune livraison en
      // cours sur cette commande », « Un appel est déjà en cours ».
      setState(() {
        _erreur = messageErreur(erreur);
        _enCoursDOuverture = false;
      });
    }
  }

  void _demarrerLHorloge() {
    _horloge?.cancel();
    _horloge = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _duree += const Duration(seconds: 1));
    });
  }

  String _libelleDeFin(String statut) => switch (statut) {
    'declined' => 'Appel refusé',
    'missed' => 'Pas de réponse',
    _ => 'Appel terminé',
  };

  Future<void> _raccrocher() async {
    await _appels.raccrocher();
    if (mounted) _fermer(null);
  }

  void _fermer(String? message) {
    _horloge?.cancel();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    Navigator.of(context).maybePop();
  }

  String get _nom {
    final appel = _appel;
    if (appel == null) return widget.nomInterlocuteur ?? 'Client';
    final nom = _appels.jeSuisLAppelant ? appel.calleeName : appel.callerName;
    return nom.isEmpty ? (widget.nomInterlocuteur ?? 'Client') : nom;
  }

  String get _etatLisible {
    if (_erreur != null) return 'Échec';
    if (_distantPresent) return _dureeLisible;
    if (_enCoursDOuverture) return 'Connexion…';
    return widget.appelEntrant != null ? 'En communication' : 'Sonne…';
  }

  String get _dureeLisible {
    final minutes = _duree.inMinutes.toString().padLeft(2, '0');
    final secondes = (_duree.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secondes';
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<AgoraCallService>();
    final estVideo = widget.video && media.isVideoEnabled;

    return PopScope(
      // Le bouton retour du système ne doit pas laisser un appel ouvert
      // derrière lui : le canal resterait joint, micro compris.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_raccrocher());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: estVideo && _distantPresent
                    ? _vueVideo(media)
                    : _vueAudio(),
              ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    _erreur!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              _controles(media),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vueAudio() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white24,
          child: Text(
            _nom.isEmpty ? '?' : _nom.characters.first.toUpperCase(),
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _nom,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(_etatLisible, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    );
  }

  Widget _vueVideo(AgoraCallService media) {
    final engine = media.engine;
    final distant = media.remoteUid;
    if (engine == null || distant == null) return _vueAudio();

    return Stack(
      children: [
        Positioned.fill(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: distant),
              connection: RtcConnection(channelId: media.currentChannelId),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          width: 110,
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controles(AgoraCallService media) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _bouton(
          icone: media.isMuted ? Icons.mic_off : Icons.mic,
          libelle: media.isMuted ? 'Micro coupé' : 'Micro',
          actif: !media.isMuted,
          onPressed: media.toggleMute,
        ),
        _bouton(
          icone: media.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          libelle: 'Haut-parleur',
          actif: media.isSpeakerOn,
          onPressed: media.toggleSpeaker,
        ),
        if (widget.video)
          _bouton(
            icone: Icons.cameraswitch,
            libelle: 'Caméra',
            actif: true,
            onPressed: media.switchCamera,
          ),
        _bouton(
          icone: Icons.call_end,
          libelle: 'Raccrocher',
          actif: true,
          couleur: Colors.red,
          onPressed: _raccrocher,
        ),
      ],
    );
  }

  Widget _bouton({
    required IconData icone,
    required String libelle,
    required bool actif,
    required Future<void> Function() onPressed,
    Color? couleur,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: libelle,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: couleur ?? (actif ? Colors.white24 : Colors.white10),
              child: IconButton(
                icon: Icon(icone, color: Colors.white),
                onPressed: () => unawaited(onPressed()),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(libelle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
