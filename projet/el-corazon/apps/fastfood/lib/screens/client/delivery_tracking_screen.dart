import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:elcora_fast/presentation/deplacement_livreur.dart';
import 'package:elcora_fast/presentation/trajet_livreur.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/realtime_tracking_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/services/geocoding_service.dart';
import 'package:elcora_fast/services/directions_service.dart';
import 'package:elcora_fast/services/driver_rating_service.dart';
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/position_livreur.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/screens/client/chat_screen.dart';
import 'package:elcora_fast/screens/client/call_screen.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/presentation/suivi_commande.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;

/// Écran de suivi de livraison en temps réel
class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreen({
    required this.orderId,
    super.key,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  PositionLivreur? _deliveryLocation;
  String? _estimatedDeliveryTime;
  Map<String, dynamic>? _driverProfile;
  double? _driverRating; // Note moyenne du livreur
  int _driverRatingCount = 0; // Nombre d'évaluations du livreur

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {};
  LatLng? _deliveryLatLng;

  /// Point d'enlèvement — d'où part le repas. Nul tant que le serveur ne rend
  /// pas `restaurant_location` : la carte montre alors deux repères au lieu de
  /// trois, ce qui reste juste.
  LatLng? _restaurantLatLng;

  /// Position **affichée** du livreur, distincte de [_deliveryLocation], qui
  /// est la dernière position **relevée**.
  ///
  /// Les deux ne coïncident que lorsque le glissement est terminé. Toutes les
  /// mesures — distance, vitesse, alerte de proximité — portent sur la seconde :
  /// l'interpolation est un confort d'affichage, elle n'a pas à contaminer ce
  /// qu'on annonce au client.
  LatLng? _positionAffichee;
  AnimationController? _glissement;
  LatLng? _glissementDepart;
  LatLng? _glissementArrivee;

  /// Cap issu du **déplacement observé**, quand le relevé n'en porte pas.
  ///
  /// `OrderTrackingConsumer` ne relaie ni la vitesse ni le cap : le livreur les
  /// émet, la diffusion ne les porte pas. Le repère restait donc figé plein
  /// nord pendant toute la livraison. Le segment entre deux relevés le donne.
  double? _capObserve;

  StreamSubscription<Order>? _orderUpdatesSubscription;
  StreamSubscription<PositionLivreur>? _deliveryLocationSubscription;
  RealtimeTrackingService? _trackingService;

  /// Statuts pendant lesquels `ws/orders/{id}/tracking/` accepte une
  /// connexion — miroir de `TRACKABLE_ORDER_STATUSES`
  /// (`backend/apps/tracking/consumers.py`).
  ///
  /// Une commande qui attend encore sa confirmation n'a rien à diffuser, et le
  /// serveur refuse la poignée de main. L'écran s'ouvrant juste après le
  /// paiement, c'est le cas le plus courant : le canal était systématiquement
  /// tenté sur une commande `pending`, systématiquement refusé (403), et
  /// l'échec ressortait en erreur non rattrapée dans la console. Jusqu'à la
  /// confirmation, le rafraîchissement périodique fait le travail.
  static const Set<OrderStatus> _statutsDiffuses = {
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.onTheWay,
  };

  /// Vrai une fois le canal temps réel effectivement ouvert.
  bool _suiviTempsReelOuvert = false;

  /// Cadence de la minuterie actuellement en place — sert à ne la
  /// remplacer que lorsqu'elle doit réellement changer.
  Duration? _cadenceDeRelecture;
  /// Suivi serveur : livreur affecté et dernière position connue.
  final eccore.TrackingRepository _tracking =
      eccore.TrackingRepository(apiClient: apiClient);
  late GeocodingService? _geocodingService;
  late DirectionsService? _directionsService;
  Timer? _estimatedTimeUpdateTimer;
  Timer?
      _orderRefreshTimer; // Timer pour rafraîchir périodiquement depuis la DB

  // Nouvelles fonctionnalités
  List<PositionLivreur> _locationHistory = [];
  bool _proximityAlertShown = false; // Pour éviter les alertes répétées
  double _averageSpeed = 0.0; // Vitesse moyenne en km/h
  double _totalDistance = 0.0; // Distance totale parcourue en km
  bool _isReconnecting = false; // État de reconnexion
  final Map<OrderStatus, DateTime> _statusTimestamps =
      {}; // Horodatage des statuts

  /// Origine et heure du dernier itinéraire demandé à Google.
  ///
  /// ## Ce qu'ils empêchent
  ///
  /// `_getDirections` était appelé depuis `_updateMapMarkers`, donc **à chaque
  /// relevé** — un appel Directions toutes les dix secondes, soit de l'ordre de
  /// 200 par livraison. Le cache du dépôt n'y changeait rien : sa clé contient
  /// l'origine, qui est justement ce qui bouge. Sur une flotte, cela met le
  /// projet Google en quota dans la journée, et un quota dépassé ne dégrade pas
  /// le tracé — il le supprime.
  ///
  /// Le tracé, lui, ne change pas utilement tous les dix mètres : c'est la
  /// **route** qui est affichée, et elle reste la même tant que le livreur la
  /// suit. On la recalcule quand il s'en est écarté ou que le trafic a eu le
  /// temps de bouger.
  LatLng? _origineDuDernierItineraire;
  DateTime? _heureDuDernierItineraire;

  /// Déplacement à partir duquel l'itinéraire mérite d'être redemandé.
  static const double _itineraireSiEcartDeMetres = 400;

  /// Âge à partir duquel il mérite d'être redemandé quoi qu'il arrive — le
  /// trafic a bougé, et une durée d'il y a dix minutes induit en erreur.
  static const Duration _itinerairePerimeApres = Duration(minutes: 3);

  /// Cadence d'émission attendue du livreur, qui règle la durée du glissement
  /// du repère. Lue une fois : les deux applications partagent ce réglage
  /// (`TrackingSettings`), et le suivi n'a pas à le redécouvrir à chaque image.
  ///
  /// `dotenv.env` **lève** tant que le fichier n'a pas été chargé, et `main()`
  /// avale l'échec de `dotenv.load` pour que l'application démarre quand même :
  /// la garde n'est donc pas théorique. Sans elle, ouvrir le suivi sur un
  /// appareil dont le `.env` manque ferait tomber l'écran entier pour un
  /// réglage facultatif.
  late final eccore.TrackingSettings _cadenceDuLivreur =
      eccore.TrackingSettings.depuisEnvironnement(
    dotenv.isInitialized ? dotenv.env : const {},
  );

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _startTracking();
  }

  @override
  void dispose() {
    _orderUpdatesSubscription?.cancel();
    _deliveryLocationSubscription?.cancel();
    _estimatedTimeUpdateTimer?.cancel();
    _orderRefreshTimer?.cancel();
    // Un `AnimationController` non libéré retient son ticker : le glissement
    // continuerait de battre à soixante images par seconde sur un écran fermé.
    _glissement?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    try {
      // Valider l'ID de commande avant de faire la requête
      if (widget.orderId.isEmpty) {
        throw Exception('ID de commande invalide: l\'ID est vide');
      }

      // Valider le format UUID (format basique)
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      if (!uuidPattern.hasMatch(widget.orderId)) {
        eccore.Journal.trace('⚠️ Order ID format may be invalid: ${widget.orderId}');
        // On continue quand même, car certains IDs peuvent avoir un format différent
      }

      final appService = Provider.of<AppService>(context, listen: false);
      _geocodingService = GeocodingService();
      _directionsService = DirectionsService();

      // Charger la commande depuis le backend Django ; à défaut, l'exemplaire
      // déjà en mémoire (parcours hors ligne).
      _order = await DjangoOrderRepository().getOrderById(widget.orderId);
      if (_order == null) {
        final orders = appService.orders;
        try {
          _order = orders.firstWhere((order) => order.id == widget.orderId);
        } catch (_) {
          throw Exception('Commande introuvable');
        }
      }

      // Livreur et dernière position viennent du même appel de suivi.
      if (_order != null) {
        await _placerLesPointsFixes();
        await _loadTracking();
        _initializeStatusTimestamps();
        // C'est ici que le passage de `pending` à `confirmed` est constaté :
        // le canal s'ouvre au moment où le serveur accepte de le servir.
        await _ouvrirSuiviSiDiffuse();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      eccore.Journal.trace('❌ Error loading order details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Erreur lors du chargement de la commande: ${e.toString()}';
      });
    }
  }

  /// Lit `tracking/orders/{id}/` : le livreur tel que le client peut le voir,
  /// et sa dernière position.
  ///
  /// Le contrat ne rend ni l'e-mail ni le téléphone personnel du livreur, et
  /// **pas non plus l'historique complet du trajet** : suivre son repas est un
  /// service, suivre un employé après coup n'en est pas un. La trace affichée
  /// sur la carte est donc celle accumulée pendant la session, depuis le
  /// WebSocket — l'ancienne version relisait tout le trajet en base.
  Future<void> _loadTracking() async {
    try {
      final tracking = await _tracking.forOrder(widget.orderId);
      if (!mounted) return;

      if (tracking.hasCourier && tracking.courier.isNotEmpty) {
        setState(() {
          _driverProfile = {
            'auth_user_id': tracking.courier['id'],
            'name': tracking.courier['full_name'] ?? 'Livreur',
            'profile_image': tracking.courier['avatar'],
            'vehicle_type': tracking.courier['vehicle_type'],
          };
        });
        await _loadDriverRating();
      }

      final position = tracking.lastPosition;
      if (position != null && mounted) {
        setState(() {
          _deliveryLocation = PositionLivreur(
            commandeId: widget.orderId,
            latitude: position.latitude,
            longitude: position.longitude,
            releveeA: position.recordedAt,
            precisionMetres: position.accuracyMeters,
            vitesseMetresParSeconde: position.speedMetersPerSecond,
            capDegres: position.headingDegrees,
          );
        });

        await _calculateEstimatedDeliveryTime();
        _deplacerLeRepereDuLivreur(_deliveryLocation!);
        _checkProximity();
        _calculateDeliveryStats();
      }
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('Suivi indisponible : ${e.code}');
    }
  }

  /// Note du livreur affecté à cette commande — lue dans le suivi
  /// (`tracking/orders/{id}/`), qui la porte déjà : le client voit la note de
  /// celui qui lui livre, et n'interroge pas la fiche d'un livreur au hasard.
  Future<void> _loadDriverRating() async {
    try {
      final note = await DriverRatingService().courierRatingForOrder(widget.orderId);
      if (note != null && mounted) {
        setState(() {
          _driverRating = note.average;
          _driverRatingCount = note.count;
        });
      }
    } catch (e) {
      eccore.Journal.trace('⚠️ Error loading driver rating: $e');
    }
  }

  /// Place les deux points fixes de la carte : d'où part le repas, où il va.
  ///
  /// ## Ce que faisait cette méthode
  ///
  /// Elle **géocodait la ligne d'adresse** — un aller vers Google à chaque
  /// ouverture de l'écran, pour retrouver une valeur que la commande portait
  /// déjà. Le serveur fige `delivery_location` au moment de commander : c'est
  /// le point que le client a lui-même posé sur la carte, pas l'interprétation
  /// d'un libellé. Les deux divergent dès que l'adresse est un repère plutôt
  /// qu'une voie — « en face de la pharmacie du Grand Marché » —, cas dans
  /// lequel le géocodage rendait soit un point à quelques rues de là, soit
  /// rien du tout. Et quand il ne rendait rien, la carte n'avait plus de
  /// destination : ni repère client, ni tracé, ni distance, ni alerte de
  /// proximité, sans qu'aucun message ne l'explique.
  ///
  /// Le géocodage reste en **repli**, pour les commandes qu'un parcours hors
  /// ligne a construites sans coordonnées.
  Future<void> _placerLesPointsFixes() async {
    final order = _order;
    if (order == null) return;

    final latitude = order.deliveryLatitude;
    final longitude = order.deliveryLongitude;
    final restaurantLat = order.restaurantLatitude;
    final restaurantLon = order.restaurantLongitude;

    if (latitude != null && longitude != null) {
      if (!mounted) return;
      setState(() {
        _deliveryLatLng = LatLng(latitude, longitude);
        _restaurantLatLng = restaurantLat == null || restaurantLon == null
            ? null
            : LatLng(restaurantLat, restaurantLon);
      });
      _updateMapMarkers();
      return;
    }

    if (_geocodingService == null) return;
    try {
      final latLng =
          await _geocodingService!.geocodeAddress(order.deliveryAddress);
      if (latLng != null && mounted) {
        setState(() {
          _deliveryLatLng = latLng;
          _restaurantLatLng = restaurantLat == null || restaurantLon == null
              ? null
              : LatLng(restaurantLat, restaurantLon);
        });
        _updateMapMarkers();
      }
    } catch (e) {
      eccore.Journal.trace('⚠️ Error geocoding delivery address: $e');
    }
  }

  void _updateMapMarkers() {
    if (!mounted) return;

    final Set<Marker> markers = {};

    // Marker restaurant (point d'enlèvement) — d'où part le repas.
    //
    // La carte n'en montrait pas : le client voyait son adresse et un point
    // qui s'en approche, sans jamais savoir d'où. C'est pourtant ce qui rend
    // lisible la première moitié de la course, celle où le livreur s'éloigne
    // encore de chez lui.
    if (_restaurantLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantLatLng!,
          infoWindow: InfoWindow(
            title: _order?.items.isNotEmpty == true
                ? 'Restaurant'
                : 'Point de retrait',
            snippet: 'Votre commande part d’ici',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    // Marker client (destination)
    if (_deliveryLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _deliveryLatLng!,
          infoWindow: InfoWindow(
            title: 'Votre adresse',
            snippet: _order?.deliveryAddress ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Marker livreur, posé sur la position **affichée** — celle que le
    // glissement fait avancer — et non sur le dernier relevé : c'est toute la
    // différence entre un repère qui progresse et un repère qui saute.
    final positionAffichee = _positionAffichee;
    if (_deliveryLocation != null && positionAffichee != null) {
      final heading = _deliveryLocation!.capDegres ?? _capObserve;
      final speed = _deliveryLocation!.vitesseKmH?.toStringAsFixed(0);

      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: positionAffichee,
          infoWindow: InfoWindow(
            title: 'Livreur',
            snippet: speed != null ? 'En route • $speed km/h' : 'En route',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: heading ?? 0,
          anchor: const Offset(0.5, 0.5),
          // Un repère « plat » suit la rotation de la carte : il n'a de sens
          // qu'avec un cap. Sans cap, il resterait pointé plein nord en
          // prétendant indiquer une direction.
          flat: heading != null,
        ),
      );
    }

    final Set<Circle> circles = {};

    // Cercle de destination (pulse effect simulation - static for now)
    if (_deliveryLatLng != null) {
      circles.add(
        Circle(
          circleId: const CircleId('destination_area'),
          center: _deliveryLatLng!,
          radius: 100, // 100 meters radius
          fillColor: AppColors.primary.withValues(alpha: 0.1),
          strokeColor: AppColors.primary.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  /// Fait glisser le repère du livreur vers son nouveau relevé.
  ///
  /// Le premier relevé, et tout écart trop grand pour venir d'un déplacement
  /// observé, **reposent** le repère au lieu de l'animer : voir
  /// [sautAuDelaDeMetres]. Faire traverser la ville en ligne droite à un
  /// livreur qui sort d'un tunnel serait plus faux que le saut qu'on évite.
  void _deplacerLeRepereDuLivreur(PositionLivreur releve) {
    final arrivee = releve.point;
    final depart = _positionAffichee;

    _glissement?.stop();

    if (depart == null) {
      _positionAffichee = arrivee;
      _appliquerLaCameraEtLItineraire(arrivee);
      _updateMapMarkers();
      return;
    }

    final distance = _geocodingService?.calculateDistance(depart, arrivee);
    final duree = distance == null
        ? Duration.zero
        : dureeDeGlissement(distance * 1000, cadence: _cadenceDuLivreur.emissionInterval);

    _capObserve = capDuSegment(depart, arrivee) ?? _capObserve;

    if (duree == Duration.zero) {
      _positionAffichee = arrivee;
      _appliquerLaCameraEtLItineraire(arrivee);
      _updateMapMarkers();
      return;
    }

    _glissementDepart = depart;
    _glissementArrivee = arrivee;

    final controleur = _glissement ??= AnimationController(vsync: this)
      ..addListener(_surAvancementDuGlissement);
    controleur.duration = duree;
    controleur.forward(from: 0);

    // La caméra et l'itinéraire visent la position **relevée**, pas
    // l'intermédiaire : les recalculer à chaque image du glissement ferait
    // soixante appels par seconde.
    _appliquerLaCameraEtLItineraire(arrivee);
  }

  void _surAvancementDuGlissement() {
    final depart = _glissementDepart;
    final arrivee = _glissementArrivee;
    final controleur = _glissement;
    if (!mounted || depart == null || arrivee == null || controleur == null) {
      return;
    }

    _positionAffichee = pointIntermediaire(depart, arrivee, controleur.value);
    _updateMapMarkers();
  }

  /// Recadre la carte et redemande l'itinéraire — au plus quand il le faut.
  void _appliquerLaCameraEtLItineraire(LatLng positionLivreur) {
    if (_mapController == null) return;

    final destination = _deliveryLatLng;
    if (destination == null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(positionLivreur));
      return;
    }

    _fitBounds(positionLivreur, destination);
    if (_itineraireMeriteUnRecalcul(positionLivreur)) {
      unawaited(_getDirections(positionLivreur, destination));
    }
  }

  /// Le tracé affiché est-il devenu faux au point de valoir un appel Google ?
  ///
  /// Deux raisons, dont une seule suffit : le livreur s'est écarté de l'origine
  /// du tracé actuel, ou ce tracé a vieilli — le trafic n'est plus celui sur
  /// lequel la durée a été calculée. En dehors de ces deux cas, redemander
  /// rendrait la même route pour le prix d'une requête.
  bool _itineraireMeriteUnRecalcul(LatLng origine) {
    final precedente = _origineDuDernierItineraire;
    final heure = _heureDuDernierItineraire;
    if (precedente == null || heure == null) return true;

    if (DateTime.now().difference(heure) >= _itinerairePerimeApres) return true;

    final ecartKm = _geocodingService?.calculateDistance(precedente, origine);
    if (ecartKm == null) return false;
    return ecartKm * 1000 >= _itineraireSiEcartDeMetres;
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    if (_directionsService == null) return;

    // Marqué **avant** l'appel, et non après : deux relevés rapprochés
    // lanceraient sinon deux requêtes concurrentes, chacune ignorant que
    // l'autre est en vol.
    _origineDuDernierItineraire = origin;
    _heureDuDernierItineraire = DateTime.now();

    try {
      final routeInfo = await _directionsService!.getRoute(
        origin: origin,
        destination: destination,
      );

      if (routeInfo != null && mounted) {
        setState(() {
          // Préserver le polyline d'historique s'il existe
          final historyPolyline = _polylines.firstWhere(
            (p) => p.polylineId.value == 'history',
            orElse: () => const Polyline(
              polylineId: PolylineId('none'),
            ),
          );

          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              // Le socle rend le tracé en `GeoPoint`, sans dépendance à la
              // cartographie ; la carte le veut en `LatLng`.
              points: routeInfo.polylinePoints.enLatLng,
              color: Theme.of(context).colorScheme.primary,
              width: 5,
            ),
          };

          // Réajouter le polyline d'historique s'il existait
          if (historyPolyline.polylineId.value != 'none') {
            _polylines.add(historyPolyline);
          }

          // Update estimated time with traffic info if available
          if (routeInfo.durationInTrafficMinutes != null) {
            _estimatedDeliveryTime =
                '${routeInfo.durationInTrafficMinutes} min';
          }
        });
      }
    } catch (e) {
      eccore.Journal.trace('⚠️ Error getting directions: $e');
      // L'échec ne se garde pas : un quota momentané ou une coupure ne doivent
      // pas interdire la prochaine tentative pendant trois minutes.
      _origineDuDernierItineraire = null;
      _heureDuDernierItineraire = null;
    }
  }

  void _fitBounds(LatLng p1, LatLng p2) {
    LatLngBounds bounds;
    if (p1.latitude > p2.latitude && p1.longitude > p2.longitude) {
      bounds = LatLngBounds(southwest: p2, northeast: p1);
    } else if (p1.longitude > p2.longitude) {
      bounds = LatLngBounds(
        southwest: LatLng(p1.latitude, p2.longitude),
        northeast: LatLng(p2.latitude, p1.longitude),
      );
    } else if (p1.latitude > p2.latitude) {
      bounds = LatLngBounds(
        southwest: LatLng(p2.latitude, p1.longitude),
        northeast: LatLng(p1.latitude, p2.longitude),
      );
    } else {
      bounds = LatLngBounds(southwest: p1, northeast: p2);
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  void _initializeStatusTimestamps() {
    if (_order == null) return;

    // Ajouter le statut actuel avec l'horodatage actuel
    _statusTimestamps[_order!.status] = DateTime.now();

    // Ajouter les timestamps depuis les données de la commande
    _statusTimestamps[OrderStatus.pending] = _order!.createdAt;
  }

  /// Met à jour le polyline de l'historique des positions
  void _updateLocationHistoryPolyline() {
    if (_locationHistory.length < 2) return;

    final points = _locationHistory.reversed.map((loc) => loc.point).toList();

    if (mounted) {
      setState(() {
        // Supprimer l'ancien polyline d'historique s'il existe
        _polylines.removeWhere((poly) => poly.polylineId.value == 'history');

        // Ajouter le nouveau polyline d'historique
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('history'),
            points: points,
            // Le doré de la palette, non le bleu de Material : le tracé se
            // pose sur une carte routière déjà bleue, où il disparaissait.
            color: AppColors.secondary.withValues(alpha: 0.7),
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      });
    }
  }

  /// Vérifie si le livreur est proche et envoie une alerte
  void _checkProximity() {
    if (_deliveryLocation == null ||
        _deliveryLatLng == null ||
        _proximityAlertShown ||
        _geocodingService == null) {
      return;
    }

    final driverPos = _deliveryLocation!.point;

    final distance =
        _geocodingService!.calculateDistance(driverPos, _deliveryLatLng!);

    if (livreurToutProche(distance) && !_proximityAlertShown) {
      _proximityAlertShown = true;
      if (mounted) {
        context.showSuccessMessage('Votre livreur arrive — il est tout près.');
      }
    }
  }

  /// Calcule les statistiques de livraison (vitesse moyenne, distance parcourue)
  void _calculateDeliveryStats() {
    final geocodage = _geocodingService;
    if (geocodage == null) return;

    final mesure = statistiquesDuTrajet(
      _locationHistory,
      distanceEntre: geocodage.calculateDistance,
    );

    if (!mounted) return;

    setState(() {
      _totalDistance = mesure.distanceParcourue;
      // On ne remplace la vitesse affichée que par une vitesse mesurée :
      // faute de relevé plausible, la dernière connue vaut mieux qu'un zéro.
      if (mesure.vitesseMoyenne != null) {
        _averageSpeed = mesure.vitesseMoyenne!;
      }
    });
  }

  Future<void> _startTracking() async {
    try {
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        eccore.Journal.trace('⚠️ User not logged in, cannot start tracking');
        return;
      }

      // Initialiser le service de tracking en temps réel
      _trackingService = RealtimeTrackingService();

      if (!_trackingService!.isConnected) {
        await _trackingService!.initialize();
      }

      if (!mounted || !context.mounted) return;

      // Le canal n'est ouvert que si la commande est déjà diffusée ; sinon,
      // [_loadOrderDetails] s'en chargera dès qu'elle le sera. Les abonnements
      // ci-dessous, eux, sont posés tout de suite : ils écoutent le service,
      // pas le canal, et survivent à son ouverture différée.
      await _ouvrirSuiviSiDiffuse();

      // S'abonner aux mises à jour de la commande
      _orderUpdatesSubscription = _trackingService!.orderUpdates.listen(
        (updatedOrder) {
          if (updatedOrder.id == widget.orderId && mounted) {
            final previousStatus = _order?.status;
            setState(() {
              _order = updatedOrder;
            });

            // Enregistrer le timestamp du changement de statut
            if (updatedOrder.status != previousStatus) {
              _statusTimestamps[updatedOrder.status] = DateTime.now();
            }

            // Mettre à jour le profil du livreur si nouvellement assigné
            if (updatedOrder.deliveryPersonId != null &&
                (_driverProfile == null ||
                    _driverProfile!['auth_user_id'] !=
                        updatedOrder.deliveryPersonId)) {
              _loadTracking();
            }

            // Si la commande est livrée, arrêter le suivi
            if (updatedOrder.status == OrderStatus.delivered) {
              _estimatedTimeUpdateTimer?.cancel();
              _orderRefreshTimer?.cancel();
              // Le serveur ferme aussi de son côté : une commande livrée n'est
              // plus diffusée. Le dire ici évite de rouvrir un canal refusé.
              _suiviTempsReelOuvert = false;
              unawaited(_trackingService?.untrackOrder(widget.orderId) ??
                  Future<void>.value(),);
            }
          }
        },
        onError: (error) {
          eccore.Journal.trace('❌ Error in order updates stream: $error');
          _attemptReconnect();
        },
        onDone: () {
          eccore.Journal.trace('⚠️ Order updates stream closed, attempting reconnect');
          _attemptReconnect();
        },
      );

      // S'abonner aux mises à jour de position du livreur
      _deliveryLocationSubscription =
          _trackingService!.deliveryLocationUpdates.listen(
        (newLocation) {
          // Filtrer pour cette commande uniquement
          if (newLocation.commandeId == widget.orderId && mounted) {
            setState(() {
              // Ajouter à l'historique
              _locationHistory.insert(0, newLocation);
              // Garder seulement les 100 dernières positions
              if (_locationHistory.length > 100) {
                _locationHistory = _locationHistory.take(100).toList();
              }
              _deliveryLocation = newLocation;
            });

            // Recalculer le temps estimé
            _calculateEstimatedDeliveryTime();
            // Glissement plutôt que repose : voir [_deplacerLeRepereDuLivreur].
            // C'est lui qui rafraîchit les repères, recadre et décide s'il faut
            // redemander l'itinéraire — `_updateMapMarkers` seul le faisait
            // pour un appel Google par relevé.
            _deplacerLeRepereDuLivreur(newLocation);
            _updateLocationHistoryPolyline();

            // Vérifier la proximité et calculer les statistiques
            _checkProximity();
            _calculateDeliveryStats();
          }
        },
        onError: (error) {
          eccore.Journal.trace('❌ Error in delivery location stream: $error');
          // Tenter une reconnexion automatique
          _attemptReconnect();
        },
        onDone: () {
          eccore.Journal.trace(
            '⚠️ Delivery location stream closed, attempting reconnect',
          );
          _attemptReconnect();
        },
      );

      // Mettre à jour le temps estimé périodiquement
      _estimatedTimeUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _calculateEstimatedDeliveryTime(),
      );

      // Filet de sécurité : relire la commande périodiquement, pour que
      // l'écran reste juste même si le temps réel ne passe pas.
      _programmerRelectureDeLaCommande();

      eccore.Journal.trace('✅ Started real-time tracking for order: ${widget.orderId}');
    } catch (e) {
      eccore.Journal.trace('❌ Error starting tracking: $e');
    }
  }

  /// (Re)programme la relecture périodique de la commande, à la cadence que
  /// justifie l'état du canal temps réel.
  ///
  /// ## Pourquoi la cadence n'est pas fixe
  ///
  /// Elle était de dix secondes, quoi qu'il arrive : six `GET /orders/{id}/`
  /// par minute et par client, sur l'écran qu'on laisse ouvert le plus
  /// longtemps de toute l'application — et ce **pendant** que le WebSocket
  /// livrait déjà les mêmes changements. Le filet doublait en permanence la
  /// source qu'il n'est là que pour suppléer.
  ///
  /// Canal ouvert, la relecture ne rattrape qu'un message perdu : une minute
  /// suffit. Canal fermé, elle est la seule source : dix secondes.
  ///
  /// La cadence d'un `Timer.periodic` ne se modifie pas — d'où le
  /// remplacement, appelé à chaque bascule de [_suiviTempsReelOuvert].
  void _programmerRelectureDeLaCommande() {
    final cadence = _suiviTempsReelOuvert
        ? const Duration(minutes: 1)
        : const Duration(seconds: 10);

    if (_cadenceDeRelecture == cadence && _orderRefreshTimer?.isActive == true) {
      return;
    }

    _cadenceDeRelecture = cadence;
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = Timer.periodic(cadence, (_) {
      if (mounted) _loadOrderDetails();
    });
  }

  /// Ouvre le canal temps réel, si et seulement si la commande est dans un
  /// statut que le serveur diffuse.
  ///
  /// Rien n'est tenté autrement : la poignée de main serait refusée, et un
  /// refus ne se corrige pas en le répétant. L'écran vit alors du
  /// rafraîchissement périodique, qui constatera le passage à `confirmed` et
  /// rappellera cette méthode.
  Future<bool> _ouvrirSuiviSiDiffuse() async {
    if (_suiviTempsReelOuvert) return true;

    final statut = _order?.status;
    if (statut == null || !_statutsDiffuses.contains(statut)) return false;

    final service = _trackingService ??= RealtimeTrackingService();
    await service.trackOrder(widget.orderId);
    _suiviTempsReelOuvert = true;
    // Le canal reprend la charge : la relecture périodique s'espace.
    _programmerRelectureDeLaCommande();
    eccore.Journal.trace('✅ Suivi temps réel ouvert pour ${widget.orderId}');
    return true;
  }

  /// Tente une reconnexion automatique en cas de perte de connexion
  Future<void> _attemptReconnect() async {
    if (_isReconnecting || !mounted) return;

    setState(() {
      _isReconnecting = true;
    });

    // Attendre un peu avant de reconnecter
    await Future.delayed(const Duration(seconds: 3));

    try {
      if (!mounted || !context.mounted) return;
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        setState(() => _isReconnecting = false);
        return;
      }

      // Réinitialiser le service
      if (_trackingService != null && !_trackingService!.isConnected) {
        await _trackingService!.initialize();
      }

      // Le canal est refait à neuf, et seulement s'il a lieu d'être : sur une
      // commande que le serveur ne diffuse pas, il n'y a rien à rétablir.
      _suiviTempsReelOuvert = false;
      // Le canal est tombé : la relecture redevient la seule source, et
      // reprend donc sa cadence courte le temps de la reconnexion.
      _programmerRelectureDeLaCommande();
      final rouvert = await _ouvrirSuiviSiDiffuse();

      if (mounted) {
        setState(() => _isReconnecting = false);
        // L'annonce ne portait sur rien : elle s'affichait même quand aucune
        // connexion n'avait été rétablie. Elle ne parle plus que d'un canal
        // réellement rouvert.
        if (rouvert) {
          context.showSuccessMessage('Suivi temps réel rétabli');
        }
      }
    } catch (e) {
      eccore.Journal.trace('❌ Erreur lors de la reconnexion: $e');
      if (mounted) {
        setState(() => _isReconnecting = false);
        // Réessayer après un délai plus long
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) _attemptReconnect();
        });
      }
    }
  }

  Future<void> _calculateEstimatedDeliveryTime() async {
    if (_order == null ||
        _deliveryLocation == null ||
        _geocodingService == null ||
        _order!.status != OrderStatus.onTheWay) {
      return;
    }

    try {
      // Géocoder l'adresse de livraison
      final deliveryCoords =
          await _geocodingService!.geocodeAddress(_order!.deliveryAddress);

      if (deliveryCoords == null) {
        eccore.Journal.trace('⚠️ Could not geocode delivery address');
        return;
      }

      // Coordonnées du livreur
      final driverCoords = _deliveryLocation!.point;

      // Calculer le temps de trajet estimé
      final travelTime = await _geocodingService!
          .calculateTravelTime(driverCoords, deliveryCoords);

      if (travelTime != null && mounted) {
        setState(() {
          _estimatedDeliveryTime = '$travelTime min';
        });
      } else {
        // Fallback: calculer la distance et estimer
        final distanceKm =
            _geocodingService!.calculateDistance(driverCoords, deliveryCoords);
        final estimatedMinutes = minutesEstimeesPourKm(distanceKm);

        if (mounted) {
          setState(() {
            _estimatedDeliveryTime = '$estimatedMinutes min';
          });
        }
      }
    } catch (e) {
      eccore.Journal.trace('❌ Error calculating estimated delivery time: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de passer l\'appel vers $phoneNumber'),
          ),
        );
      }
    }
  }

  void _openChat() {
    if (_order?.deliveryPersonId == null) {
      context.showErrorMessage(
        'La conversation s’ouvrira dès qu’un livreur aura pris votre commande.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          orderId: widget.orderId,
          driverId: _order?.deliveryPersonId,
          driverName: _driverProfile?['name'] ?? 'Livreur',
        ),
      ),
    );
  }

  Future<void> _startVoiceCall() async {
    if (_order?.deliveryPersonId == null) {
      context.showErrorMessage('Aucun livreur n’est encore affecté.');
      return;
    }

    final appService = Provider.of<AppService>(context, listen: false);
    final currentUser = appService.currentUser;

    if (currentUser == null) {
      context.showErrorMessage('Connectez-vous pour passer un appel.');
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          orderId: widget.orderId,
          callerName: currentUser.fullName,
          receiverName: _driverProfile?['name'] ?? 'Livreur',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: const GlassAppBar(title: 'Suivi de livraison'),
        body: const etats.PageLoadingWidget(
          message: 'Localisation de votre commande…',
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: const GlassAppBar(title: 'Suivi de livraison'),
        body: etats.ErrorWidget(
          message: _errorMessage!,
          onRetry: _loadOrderDetails,
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapWidget(fullScreen: true)),
          _barreFlottante(theme),
          _feuilleDeSuivi(theme),
        ],
      ),
    );
  }

  /// Le bandeau posé sur la carte : retour, statut, arrivée estimée.
  ///
  /// `GlassAppBar` ne convient pas ici — elle occupe toute la largeur et
  /// masquerait la carte que le client vient précisément regarder. C'est le
  /// même verre dépoli, mais en pastilles flottantes, comme la maquette
  /// `delivery_tracking` les dessine.
  Widget _barreFlottante(ThemeData theme) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + DesignConstants.spacingS,
      left: DesignConstants.spacingM,
      right: DesignConstants.spacingM,
      child: Row(
        children: [
          _PastilleDeCarte(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: theme.colorScheme.onSurface,
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: _PastilleDeCarte(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignConstants.spacingM,
                vertical: DesignConstants.spacingS,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.two_wheeler_rounded,
                    color: theme.colorScheme.primary,
                    size: DesignConstants.iconSizeMedium,
                  ),
                  const SizedBox(width: DesignConstants.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _order!.status.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLg(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_estimatedDeliveryTime != null)
                          Text(
                            'Arrivée estimée $_estimatedDeliveryTime',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feuilleDeSuivi(ThemeData theme) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignConstants.radiusXLarge),
            ),
            boxShadow: DesignConstants.shadowHigh,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              0,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: DesignConstants.spacingM,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _carteDuLivreur(theme),
              const SizedBox(height: DesignConstants.spacingM),
              _actions(theme),
              if (_order!.status == OrderStatus.onTheWay &&
                  _totalDistance > 0) ...[
                const SizedBox(height: DesignConstants.spacingL),
                _statistiques(theme),
              ],
              const SizedBox(height: DesignConstants.spacingL),
              _chronologie(theme),
              const SizedBox(height: DesignConstants.spacingL),
              _adresse(theme),
              const SizedBox(height: DesignConstants.spacingL),
              _detailCommande(theme),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------- le livreur

  Widget _carteDuLivreur(ThemeData theme) {
    if (_driverProfile == null) {
      return SectionCard(
        color: theme.colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            Container(
              width: DesignConstants.avatarSizeMedium,
              height: DesignConstants.avatarSizeMedium,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: DesignConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recherche d’un livreur…',
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DesignConstants.spacingS),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      DesignConstants.radiusSmall,
                    ),
                    child: const LinearProgressIndicator(minHeight: 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final vehicule = _driverProfile!['vehicle_type']?.toString();
    final plaque = _driverProfile!['vehicle_plate']?.toString();

    return SectionCard(
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: DesignConstants.avatarSizeLarge,
              height: DesignConstants.avatarSizeLarge,
              child: FoodImage(
                url: _driverProfile!['profile_image']?.toString(),
                icon: Icons.person_rounded,
                iconSize: 32,
              ),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverProfile!['name']?.toString() ?? 'Votre livreur',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Wrap(
                  spacing: DesignConstants.spacingS,
                  runSpacing: DesignConstants.spacingXS,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Un livreur sans note est **nouveau**, pas mal noté :
                    // afficher « 0,0 ★ » le condamnerait sur une absence de
                    // données.
                    if (_driverRating != null)
                      RatingBadge(
                        rating: _driverRating!,
                        count:
                            _driverRatingCount > 0 ? _driverRatingCount : null,
                      )
                    else
                      const StatusChip(
                        label: 'Nouveau',
                        icon: Icons.auto_awesome_rounded,
                      ),
                    // Véhicule et plaque ne sont montrés que si le suivi les
                    // porte : la maquette dessine « Yamaha NMAX • ABJ-742 »,
                    // le serveur ne les renseigne pas toujours.
                    if (vehicule != null && vehicule.isNotEmpty)
                      StatusChip(
                        label: plaque != null && plaque.isNotEmpty
                            ? '$vehicule • $plaque'
                            : vehicule,
                        icon: Icons.two_wheeler_rounded,
                        background: theme.colorScheme.surfaceContainerHigh,
                        foreground: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- actions

  Widget _actions(ThemeData theme) {
    final avecLivreur = _order?.deliveryPersonId != null;

    return Row(
      children: [
        Expanded(
          child: ActionButton(
            label: 'Message',
            emphasis: ActionEmphasis.outlined,
            icon: Icons.chat_bubble_outline_rounded,
            height: 48,
            // Désactivés tant qu'aucun livreur n'est affecté : il n'y a
            // personne à joindre, et un bouton actif qui répond « aucun
            // livreur assigné » fait porter au client l'erreur de l'écran.
            onPressed: avecLivreur ? _openChat : null,
          ),
        ),
        const SizedBox(width: DesignConstants.gutter),
        Expanded(
          child: ActionButton(
            label: 'Appeler',
            emphasis: ActionEmphasis.outlined,
            icon: Icons.phone_outlined,
            height: 48,
            onPressed: avecLivreur ? _startVoiceCall : null,
          ),
        ),
        const SizedBox(width: DesignConstants.gutter),
        Expanded(
          child: ActionButton(
            label: 'Aide',
            emphasis: ActionEmphasis.outlined,
            icon: Icons.support_agent_rounded,
            height: 48,
            // Le support écrit, adossé aux tickets, plutôt qu'un numéro
            // inventé : les deux qui figuraient ici étaient ivoiriens et
            // aboutissaient chez un inconnu (voir `AppConstants.supportPhone`).
            onPressed: _ouvrirLeSupport,
          ),
        ),
      ],
    );
  }

  void _ouvrirLeSupport() {
    if (AppConstants.supportPhone.isEmpty) {
      Navigator.of(context).pushNamed(AppRouter.support);
      return;
    }
    _makePhoneCall(AppConstants.supportPhone);
  }

  // ----------------------------------------------------------- chronologie

  /// La chronologie, dans le même repliement à quatre jalons que le détail de
  /// commande — c'est ce que la maquette dessine (Prep · Picked Up · Nearby ·
  /// Delivered), et cela évite deux vues du même cycle qui divergent.
  Widget _chronologie(ThemeData theme) {
    final etapes = etapesDeSuivi(_order!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Progression'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            children: [
              for (var i = 0; i < etapes.length; i++)
                _jalon(theme, etapes[i], dernier: i == etapes.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _jalon(ThemeData theme, EtapeDeSuivi etape, {required bool dernier}) {
    final teinte = etape.annulation
        ? theme.colorScheme.error
        : etape.franchie
            ? AppColors.success
            : theme.colorScheme.outlineVariant;

    // L'heure vient du serveur (`status_events`) ; à défaut, de ce que cet
    // écran a lui-même observé pendant qu'il était ouvert.
    final horodatage =
        etape.horodatage ?? _statusTimestamps[_statutDuJalon(etape.jalon)];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: etape.franchie || etape.annulation
                      ? teinte
                      : theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  etape.annulation
                      ? Icons.close_rounded
                      : etape.franchie
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                  size: 14,
                  color: etape.franchie || etape.annulation
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!dernier)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: etape.franchie
                        ? teinte
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: dernier ? 0 : DesignConstants.spacingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          etape.annulation
                              ? libelleDeSortie(_order!.status)
                              : etape.jalon.libelle,
                          style: AppTypography.titleLg(
                            color: etape.franchie || etape.annulation
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (horodatage != null)
                        Text(
                          _formatTime(horodatage),
                          style: AppTypography.bodyMd(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (etape.courante && !etape.annulation) ...[
                    const SizedBox(height: 2),
                    Text(
                      etape.jalon.description,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Le statut représentatif d'un jalon, pour retrouver une heure observée
  /// localement quand le serveur n'a pas publié l'événement.
  OrderStatus _statutDuJalon(JalonDeSuivi jalon) {
    switch (jalon) {
      case JalonDeSuivi.confirmee:
        return OrderStatus.confirmed;
      case JalonDeSuivi.enPreparation:
        return OrderStatus.preparing;
      case JalonDeSuivi.enRoute:
        return OrderStatus.onTheWay;
      case JalonDeSuivi.livree:
        return OrderStatus.delivered;
    }
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return 'À l’instant';
    if (difference.inMinutes < 60) return 'il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'il y a ${difference.inHours} h';

    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day}/${dateTime.month} à $h:$m';
  }

  // ------------------------------------------------------------- l'adresse

  Widget _adresse(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Adresse de livraison'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: theme.colorScheme.primary,
                size: DesignConstants.iconSizeMedium,
              ),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order!.deliveryAddress,
                      style: AppTypography.bodyLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if ((_order!.deliveryNotes ?? '').isNotEmpty) ...[
                      const SizedBox(height: DesignConstants.spacingXS),
                      Text(
                        _order!.deliveryNotes!,
                        style: AppTypography.bodyMd(
                          color: theme.colorScheme.onSurfaceVariant,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- détail commande

  Widget _detailCommande(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Votre commande'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            children: [
              for (final article in _order!.items)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: DesignConstants.spacingS,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${article.quantity}×',
                        style: AppTypography.labelLg(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: DesignConstants.spacingS),
                      Expanded(
                        child: Text(
                          article.name,
                          style: AppTypography.bodyLg(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(article.totalPrice),
                        style: AppTypography.bodyLg(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              const SummaryDivider(),
              SummaryRow(
                label: 'Sous-total',
                value: PriceFormatter.format(_order!.subtotal),
              ),
              SummaryRow(
                label: 'Livraison',
                value: PriceFormatter.format(_order!.deliveryFee),
              ),
              if (_order!.discount > 0)
                SummaryRow(
                  label: 'Remise',
                  value: '-${PriceFormatter.format(_order!.discount)}',
                  isDiscount: true,
                ),
              const SummaryDivider(),
              SummaryRow(
                label: 'Total',
                value: PriceFormatter.format(_order!.total),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ statistiques

  Widget _statistiques(ThemeData theme) {
    Widget mesure(IconData icone, String valeur, String libelle) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(DesignConstants.spacingM),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: DesignConstants.borderRadiusMedium,
          ),
          child: Column(
            children: [
              Icon(
                icone,
                color: theme.colorScheme.primary,
                size: DesignConstants.iconSizeMedium,
              ),
              const SizedBox(height: DesignConstants.spacingS),
              Text(
                valeur,
                style: AppTypography.titleLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                libelle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Course en cours'),
        const SizedBox(height: DesignConstants.spacingS),
        Row(
          children: [
            mesure(
              Icons.straighten_rounded,
              '${_totalDistance.toStringAsFixed(1)} km',
              'Parcourus',
            ),
            const SizedBox(width: DesignConstants.gutter),
            mesure(
              Icons.speed_rounded,
              // Un livreur à l'arrêt n'a pas une vitesse de zéro : il n'a pas
              // de vitesse mesurable. Le tiret le dit, « 0,0 km/h » ment.
              _averageSpeed > 0
                  ? '${_averageSpeed.toStringAsFixed(0)} km/h'
                  : '—',
              'Vitesse moyenne',
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- la carte

  Widget _buildMapWidget({bool fullScreen = false}) {
    // Un `Builder` pour capturer les erreurs de rendu de la carte.
    return Builder(
      builder: (context) {
        try {
          return GoogleMap(
            initialCameraPosition: CameraPosition(
              // Repli sur le restaurant : les coordonnées écrites ici
              // pointaient à 600 km de l'établissement, si bien qu'une
              // commande sans position connue ouvrait la carte sur une autre
              // ville, dans un autre pays.
              //
              // Le point du restaurant vient maintenant de la commande quand le
              // serveur le rend (`restaurant_location`) ; la constante ne sert
              // plus qu'au tout dernier repli, et désigne le premier
              // établissement — elle deviendra fausse au deuxième.
              target: _deliveryLocation?.point ??
                  _deliveryLatLng ??
                  _restaurantLatLng ??
                  const LatLng(
                    AppConstants.restaurantLatitude,
                    AppConstants.restaurantLongitude,
                  ),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateMapMarkers();
            },
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            trafficEnabled: true,
          );
        } catch (e) {
          eccore.Journal.trace('❌ Erreur lors du chargement de Google Maps: $e');
          return ColoredBox(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignConstants.spacingL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 48,
                    ),
                    const SizedBox(height: DesignConstants.spacingM),
                    Text(
                      'Carte indisponible. Le suivi textuel ci-dessous reste '
                      'à jour.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Une pastille de verre dépoli posée sur la carte.
///
/// Reprend le flou et l'opacité de `GlassAppBar`, mais en élément flottant :
/// une barre pleine largeur masquerait la carte que le client vient regarder.
class _PastilleDeCarte extends StatelessWidget {
  const _PastilleDeCarte({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rayon = BorderRadius.circular(DesignConstants.radiusXLarge);

    return ClipRRect(
      borderRadius: rayon,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppColors.glassBlur,
          sigmaY: AppColors.glassBlur,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: rayon,
            boxShadow: DesignConstants.shadowMedium,
          ),
          child: child,
        ),
      ),
    );
  }
}
