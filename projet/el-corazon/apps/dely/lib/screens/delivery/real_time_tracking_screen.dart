import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart'
    show EtatNavigation, EtapeNavigation, Journal, LangueNavigation;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/screens/delivery/widgets/attente_de_la_cuisine.dart';
import 'package:elcora_dely/screens/delivery/widgets/bandeau_instruction.dart';
import 'package:elcora_dely/screens/delivery/widgets/panneau_simulation.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/navigation_service.dart';
import 'package:elcora_dely/widgets/loading_widget.dart';

/// La carte du livreur : suivi de course **et** navigation guidée.
///
/// ## Ce que cet écran est devenu
///
/// Il affichait une carte, trois repères et un trait. Le trait venait bien de
/// Google Directions, mais tout ce qui fait une navigation manquait : les
/// manœuvres étaient jetées à la lecture de la réponse, il n'existait aucune
/// voix dans le projet, rien ne détectait une sortie d'itinéraire, rien ne
/// savait qu'on était arrivé, et la caméra recadrait l'itinéraire entier à
/// chaque recalcul — ce qui annulait le suivi du livreur et son propre geste
/// sur la carte.
///
/// La logique n'est plus ici. Elle est dans `MoteurDeNavigation` (socle), qui
/// se vérifie sans carte ni GPS, et dans `NavigationService`, qui l'assemble
/// avec le flux de position existant. Cet écran dessine, et transmet les
/// gestes.
///
/// ## Ce qui n'a pas changé
///
/// Le parcours métier. L'unique bouton d'avancement vient toujours de
/// `allowed_transitions`, la confirmation de livraison reste obligatoire, et
/// **aucune arrivée détectée par le GPS ne fait avancer une course**. Le GPS
/// guide ; le serveur décide.
class RealTimeTrackingScreen extends StatefulWidget {
  const RealTimeTrackingScreen({required this.order, super.key});

  final Course order;

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  late final NavigationService _navigation;
  late AppService _appService;

  GoogleMapController? _mapController;

  /// La course, telle qu'elle est **maintenant**.
  ///
  /// Part de celle qu'on a reçue, puis suit `AppService` : sans cela, franchir
  /// une étape depuis cet écran n'en changeait pas l'affichage, et le trajet
  /// continuait de viser le restaurant après la récupération.
  late Course _course;

  /// La caméra suit-elle le livreur ?
  ///
  /// Ce bouton s'appelait « démarrer / arrêter le suivi » et n'arrêtait rien de
  /// tel : l'émission vers le serveur vit dans `RealtimeTrackingService`, pour
  /// toute la course, et fermer ce flux-ci ne la touchait pas. Le livreur
  /// croyait donc pouvoir couper son suivi d'un geste — il ne coupait que le
  /// recentrage de sa propre carte.
  bool _suitLeLivreur = true;

  /// Une animation de caméra est-elle en cours de notre fait ?
  ///
  /// `onCameraMoveStarted` se déclenche aussi bien pour un geste du livreur que
  /// pour nos propres animations, et rien dans l'API ne les distingue. Ce
  /// drapeau le fait : sans lui, chaque recentrage automatique se prendrait
  /// pour un geste et couperait le suivi qu'il vient d'appliquer.
  bool _cameraPilotee = false;

  bool _isUpdatingStatus = false;
  bool _pret = false;

  @override
  void initState() {
    super.initState();
    _course = widget.order;
    _navigation = NavigationService()..addListener(_surNavigation);

    _appService = Provider.of<AppService>(context, listen: false);
    _appService.addListener(_surCourse);

    unawaited(_ouvrir());
  }

  Future<void> _ouvrir() async {
    await _navigation.ouvrir(_course);
    if (mounted) setState(() => _pret = true);
  }

  @override
  void dispose() {
    // Chaque ressource est rendue là où elle a été prise : l'écouteur de
    // course, celui de la navigation, la navigation elle-même — qui referme la
    // voix et se désabonne du flux de position — puis la carte.
    _appService.removeListener(_surCourse);
    _navigation.removeListener(_surNavigation);
    unawaited(_navigation.fermer().then((_) => _navigation.dispose()));
    _mapController?.dispose();
    super.dispose();
  }

  void _surNavigation() {
    if (!mounted) return;
    setState(() {});
    unawaited(_majCamera());
  }

  /// La course a bougé — de notre fait, ou par le canal de suivi.
  void _surCourse() {
    if (!mounted) return;
    final rafraichie = _appService.courseForOrder(_course.orderId);
    if (rafraichie == null) return;
    if (rafraichie.assignment.status == _course.assignment.status) return;

    setState(() => _course = rafraichie);
    // C'est ici que la navigation passe du restaurant au client : elle **suit**
    // l'étape que le livreur a déclarée et que le serveur a enregistrée. Elle
    // ne la provoque jamais.
    unawaited(_navigation.majCourse(rafraichie));
  }

  // ------------------------------------------------------------------ caméra

  Future<void> _majCamera() async {
    final carte = _mapController;
    if (carte == null) return;

    if (!_navigation.enNavigation) {
      // En aperçu, la caméra cadre l'itinéraire entier — c'est ce que le
      // livreur consulte.
      return;
    }
    if (!_suitLeLivreur) return;

    final position = _navigation.positionLivreur;
    if (position == null) return;

    await _animer(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 17.5,
          // La carte tourne dans le sens de marche : c'est ce qui permet de
          // lire « à droite » sur l'écran comme à droite sur la route. Sans
          // cap fiable — à l'arrêt — on garde le nord plutôt que de faire
          // pivoter la carte au hasard.
          bearing: _navigation.capLivreur ?? 0,
          tilt: 45,
        ),
      ),
    );
  }

  /// Cadre l'itinéraire entier — l'aperçu.
  Future<void> _cadrerLItineraire() async {
    final carte = _mapController;
    final trace = _navigation.trace;
    if (carte == null || trace.length < 2) return;

    var sudOuest = trace.first;
    var nordEst = trace.first;
    for (final point in trace) {
      sudOuest = LatLng(
        point.latitude < sudOuest.latitude ? point.latitude : sudOuest.latitude,
        point.longitude < sudOuest.longitude
            ? point.longitude
            : sudOuest.longitude,
      );
      nordEst = LatLng(
        point.latitude > nordEst.latitude ? point.latitude : nordEst.latitude,
        point.longitude > nordEst.longitude
            ? point.longitude
            : nordEst.longitude,
      );
    }

    await _animer(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sudOuest, northeast: nordEst),
        80,
      ),
    );
  }

  Future<void> _animer(CameraUpdate maj) async {
    final carte = _mapController;
    if (carte == null) return;

    _cameraPilotee = true;
    try {
      await carte.animateCamera(maj);
    } catch (e) {
      Journal.trace('Caméra : $e');
    }
    // Le délai laisse passer les événements de mouvement que notre propre
    // animation vient d'émettre. Les compter comme des gestes du livreur
    // couperait le suivi à chaque relevé de position.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _cameraPilotee = false;
  }

  /// La carte a bougé : de notre fait, ou de la main du livreur ?
  void _surMouvementDeCamera() {
    if (_cameraPilotee || !_suitLeLivreur) return;
    // Un geste manuel libère la caméra, et rien ne la ramène de force : le
    // livreur regarde peut-être la suite de son trajet. Le bouton « recentrer »
    // apparaît alors, et c'est lui qui rend la main.
    setState(() => _suitLeLivreur = false);
  }

  Future<void> _recentrer() async {
    setState(() => _suitLeLivreur = true);
    if (_navigation.enNavigation) {
      await _majCamera();
    } else {
      await _cadrerLItineraire();
    }
  }

  // ------------------------------------------------------------- métier

  /// Fait franchir une étape à la course, puis relit ce que le serveur a
  /// réellement enregistré.
  ///
  /// L'écran fermait auparavant dès l'appel parti, quelle que soit l'étape :
  /// le livreur en déduisait que c'était fait, alors que la réponse pouvait
  /// encore refuser. Il ne se ferme que sur une course terminée.
  Future<void> _updateOrderStatus(EtapeCourse etape) async {
    if (_isUpdatingStatus) return;

    if (etape == EtapeCourse.livree && !await _confirmerLivraison()) return;
    if (!mounted) return;

    setState(() => _isUpdatingStatus = true);
    try {
      await _appService.updateOrderStatus(_course.orderId, etape);

      // La course rendue par le serveur porte la nouvelle étape **et** les
      // transitions désormais permises : c'est elle qui décide de la suite. Le
      // basculement de la navigation vers le client passe par `_surCourse`,
      // que `AppService` déclenche en notifiant.
      final rafraichie = _appService.courseForOrder(_course.orderId);

      if (!mounted) return;
      setState(() {
        if (rafraichie != null) _course = rafraichie;
        _isUpdatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course mise à jour : ${etape.libelle}'),
          backgroundColor: Colors.green,
        ),
      );

      // La course est close : il n'y a plus rien à suivre sur cette carte.
      //
      // Le suivi GPS, lui, s'arrête tout seul : `AppService` referme la porte
      // dès qu'aucune course n'est active (`suivreLaCourse`). Le faire aussi
      // ici laisserait croire que c'est cet écran qui en décide.
      // Sur l'étape **terminale**, et non sur « plus rien à faire » : depuis
      // que le retrait attend la cuisine, `prochaineEtape` est aussi nulle
      // pendant l'attente — fermer l'écran à ce moment-là renverrait le livreur
      // à sa liste alors qu'il est devant le comptoir.
      if (mounted && !_course.etape.estEnCours) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageErreur(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Demande confirmation avant de déclarer la livraison faite.
  ///
  /// L'étape est **irréversible** : la machine à états du serveur est
  /// acyclique, une course livrée ne se rouvre pas, et c'est elle qui crédite
  /// la rémunération. Un appui malheureux sur un téléphone posé sur un guidon
  /// ne doit pas la déclencher — et l'arrivée détectée par le GPS ne la
  /// déclenche pas non plus : elle allume un bouton, elle ne l'appuie pas.
  ///
  /// Il n'y a **pas** de preuve de livraison à demander ici : le contrat
  /// n'expose ni code, ni photo, ni signature — `Assignment.proof_of_delivery`
  /// existe en base mais aucun sérialiseur ni aucune vue ne le rend
  /// accessible. En fabriquer une côté application donnerait une garantie que
  /// rien ne vérifie.
  Future<bool> _confirmerLivraison() async {
    // `amount_to_collect`, et non le total filtré par le moyen de paiement :
    // c'est le serveur qui sait ce qui reste dû.
    final montant = _course.aEncaisser?.format();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Text(
          montant == null
              ? 'La commande ${_course.reference} a bien été remise au client ?\n\n'
                  'Cette étape est définitive.'
              : 'La commande ${_course.reference} a bien été remise, et vous '
                  'avez encaissé $montant ?\n\nCette étape est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, c\'est livré'),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  // -------------------------------------------------------------- rendu

  @override
  Widget build(BuildContext context) {
    if (!_pret) {
      return const Scaffold(
        body: LoadingWidget(message: 'Préparation de la navigation...'),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _carte(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _hautDeLEcran()),
          ),
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).size.height * 0.34 + 12,
            child: _boutonsFlottants(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _basDeLEcran(),
          ),
        ],
      ),
    );
  }

  Widget _carte() {
    final destination = _navigation.destination;
    final livreur = _navigation.positionLivreur;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        // Jamais un point écrit en dur : à défaut de position du livreur, la
        // carte s'ouvre sur là où il doit aller.
        target: livreur ?? destination ?? const LatLng(0, 0),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        unawaited(_cadrerLItineraire());
      },
      onCameraMoveStarted: _surMouvementDeCamera,
      markers: _reperes(),
      polylines: _traces(),
      // Le point bleu du système reste **éteint** — c'est le défaut, et on ne
      // l'allume pas — au profit de notre repère. Deux raisons : il ignore le
      // trajet simulé du mode debug (il afficherait la position réelle du
      // développeur pendant qu'on rejoue un trajet à Lomé), et il ne tourne pas
      // dans le sens de marche.
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      padding: EdgeInsets.only(
        top: 140,
        bottom: MediaQuery.of(context).size.height * 0.34,
      ),
    );
  }

  Set<Marker> _reperes() {
    final livreur = _navigation.positionLivreur;
    final restaurant = _navigation.pointRestaurant;
    final client = _navigation.pointClient;

    return {
      if (livreur != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: livreur,
          // Le repère tourne dans le sens de marche, et il est **plat** :
          // posé sur la carte, il tourne avec elle. Un repère dressé
          // resterait vertical pendant que la carte pivote, et pointerait
          // alors n'importe où.
          rotation: _navigation.capLivreur ?? 0,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Votre position'),
        ),
      if (restaurant != null)
        Marker(
          markerId: const MarkerId('restaurant'),
          position: restaurant,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: _course.assignment.restaurantName,
            snippet: 'Point de retrait',
          ),
        ),
      if (client != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: client,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: _course.destinataire.isEmpty ? 'Client' : _course.destinataire,
            snippet: _course.adresseLivraison,
          ),
        ),
    };
  }

  Set<Polyline> _traces() {
    final trace = _navigation.trace;
    if (trace.length < 2) return const {};

    final approximatif = _navigation.traceApproximatif;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: trace,
        // Le repli en ligne droite se **voit** : pointillés et couleur
        // atténuée. Il était auparavant dessiné comme un itinéraire, ce qui
        // invitait le livreur à suivre un trait qui traverse les murs.
        color: approximatif
            ? Colors.blueGrey.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.primary,
        width: approximatif ? 4 : 7,
        patterns: approximatif
            ? [PatternItem.dash(20), PatternItem.gap(12)]
            : const [],
      ),
    };
  }

  Widget _hautDeLEcran() {
    final instruction = _navigation.instruction;
    final enNavigation = _navigation.enNavigation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              _rondBouton(
                Icons.arrow_back,
                'Retour',
                () => Navigator.pop(context),
              ),
              const Spacer(),
              _rondBouton(
                Icons.more_vert,
                'Plus',
                _menu,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (enNavigation && instruction != null)
            BandeauInstruction(
              instruction: instruction,
              manoeuvre: _navigation.manoeuvre,
              distanceMetres: _navigation.distanceAvantManoeuvreMetres,
              instructionSuivante: _navigation.instructionSuivante,
            )
          else
            _enteteApercu(),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            PanneauSimulation(navigation: _navigation),
          ],
        ],
      ),
    );
  }

  Widget _enteteApercu() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              _navigation.etapeNavigation == EtapeNavigation.restaurant
                  ? Icons.storefront
                  : Icons.home_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Course ${_course.reference}',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    'Vers ${_navigation.destinationLibelle}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonsFlottants() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_suitLeLivreur)
          _rondBouton(Icons.my_location, 'Recentrer', _recentrer),
        if (!_suitLeLivreur) const SizedBox(height: 8),
        if (_navigation.enNavigation) ...[
          _rondBouton(
            _navigation.voix.actif ? Icons.volume_up : Icons.volume_off,
            _navigation.voix.actif ? 'Couper la voix' : 'Rétablir la voix',
            () => _navigation.voix.definirActif(actif: !_navigation.voix.actif),
          ),
          const SizedBox(height: 8),
          _rondBouton(
            Icons.replay,
            'Répéter l’instruction',
            _navigation.repeterLInstruction,
          ),
          const SizedBox(height: 8),
        ],
        _rondBouton(
          Icons.refresh,
          'Recalculer l’itinéraire',
          _navigation.calculEnCours ? null : _navigation.recalculer,
        ),
      ],
    );
  }

  Widget _rondBouton(IconData icone, String infobulle, VoidCallback? action) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        onPressed: action,
        icon: Icon(icone),
        tooltip: infobulle,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _basDeLEcran() {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bandeauEtat(),
              const SizedBox(height: 10),
              _mesures(),
              const SizedBox(height: 12),
              _boutonDeMode(),
              const SizedBox(height: 8),
              _buildActionSuivante(),
            ],
          ),
        ),
      ),
    );
  }

  /// Ce que le livreur doit savoir de l'état du guidage, en une ligne.
  ///
  /// Trois choses s'y disputent la place, et l'ordre est celui de l'urgence :
  /// une arrivée détectée, un obstacle au suivi, puis l'état ordinaire. Le
  /// voyant de suivi vient du service qui l'assure — c'est le seul moyen pour
  /// le livreur d'apprendre qu'il n'est pas suivi autrement que par le reproche
  /// d'un client.
  Widget _bandeauEtat() {
    final theme = Theme.of(context);
    final etat = _navigation.etat;
    final obstacle = _navigation.obstacle;

    final (IconData icone, Color couleur, String texte) = switch (etat) {
      EtatNavigation.arriveAuRestaurant => (
          Icons.storefront,
          Colors.green,
          'Vous êtes arrivé au restaurant.',
        ),
      EtatNavigation.arriveChezLeClient => (
          Icons.flag,
          Colors.green,
          'Vous êtes arrivé chez le client.',
        ),
      EtatNavigation.horsItineraire => (
          Icons.alt_route,
          Colors.orange,
          'Vous avez quitté l’itinéraire. Recalcul en cours…',
        ),
      EtatNavigation.positionIndisponible => (
          Icons.gps_off,
          Colors.orange,
          obstacle ?? 'Position indisponible.',
        ),
      EtatNavigation.erreur => (
          Icons.error_outline,
          Colors.red,
          obstacle ?? 'Itinéraire indisponible.',
        ),
      EtatNavigation.preparation => (
          Icons.hourglass_empty,
          Colors.blueGrey,
          'Calcul de l’itinéraire…',
        ),
      EtatNavigation.terminee => (
          Icons.check_circle,
          Colors.green,
          'Course terminée.',
        ),
      _ => _navigation.positionSuivie
          ? (Icons.gps_fixed, Colors.green, 'Suivi actif')
          : (Icons.gps_not_fixed, Colors.grey, 'Suivi interrompu'),
    };

    return Row(
      children: [
        Icon(icone, size: 18, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: couleur, fontWeight: FontWeight.w600),
            maxLines: 2,
          ),
        ),
        if (_navigation.traceApproximatif)
          Tooltip(
            message: 'Tracé approximatif : itinéraire routier indisponible.',
            child: Icon(
              Icons.warning_amber,
              size: 18,
              color: Colors.orange.shade700,
            ),
          ),
      ],
    );
  }

  Widget _mesures() {
    final distance = _navigation.distanceRestanteMetres;
    final duree = _navigation.dureeRestante;
    final arrivee = _navigation.heureArriveeEstimee;

    return Row(
      children: [
        Expanded(
          child: _mesure(
            Icons.schedule,
            'Arrivée',
            arrivee == null ? '—' : DateFormat.Hm().format(arrivee),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _mesure(
            Icons.timer_outlined,
            'Restant',
            duree == null ? '—' : _dureeLisible(duree),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _mesure(
            Icons.straighten,
            'Distance',
            distance == null ? '—' : distanceLisible(distance),
          ),
        ),
      ],
    );
  }

  static String _dureeLisible(Duration duree) {
    if (duree.inMinutes < 60) return '${duree.inMinutes} min';
    return '${duree.inHours} h ${duree.inMinutes % 60} min';
  }

  Widget _mesure(IconData icone, String titre, String valeur) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icone, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 2),
          Text(
            valeur,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
          Text(titre, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _boutonDeMode() {
    final enNavigation = _navigation.enNavigation;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enNavigation
            ? _navigation.arreterLaNavigation
            : _demarrerLaNavigation,
        icon: Icon(enNavigation ? Icons.stop_circle_outlined : Icons.navigation),
        label: Text(
          enNavigation
              // Le libellé dit ce que le bouton fait : il arrête le **guidage**,
              // pas le suivi de la course, qui appartient au serveur et au
              // client.
              ? 'Arrêter le guidage vocal'
              : 'Démarrer la navigation',
        ),
      ),
    );
  }

  Future<void> _demarrerLaNavigation() async {
    setState(() => _suitLeLivreur = true);
    await _navigation.demarrerLaNavigation();
    await _majCamera();
  }

  /// L'unique bouton d'avancement, décidé par le serveur.
  ///
  /// Deux boutons figés occupaient cette place — « Commande récupérée » et
  /// « Livré » — affichés quelle que soit l'étape. « Livré » était donc
  /// proposé à un livreur qui venait d'accepter, sur une transition que la
  /// machine à états refuse : l'appui produisait une erreur, sans que rien
  /// n'ait indiqué que le geste était impossible.
  ///
  /// `allowed_transitions` dit ce que le serveur accepte depuis l'état
  /// courant. Un seul bouton en découle, et il disparaît quand il n'y a plus
  /// rien à franchir. **L'arrivée détectée par le GPS ne le remplace pas** :
  /// elle le met en avant, elle ne l'appuie pas.
  Widget _buildActionSuivante() {
    final suivante = _course.prochaineEtape;

    // L'attente de la cuisine passe avant l'état « rien à faire » : sans cette
    // branche, l'écran annoncerait « Course terminée — Acceptée » à un livreur
    // qui attend simplement que le repas sorte.
    if (suivante == null && _course.enAttenteDeLaCuisine) {
      return const AttenteDeLaCuisine();
    }

    if (suivante == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Course terminée — ${_course.etape.libelle}.',
                style: const TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    final estLivraison = suivante == EtapeCourse.livree;
    // L'arrivée détectée met le geste en avant — c'est le moment où le livreur
    // en a besoin — sans rien décider à sa place.
    final misEnAvant = _navigation.etat.estUneArrivee;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
            _isUpdatingStatus ? null : () => _updateOrderStatus(suivante),
        icon: _isUpdatingStatus
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(_iconeEtape(suivante)),
        label: Text(_libelleAction(suivante)),
        style: ElevatedButton.styleFrom(
          backgroundColor: estLivraison
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: misEnAvant ? 18 : 14),
          elevation: misEnAvant ? 6 : 2,
        ),
      ),
    );
  }

  /// Le geste, pas l'état : le bouton dit ce que le livreur fait.
  String _libelleAction(EtapeCourse etape) => switch (etape) {
        EtapeCourse.recuperee => 'J\'ai récupéré la commande',
        EtapeCourse.enRoute => 'Je pars chez le client',
        EtapeCourse.livree => 'J\'ai livré la commande',
        _ => etape.libelle,
      };

  IconData _iconeEtape(EtapeCourse etape) => switch (etape) {
        EtapeCourse.recuperee => Icons.shopping_bag,
        EtapeCourse.enRoute => Icons.delivery_dining,
        EtapeCourse.livree => Icons.check_circle,
        _ => Icons.arrow_forward,
      };

  void _menu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Langue du guidage'),
              subtitle: Text(
                _navigation.langue == LangueNavigation.francais
                    ? 'Français'
                    : 'English',
              ),
              onTap: () {
                Navigator.pop(feuille);
                unawaited(
                  _navigation.definirLangue(
                    _navigation.langue == LangueNavigation.francais
                        ? LangueNavigation.anglais
                        : LangueNavigation.francais,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Mon profil'),
              onTap: () {
                Navigator.pop(feuille);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const DriverProfileScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(feuille);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
