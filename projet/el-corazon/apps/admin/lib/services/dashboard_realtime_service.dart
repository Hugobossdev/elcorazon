import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Ce que l'écran affiche du lien temps réel.
///
/// Trois états et pas deux : « hors ligne » et « en reconnexion » ne se
/// corrigent pas de la même façon, et les confondre ferait recharger la page à
/// quelqu'un qui n'a qu'à attendre trois secondes.
enum EtatTempsReel {
  /// Aucun canal ouvert — pas de session, pas de périmètre, ou fermé
  /// volontairement.
  ferme,

  /// Poignée de main en cours, ou attente avant une nouvelle tentative.
  connexion,

  /// Canal ouvert : les changements arrivent d'eux-mêmes.
  connecte,

  /// Le serveur a refusé le canal (code `4403`) — permission `orders.read`
  /// manquante, ou établissement hors périmètre. Réessayer ne le rendra pas
  /// autorisé, mais le back-office reste utilisable : tout passe par le REST.
  refuse,
}

/// Le tableau de bord en temps réel — `ws/restaurants/{id}/dashboard/`.
///
/// Pourquoi ce service existe
/// --------------------------
///
/// Le canal existait côté serveur depuis l'origine (`RestaurantDashboardConsumer`,
/// ADR-008) et **aucune application ne s'y connectait**. La supervision ne se
/// mettait à jour qu'au clic sur « Recharger » : une commande passée à
/// l'instant n'apparaissait pas, un statut changé en cuisine restait affiché
/// tel qu'il était à l'ouverture de l'écran.
///
/// Ce que ce service **ne fait pas**, et c'est le point de conception :
///
/// * il ne recharge pas la liste à chaque événement. Un `order.status` sur une
///   commande affichée provoque **une** lecture de cette commande, pas de la
///   page. À trente commandes à l'écran et un service en cours, la différence
///   est entre une requête et trente ;
/// * il ne remplace pas le bouton « Recharger », qui reste le seul geste
///   capable de reprendre la pagination et les filtres depuis le serveur ;
/// * il ne prétend jamais être connecté quand il ne l'est pas. [etat] est
///   dérivé de la vie réelle du socket, jamais posé par optimisme.
///
/// La reprise après coupure vit ici et non dans `RealtimeChannel`, qui ne tente
/// **qu'une seule** reconnexion avant de fermer le flux. C'est la politique du
/// socle, partagée avec les applications client et livreur, et elle ne convient
/// pas à un écran qui reste ouvert toute la soirée : après deux coupures — un
/// Wi-Fi qui bascule, un serveur qui redémarre — le canal restait fermé pour le
/// reste de la session, sans que rien ne le rouvre. `dely` avait rencontré le
/// même besoin et l'a résolu de la même façon (`RealtimeTrackingService`).
class DashboardRealtimeService extends ChangeNotifier {
  static final DashboardRealtimeService _instance = DashboardRealtimeService._internal();

  factory DashboardRealtimeService() => _instance;

  DashboardRealtimeService._internal() {
    // Le canal suit la session, pas l'écran. À la déconnexion il se ferme —
    // un socket ouvert au nom d'un compte parti continuerait de recevoir les
    // commandes de son établissement ; à la connexion suivante, il s'ouvre au
    // nom du nouveau, dont le périmètre peut être un autre.
    AdminAuthService().addListener(_surChangementDeSession);
  }

  void _surChangementDeSession() {
    if (AdminAuthService().isAuthenticated) {
      // Sans `_souhaiteConnexion`, une session restaurée au démarrage
      // ouvrirait le canal avant qu'un écran l'ait demandé. On ne rouvre que
      // ce qui était ouvert.
      if (_souhaiteConnexion) unawaited(connect());
    } else {
      unawaited(disconnect());
    }
  }

  /// Instance isolée pour les tests : la version partagée observe la session et
  /// ouvre un vrai socket.
  @visibleForTesting
  DashboardRealtimeService.pourTests();

  /// Report exponentiel, plafonné à une minute.
  ///
  /// Plafonné parce qu'il est inutile de marteler un serveur injoignable, et
  /// borné à une minute parce qu'un écran de supervision doit se raccrocher de
  /// lui-même dès que le réseau revient — sans que l'opérateur ait à recharger
  /// la page pour s'en apercevoir.
  static const _delaisDeReprise = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  eccore.RealtimeChannel? _canal;
  StreamSubscription<eccore.RealtimeEvent>? _abonnement;
  Timer? _repriseTimer;
  int _tentatives = 0;

  /// L'établissement dont le canal est ouvert. Sert à ne pas rouvrir un socket
  /// déjà ouvert sur le même établissement, et à en ouvrir un nouveau quand le
  /// sélecteur d'établissement change.
  String? _restaurantIdCourant;

  /// L'appelant veut-il être connecté ? Distinct de [etat], qui dit où en est
  /// la connexion : sans ce drapeau, une reprise programmée rouvrirait un canal
  /// que l'écran vient de fermer.
  bool _souhaiteConnexion = false;

  EtatTempsReel _etat = EtatTempsReel.ferme;
  DateTime? _dernierEvenement;
  int _evenementsRecus = 0;

  EtatTempsReel get etat => _etat;

  /// Quand le dernier événement est arrivé. `null` tant qu'il n'en est arrivé
  /// aucun — ce qui est le cas normal d'un service calme, pas un défaut.
  DateTime? get dernierEvenement => _dernierEvenement;

  int get evenementsRecus => _evenementsRecus;

  /// Les commandes dont le statut a changé, à mesure que le serveur le dit.
  ///
  /// Un flux plutôt qu'un rappel : plusieurs écrans peuvent écouter le même
  /// canal — la supervision, les livraisons actives, le tableau de bord — sans
  /// que ce service ait à les connaître.
  Stream<ChangementDeStatut> get changements => _changements.stream;
  final _changements = StreamController<ChangementDeStatut>.broadcast();

  /// Signalé quand le canal se (re)connecte.
  ///
  /// C'est le moment où l'écran doit recharger sa page : pendant la coupure,
  /// des événements ont pu passer sans que personne les reçoive. Le serveur
  /// sait rejouer un historique borné (`?since=`), mais recharger une page de
  /// vingt lignes est plus simple **et plus juste** qu'appliquer cinquante
  /// événements à une liste paginée — c'est d'ailleurs ce que recommande
  /// `common/realtime.py` au-delà du journal.
  Stream<void> get reconnexions => _reconnexions.stream;
  final _reconnexions = StreamController<void>.broadcast();

  // ---------------------------------------------------------------- cycle

  /// Ouvre le canal de l'établissement supervisé.
  ///
  /// Sans effet si le canal est déjà ouvert sur ce même établissement : c'est
  /// la garde contre les connexions multiples, et elle est nécessaire parce que
  /// plusieurs écrans appellent cette méthode à leur montage.
  Future<void> connect() async {
    final etablissement = await RestaurantScopeService().requireSlug() == null
        ? null
        : RestaurantScopeService().current;

    if (etablissement == null) {
      eccore.Journal.trace(
        'Temps réel : aucun établissement supervisé — canal non ouvert.',
      );
      return;
    }

    if (!AdminAuthService().isAuthenticated) return;

    _souhaiteConnexion = true;

    if (_canal != null && _restaurantIdCourant == etablissement.id) return;

    await _fermerLeCanal();
    _restaurantIdCourant = etablissement.id;
    _tentatives = 0;
    await _ouvrir();
  }

  /// Ferme le canal et annule toute reprise programmée.
  ///
  /// À appeler à la déconnexion et quand l'application passe en arrière-plan :
  /// un socket laissé ouvert derrière un écran verrouillé consomme de la
  /// batterie pour des événements que personne ne lit.
  Future<void> disconnect() async {
    _souhaiteConnexion = false;
    _repriseTimer?.cancel();
    _repriseTimer = null;
    _tentatives = 0;
    await _fermerLeCanal();
    _restaurantIdCourant = null;
    _poser(EtatTempsReel.ferme);
  }

  Future<void> _fermerLeCanal() async {
    await _abonnement?.cancel();
    _abonnement = null;
    await _canal?.close();
    _canal = null;
  }

  Future<void> _ouvrir() async {
    final restaurantId = _restaurantIdCourant;
    if (restaurantId == null || !_souhaiteConnexion) return;

    _poser(EtatTempsReel.connexion);

    final canal = eccore.RealtimeChannel(
      wsUrl: _wsUrl('/ws/restaurants/$restaurantId/dashboard/'),
      tokenStorage: eccore.TokenStorage(),
    );
    _canal = canal;

    var aRecuUnEvenement = false;

    _abonnement = canal.connect().listen(
      (evenement) {
        // Un message reçu prouve que le canal fonctionne : le compteur de
        // reprises repart de zéro, sans quoi une coupure passée imposerait
        // encore une minute d'attente à la suivante.
        _tentatives = 0;
        if (!aRecuUnEvenement) {
          aRecuUnEvenement = true;
          _poser(EtatTempsReel.connecte);
        }
        _traiter(evenement);
      },
      onDone: () {
        // `RealtimeChannel` ferme le flux après sa propre tentative unique. La
        // distinction se fait sur le code : un refus (`4403`) ne se rejoue pas
        // en boucle — il ne deviendrait pas autorisé — mais il est reprogrammé
        // à l'intervalle plafond, ce qui rouvre le canal de lui-même dès qu'un
        // rôle est corrigé, sans redémarrer l'application.
        final refus = _canal?.closeCodeWasForbidden ?? false;
        _poser(refus ? EtatTempsReel.refuse : EtatTempsReel.connexion);
        _programmerLaReprise(plafond: refus);
      },
    );

    // Le socle n'expose pas d'événement « ouvert » : la poignée de main
    // réussie ne se manifeste que par le premier message, et un service calme
    // n'en envoie aucun. On considère donc le canal connecté dès qu'il n'a pas
    // été refermé aussitôt — `onDone` corrige en sens inverse si c'est le cas.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (_canal == canal && _etat == EtatTempsReel.connexion && _souhaiteConnexion) {
        _poser(EtatTempsReel.connecte);
        _reconnexions.add(null);
      }
    });
  }

  void _programmerLaReprise({bool plafond = false}) {
    if (!_souhaiteConnexion) return;

    _repriseTimer?.cancel();
    final delai = plafond
        ? _delaisDeReprise.last
        : _delaisDeReprise[_tentatives.clamp(0, _delaisDeReprise.length - 1)];
    _tentatives++;

    eccore.Journal.trace(
      'Temps réel : canal fermé — nouvelle tentative dans ${delai.inSeconds} s',
    );

    _repriseTimer = Timer(delai, () {
      if (_souhaiteConnexion) unawaited(_ouvrir());
    });
  }

  // -------------------------------------------------------------- lecture

  /// Traduit un événement du canal en changement de statut.
  ///
  /// Le seul type diffusé sur ce groupe est `order.status`
  /// (`apps/orders/services.py`). `realtime.gap` peut arriver après une
  /// reconnexion avec rattrapage : il signale un trou dans le journal, donc un
  /// état local incomplet — la seule réponse juste est de recharger.
  @visibleForTesting
  void traiterPourTests(eccore.RealtimeEvent evenement) => _traiter(evenement);

  void _traiter(eccore.RealtimeEvent evenement) {
    _dernierEvenement = DateTime.now();
    _evenementsRecus++;

    switch (evenement.type) {
      case 'order.status':
        final orderId = evenement.payload['order'] as String?;
        if (orderId == null) return;
        _changements.add(
          ChangementDeStatut(
            orderId: orderId,
            reference: evenement.payload['reference'] as String? ?? '',
            depuis: evenement.payload['from_status'] as String? ?? '',
            vers: evenement.payload['status'] as String? ?? '',
            motif: evenement.payload['reason'] as String? ?? '',
          ),
        );
      case 'realtime.gap':
        // Le client a été absent plus longtemps que le journal du serveur : ce
        // qu'il affiche est incomplet, et aucun événement ultérieur ne le
        // corrigera. Recharger est la seule réponse juste.
        eccore.Journal.trace('Temps réel : trou dans le journal — rechargement.');
        _reconnexions.add(null);
    }
    notifyListeners();
  }

  void _poser(EtatTempsReel etat) {
    if (_etat == etat) return;
    _etat = etat;
    notifyListeners();
  }

  /// L'URL du canal, dérivée de celle de l'API.
  ///
  /// Même construction que dans `dely` : `https` donne `wss`, tout le reste
  /// donne `ws`. Le port est repris tel quel — en développement, l'API et le
  /// canal partagent le même.
  String _wsUrl(String chemin) {
    final base = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';
    final uri = Uri.parse(base);
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: uri.port,
      path: chemin,
    ).toString();
  }

  @override
  void dispose() {
    _repriseTimer?.cancel();
    unawaited(_fermerLeCanal());
    unawaited(_changements.close());
    unawaited(_reconnexions.close());
    super.dispose();
  }
}

/// Un changement de statut annoncé par le serveur.
///
/// Porte ce que le canal envoie et rien de plus : l'écran qui en a besoin
/// relit la commande. Reconstruire une commande à partir de cette charge
/// donnerait un objet privé de `allowed_transitions` — et donc des boutons
/// faux.
@immutable
class ChangementDeStatut {
  const ChangementDeStatut({
    required this.orderId,
    required this.reference,
    required this.depuis,
    required this.vers,
    required this.motif,
  });

  final String orderId;
  final String reference;

  /// Vide sur la toute première transition, la commande n'ayant pas d'avant.
  final String depuis;

  final String vers;

  /// Motif saisi par le personnel, ou vide si la transition vient du système.
  final String motif;
}
