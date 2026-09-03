import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:elcora_dely/config/adresses.dart';
import 'package:elcora_dely/services/agora_call_service.dart';

/// Appels livreur ↔ client — **la signalisation**, `/api/v1/calls/` et
/// `ws/me/`.
///
/// ## Ce que ce service remplace
///
/// `dely` avait un écran d'appel qui n'appelait personne. Il composait
/// lui-même le canal Agora (`order_{orderId}`), dérivait son `uid` d'un
/// `hashCode` d'identifiant, rejoignait avec un **jeton vide**, et prévenait
/// le client… en lui envoyant un message dans la conversation
/// (« 📞 Appel vocal en cours… »). Aucune de ces quatre choses ne pouvait
/// marcher contre le backend réel :
///
/// * le serveur dérive le canal de l'**appel** (`call-{uuid}`), pas de la
///   commande — les deux applications ne se seraient jamais retrouvées dans la
///   même pièce, et un canal composé sur l'identifiant de commande laissait
///   rejoindre la conversation de n'importe quelle commande qu'on connaît ;
/// * le serveur attribue `1` à l'appelant et `2` au destinataire — un
///   `hashCode` tronqué entre en collision, et deux participants au même `uid`
///   s'expulsent mutuellement du canal ;
/// * le jeton est **signé côté serveur** ; le certificat Agora n'est pas dans
///   l'application, et un jeton vide n'ouvre rien dès que le projet Agora en
///   exige un ;
/// * et surtout, **rien ne faisait sonner le téléphone d'en face** : sans
///   `POST /calls/orders/{id}/`, aucun `Call` n'existe, et le client n'a
///   jamais été prévenu autrement que par une ligne de conversation.
///
/// L'app cliente, elle, était déjà branchée correctement
/// (`apps/fastfood/lib/services/call_service.dart`). La fonctionnalité était
/// donc à moitié construite, et les deux moitiés ne se rencontraient pas.
///
/// ## Séparation avec [AgoraCallService]
///
/// Deux services, deux sujets, et c'est délibéré :
///
/// * **celui-ci** décide *qui* appelle *qui* et *quand* — et il ne décide rien
///   en réalité, il relaie ce que le serveur a tranché ;
/// * [AgoraCallService] porte le **média** — micro, haut-parleur, caméra,
///   canal RTC. Il ne sait rien des commandes ni des courses.
///
/// Les fusionner ferait dépendre la signalisation du moteur RTC, donc rendrait
/// intestable l'une sans l'autre.
///
/// ## La file personnelle suit la session, pas un écran
///
/// `ws/me/` est ouvert par [demarrer], appelé depuis `AppService` à l'ouverture
/// de session — au même endroit que la file des courses et l'émission de
/// position. Un appel entrant doit joindre le livreur **où qu'il soit** dans
/// l'application, y compris sur un écran qui ne connaît pas la commande
/// concernée ; l'accrocher au montage d'un widget le ferait taire dès que cet
/// écran se ferme.
class CallService extends ChangeNotifier {
  static CallService? _instance;

  factory CallService(ProviderContainer container) {
    return _instance ??= CallService._internal(container);
  }

  CallService._internal(this._container);

  final ProviderContainer _container;

  /// Construit à la demande, comme les autres dépôts de `dely` : l'`ApiClient`
  /// vit dans le conteneur Riverpod créé par `main()`, et le lire au
  /// constructeur le figerait avant que les surcharges de test s'appliquent.
  eccore.CallRepository? _repository;
  eccore.CallRepository get _calls =>
      _repository ??= eccore.CallRepository(apiClient: _container.read(eccore.apiClientProvider));

  final AgoraCallService _media = AgoraCallService();

  eccore.RealtimeChannel? _channel;
  StreamSubscription<eccore.RealtimeEvent>? _subscription;

  final StreamController<eccore.Call> _entrants = StreamController<eccore.Call>.broadcast();
  final StreamController<eccore.Call> _etats = StreamController<eccore.Call>.broadcast();

  /// Les appels qui **sonnent** et qui nous sont adressés.
  Stream<eccore.Call> get appelsEntrants => _entrants.stream;

  /// Tout changement d'état d'un appel en cours — décroché d'en face,
  /// refusé, raccroché.
  Stream<eccore.Call> get changementsDEtat => _etats.stream;

  eccore.Call? _appelCourant;
  String? _moi;

  /// L'appel en cours, tel que le serveur l'a rendu en dernier. Nul entre deux
  /// appels.
  eccore.Call? get appelCourant => _appelCourant;

  bool get enAppel => _appelCourant?.isActive ?? false;

  /// Suis-je l'appelant de l'appel en cours ?
  bool get jeSuisLAppelant => _appelCourant != null && _appelCourant!.callerId == _moi;

  /// Le nom de l'autre partie, pour l'affichage.
  String get interlocuteur {
    final appel = _appelCourant;
    if (appel == null) return '';
    return jeSuisLAppelant ? appel.calleeName : appel.callerName;
  }

  // ------------------------------------------------- cycle de session

  /// Ouvre la file personnelle. Idempotent : rappelé au même compte, il ne
  /// rouvre rien.
  Future<void> demarrer({required String userId}) async {
    if (_moi == userId && _channel != null) return;

    _moi = userId;
    await _fermerLaFile();

    final channel = eccore.RealtimeChannel(
      wsUrl: adresseWebSocket('/ws/me/'),
      tokenStorage: _container.read(eccore.tokenStorageProvider),
    );
    _channel = channel;
    _subscription = channel.connect().listen(
      _surEvenement,
      onError: (Object erreur) => eccore.Journal.trace('CallService: file en erreur — $erreur'),
    );

    eccore.Journal.trace('✅ CallService: file personnelle ouverte');
  }

  /// Referme tout — à la déconnexion, ou dès que le compte n'est plus celui
  /// d'un livreur. Raccroche un appel encore ouvert : laisser un canal RTC
  /// vivant après une déconnexion laisserait le micro allumé.
  Future<void> arreter() async {
    if (_appelCourant != null) {
      await raccrocher();
    }
    await _fermerLaFile();
    _moi = null;
    _appelCourant = null;
    notifyListeners();
  }

  Future<void> _fermerLaFile() async {
    await _subscription?.cancel();
    await _channel?.close();
    _subscription = null;
    _channel = null;
  }

  /// La file ne transporte que des identifiants (ADR-008) : l'appel est
  /// **relu** pour que l'écran travaille sur l'état du serveur et non sur un
  /// delta que la trame aurait pu tronquer.
  Future<void> _surEvenement(eccore.RealtimeEvent event) async {
    if (!event.type.startsWith('call.')) return;

    final callId = event.payload['call'] as String?;
    if (callId == null || _moi == null) return;

    try {
      final appel = await _calls.getById(callId);

      if (event.type == 'call.incoming') {
        // Un appel entrant pendant qu'un autre est en cours : le serveur
        // l'aurait refusé (une seule conversation active par commande), mais
        // il peut porter sur une **autre** commande. On le refuse alors nous-
        // mêmes, plutôt que de faire sonner par-dessus une conversation.
        if (enAppel) {
          unawaited(_refuserSilencieusement(appel.id));
          return;
        }
        _appelCourant = appel;
        _entrants.add(appel);
      } else {
        _appelCourant = appel.isActive ? appel : null;
        if (!appel.isActive) {
          await _media.leaveChannel();
        }
        _etats.add(appel);
      }
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: relecture de l\'appel impossible — ${e.code}');
    }
  }

  // ------------------------------------------------- gestes du livreur

  /// Appelle le client de cette commande.
  ///
  /// Ni destinataire ni canal ne sont déclarés : le serveur tient les deux. Il
  /// refuse (409) tant qu'aucune livraison n'est en cours — avant, personne
  /// n'est en route ; après, la conversation n'a plus d'objet.
  ///
  /// L'`ApiException` remonte telle quelle : c'est le `detail` du serveur que
  /// l'écran doit afficher (« Aucune livraison en cours sur cette commande »),
  /// pas une phrase inventée ici.
  Future<eccore.Call> appeler({required String orderId, bool video = false}) async {
    final appel = await _calls.place(orderId: orderId, kind: video ? 'video' : 'voice');
    _appelCourant = appel;
    notifyListeners();

    if (!await _rejoindreLeCanal(appel)) {
      // Le canal n'est pas joignable : raccrocher plutôt que laisser un appel
      // sonner chez le client pour une conversation qui n'aura pas lieu.
      await raccrocher();
      throw const eccore.ApiException(
        status: 0,
        code: 'rtc_join_failed',
        detail: 'Impossible d\'ouvrir le canal audio. Vérifiez les permissions du micro.',
      );
    }
    return appel;
  }

  /// Décroche. Le jeton RTC n'est demandé qu'ici : le destinataire n'en a pas
  /// tant qu'il n'a pas accepté, et le serveur en refuse un sur un appel
  /// terminé.
  Future<bool> decrocher(eccore.Call appel) async {
    try {
      final accepte = await _calls.accept(appel.id);
      _appelCourant = accepte;
      notifyListeners();

      if (!await _rejoindreLeCanal(accepte)) {
        await raccrocher();
        return false;
      }
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: décrochage refusé — ${e.code}');
      _appelCourant = null;
      notifyListeners();
      return false;
    }
  }

  /// Refuse un appel entrant.
  Future<void> refuser(eccore.Call appel) async {
    await _refuserSilencieusement(appel.id);
    _appelCourant = null;
    notifyListeners();
  }

  Future<void> _refuserSilencieusement(String callId) async {
    try {
      await _calls.decline(callId);
    } on eccore.ApiException catch (e) {
      // Déjà raccroché d'en face, ou déjà expiré : le résultat recherché est
      // atteint. Le signaler à l'écran ferait apparaître une erreur sur un
      // geste qui a abouti.
      eccore.Journal.trace('CallService: refus sans effet — ${e.code}');
    }
  }

  /// Raccroche — quel que soit le côté d'où l'on parle.
  ///
  /// Le canal RTC est quitté **dans tous les cas**, y compris si l'appel
  /// serveur échoue : le contraire laisserait le micro ouvert sur une panne
  /// réseau.
  Future<void> raccrocher() async {
    final appel = _appelCourant;
    _appelCourant = null;

    if (appel != null) {
      try {
        await _calls.end(appel.id);
      } on eccore.ApiException catch (e) {
        eccore.Journal.trace('CallService: raccrochage non enregistré — ${e.code}');
      }
    }

    await _media.leaveChannel();
    notifyListeners();
  }

  Future<bool> _rejoindreLeCanal(eccore.Call appel) async {
    try {
      final acces = await _calls.rtcCredentials(appel.id);
      return await _media.joinChannel(
        channelId: acces.channelName,
        callType: appel.kind == 'video' ? CallType.video : CallType.voice,
        uid: acces.uid,
        token: acces.token,
      );
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('CallService: jeton RTC refusé — ${e.code}');
      return false;
    }
  }

  /// Les appels passés sur une commande — ce que l'écran d'historique lit.
  Future<List<eccore.Call>> historique(String orderId) async {
    final tous = await _calls.history();
    return tous.where((appel) => appel.orderId == orderId).toList();
  }

  @override
  void dispose() {
    unawaited(_fermerLaFile());
    unawaited(_entrants.close());
    unawaited(_etats.close());
    super.dispose();
  }
}
