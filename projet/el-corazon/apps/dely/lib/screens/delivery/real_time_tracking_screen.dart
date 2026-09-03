import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/directions_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/widgets/loading_widget.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;
import 'package:elcora_dely/presentation/messages_erreur.dart';

class RealTimeTrackingScreen extends StatefulWidget {
  final Course order;

  const RealTimeTrackingScreen({
    required this.order, super.key,
  });

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _driverLocation;

  /// Les deux points de la course, lus sur l'affectation — voir [_course].
  late LatLng _restaurantLocation;
  late LatLng _customerLocation;

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
  /// recentrage de sa propre carte. Le bouton dit maintenant ce qu'il fait.
  bool _cameraSuitLeLivreur = true;
  bool _isUpdatingStatus = false;
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  String _estimatedTime = 'Calcul en cours...';
  double _estimatedDistance = 0.0;

  /// Le transport temps réel, seul détenteur du flux de position.
  ///
  /// ## Pourquoi cet écran n'ouvre plus le sien
  ///
  /// Il ouvrait un **second** `Geolocator.getPositionStream` en parallèle de
  /// celui du service, uniquement pour bouger un repère sur sa carte. Deux flux
  /// haute précision sur le même appareil, c'est deux fois la dépense du poste
  /// le plus lourd d'un téléphone, pour une donnée que le premier avait déjà et
  /// publie (`currentPosition`, avec notification). Le second n'apportait qu'une
  /// occasion de diverger : ses réglages n'étaient pas ceux du suivi — filtre à
  /// 10 m au lieu du réglage partagé, aucune déclaration d'arrière-plan — et il
  /// s'arrêtait à la fermeture de l'écran alors que le vrai suivi continuait.
  final RealtimeTrackingService _tracking = RealtimeTrackingService();

  final DirectionsService _directionsService = DirectionsService();
  
  // Dernière position pour éviter trop de recalculs
  LatLng? _lastCalculatedPosition;
  DateTime? _lastCalculationTime;

  @override
  void initState() {
    super.initState();
    _course = widget.order;
    _restaurantLocation =
        LatLng(_course.latitudeRetrait, _course.longitudeRetrait);
    _customerLocation =
        LatLng(_course.latitudeLivraison, _course.longitudeLivraison);
    _initializeTracking();
  }

  /// Où le livreur doit se rendre **en ce moment** : le restaurant tant qu'il
  /// n'a pas le repas, le client ensuite.
  ///
  /// L'écran visait le client dès l'ouverture, quelle que soit l'étape. Un
  /// livreur qui venait d'accepter voyait donc un itinéraire vers une adresse
  /// où il n'avait rien à faire, et une durée estimée qui ne comptait pas le
  /// passage au restaurant.
  LatLng get _destination =>
      _course.repasRecupere ? _customerLocation : _restaurantLocation;

  String get _destinationLibelle =>
      _course.repasRecupere ? 'Client' : 'Restaurant';

  @override
  void dispose() {
    _tracking.removeListener(_surNouvellePosition);
    super.dispose();
  }

  /// Prend la position que le service tient déjà, et suit ses mises à jour.
  ///
  /// L'écran relevait lui-même un premier point puis ouvrait son propre flux.
  /// Les deux gestes doublaient ce que `RealtimeTrackingService` fait pour la
  /// course entière, avec deux conséquences : la dépense d'un second capteur
  /// haute précision, et une carte qui pouvait afficher une position pendant
  /// que le vrai suivi était en panne — le livreur se croyait suivi.
  Future<void> _initializeTracking() async {
    if (!mounted) return;

    _tracking.addListener(_surNouvellePosition);

    final connue = _tracking.currentPosition;
    if (connue != null) {
      _driverLocation = LatLng(connue.latitude, connue.longitude);
    }

    // Les deux points de la course sont déjà connus (voir `initState`) : ils
    // viennent de l'affectation, que le serveur rend avec `pickup_location` et
    // `delivery_location`, tous deux obligatoires.
    //
    // Cet écran géocodait à la place la **chaîne** d'adresse de livraison, et
    // retombait, quand le géocodage échouait, sur `LatLng(5.3599, -4.0083)` —
    // Abidjan, sous un commentaire annonçant Lomé. Le restaurant, lui, était un
    // point écrit en dur, le même pour tous les établissements. Un livreur
    // pouvait donc être guidé vers un autre pays sans qu'aucune erreur ne
    // s'affiche.
    _updateMarkers();
    if (_driverLocation != null) await _calculateRoute();

    if (mounted) setState(() => _isLoading = false);
  }

  /// Une position vient d'arriver — ou le suivi vient de s'interrompre.
  ///
  /// Le service notifie aussi quand il **cesse** de suivre : la position
  /// redevient nulle, et le repère doit alors rester là où il était plutôt que
  /// de disparaître. C'est la dernière position connue, et le bandeau au-dessus
  /// de la carte dit qu'elle ne bouge plus.
  void _surNouvellePosition() {
    if (!mounted) return;

    final position = _tracking.currentPosition;
    if (position == null) {
      // Rafraîchit le bandeau d'obstacle sans toucher au repère.
      setState(() {});
      return;
    }

    _driverLocation = LatLng(position.latitude, position.longitude);
    _updateMarkers();

    if (_cameraSuitLeLivreur) {
      unawaited(
        _mapController
                ?.animateCamera(CameraUpdate.newLatLng(_driverLocation!))
                .catchError((Object e) => Journal.trace('Camera: $e')) ??
            Future<void>.value(),
      );
    }

    unawaited(_calculateRoute());
    setState(() {});
  }

  Future<void> _calculateRoute() async {
    if (_driverLocation == null || !mounted) {
      return;
    }

    // Éviter trop de recalculs (throttling)
    if (_lastCalculatedPosition != null && _lastCalculationTime != null) {
      final distanceSinceLastCalc = _calculateDistance(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _lastCalculatedPosition!.latitude,
        _lastCalculatedPosition!.longitude,
      );
      
      final timeSinceLastCalc = DateTime.now().difference(_lastCalculationTime!);
      
      // Ne recalculer que si déplacé de plus de 100m ou après 30 secondes
      if (distanceSinceLastCalc < 0.1 && timeSinceLastCalc.inSeconds < 30) {
        return;
      }
    }

    if (_isCalculatingRoute) return;

    setState(() => _isCalculatingRoute = true);

    try {
      // Utiliser Google Directions API pour obtenir la vraie route
      final routeInfo = await _directionsService.getRoute(
        origin: _driverLocation!,
        destination: _destination,
      );

      if (routeInfo != null && mounted) {
        // Mettre à jour les informations
        setState(() {
          _estimatedDistance = routeInfo.distanceKm;
          _estimatedTime = routeInfo.formattedDuration;
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });

        // Mettre à jour le polyline avec la vraie route
        // Le socle rend le tracé en `GeoPoint`, sans dépendance à la
        // cartographie ; la carte le veut en `LatLng`.
        await _updateRoutePolyline(routeInfo.polylinePoints.enLatLng);
      } else {
        // Fallback: utiliser le calcul Haversine si l'API échoue
        _calculateRouteFallback();
      }
    } catch (e) {
      Journal.trace('❌ Erreur calcul route avec Directions API: $e');
      
      // Fallback: utiliser le calcul Haversine
      _calculateRouteFallback();
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  /// Calcul de route en fallback (Haversine) si l'API échoue
  void _calculateRouteFallback() {
    try {
      double distance = 0.0;
      if (_driverLocation != null) {
        distance = _calculateDistance(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          _destination.latitude,
          _destination.longitude,
        );
      }

      // Estimation basée sur la distance (vitesse moyenne: 30 km/h en ville)
      // Ajouter 5 minutes pour le ramassage
      const averageSpeedKmh = 30.0;
      const minutesPerKm = 60.0 / averageSpeedKmh;
      final estimatedMinutes = (distance * minutesPerKm).round() + 5;
      final duration = Duration(minutes: estimatedMinutes.clamp(5, 60));

      if (mounted) {
        setState(() {
          _estimatedDistance = distance;
          _estimatedTime = _formatDuration(duration);
          _lastCalculatedPosition = _driverLocation;
          _lastCalculationTime = DateTime.now();
        });
      }

      // Créer un polyline simple (ligne droite)
      _updateRoutePolyline([_driverLocation!, _destination]);
    } catch (e) {
      Journal.trace('❌ Erreur calcul route fallback: $e');
    }
  }

  /// Met à jour le polyline de la route sur la carte
  Future<void> _updateRoutePolyline(List<LatLng> points) async {
    if (!mounted || points.isEmpty) return;

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    // Ajuster la caméra pour afficher toute la route
    if (_mapController != null && points.length > 1) {
      try {
        final bounds = _calculateBounds(points);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      } catch (e) {
        Journal.trace('Erreur ajustement caméra: $e');
      }
    }
  }

  /// Calcule les limites (bounds) d'une liste de points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _updateMarkers() {
    if (!mounted) return;

    setState(() {
      _markers = {
        if (_driverLocation != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(
              title: 'Votre position',
              snippet: 'Livreur',
            ),
          ),
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLocation,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title:
                _course.destinataire.isEmpty ? 'Client' : _course.destinataire,
            snippet: _course.adresseLivraison,
          ),
        ),
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: _course.assignment.restaurantName,
            snippet: 'Point de retrait',
          ),
        ),
      };
    });
  }

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  /// Fait franchir une étape à la course, puis relit ce que le serveur a
  /// réellement enregistré.
  ///
  /// L'écran fermait auparavant dès l'appel parti, quelle que soit l'étape :
  /// le livreur en déduisait que c'était fait, alors que la réponse pouvait
  /// encore refuser. Il ne se ferme plus que sur une course terminée, et
  /// l'affichage — étape, destination, boutons — suit la course rendue.
  Future<void> _updateOrderStatus(EtapeCourse etape) async {
    if (_isUpdatingStatus) return;

    if (etape == EtapeCourse.livree && !await _confirmerLivraison()) return;
    if (!mounted) return;

    setState(() => _isUpdatingStatus = true);
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.updateOrderStatus(_course.orderId, etape);

      // La course rendue par le serveur porte la nouvelle étape **et** les
      // transitions désormais permises : c'est elle qui décide de la suite.
      final rafraichie = appService.courseForOrder(_course.orderId);

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
      if (_course.prochaineEtape == null) {
        Navigator.pop(context);
      } else {
        // La destination vient peut-être de changer (restaurant -> client) :
        // sans cette remise à zéro, l'étranglement anti-recalcul garderait le
        // tracé vers le restaurant pendant trente secondes après que le
        // livreur a déclaré avoir récupéré la commande.
        _lastCalculatedPosition = null;
        _lastCalculationTime = null;
        _updateMarkers();
        await _calculateRoute();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageErreur(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Demande confirmation avant de déclarer la livraison faite.
  ///
  /// L'étape est **irréversible** : la machine à états du serveur est
  /// acyclique, une course livrée ne se rouvre pas, et c'est elle qui crédite
  /// la rémunération et incrémente les compteurs. Un appui malheureux sur un
  /// téléphone posé sur un guidon ne doit pas la déclencher.
  ///
  /// Il n'y a **pas** de preuve de livraison à demander ici : le contrat
  /// n'expose ni code, ni photo, ni signature — `Assignment.proof_of_delivery`
  /// existe en base mais aucun sérialiseur ni aucune vue ne le rend
  /// accessible. En fabriquer une côté application donnerait une garantie que
  /// rien ne vérifie.
  Future<bool> _confirmerLivraison() async {
    final montant = _course.moyenPaiement.aEncaisser
        ? _course.total?.format()
        : null;

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

  /// Voyant d'état du suivi, et ce qui le bloque le cas échéant.
  ///
  /// L'obstacle vient du service : c'est lui qui a essayé d'ouvrir le flux et
  /// qui sait pourquoi il n'y est pas arrivé. L'afficher ici est le seul moyen
  /// pour le livreur d'apprendre qu'il n'est pas suivi autrement que par le
  /// reproche d'un client.
  Widget _voyantDeSuivi() {
    final obstacle = _tracking.trackingUnavailableReason;
    final actif = _tracking.isTrackingLocation && obstacle == null;
    final couleur = actif
        ? Colors.green
        : (obstacle == null ? Colors.grey : Colors.orange);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                actif ? 'Suivi actif' : 'Suivi interrompu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: couleur,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (obstacle != null) ...[
          const SizedBox(height: 4),
          Text(
            obstacle,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi — ${_course.reference}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(
              () => _cameraSuitLeLivreur = !_cameraSuitLeLivreur,
            ),
            icon: Icon(
              _cameraSuitLeLivreur
                  ? Icons.my_location
                  : Icons.location_searching,
            ),
            tooltip: _cameraSuitLeLivreur
                ? 'La carte suit votre position'
                : 'Recentrer sur votre position',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Initialisation du suivi...')
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      // Jamais un point écrit en dur : à défaut de position
                      // du livreur, la carte s'ouvre sur là où il doit aller.
                      target: _driverLocation ?? _destination,
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _updateMarkers();
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                  ),
                ),

                // Status and controls
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // État **réel** du suivi, lu sur le service qui
                        // l'assure. Ce voyant reflétait jusqu'ici l'ouverture
                        // du flux de cet écran : il passait au vert dès que la
                        // carte s'affichait, y compris quand le suivi
                        // n'émettait rien vers le serveur — GPS coupé,
                        // permission refusée. Le livreur lisait « suivi actif »
                        // pendant que le client voyait un point immobile.
                        _voyantDeSuivi(),
                        const SizedBox(height: 16),

                        // ETA and distance
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Temps estimé',
                                _isCalculatingRoute ? 'Calcul...' : _estimatedTime,
                                Icons.access_time,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                'Distance',
                                _isCalculatingRoute 
                                    ? 'Calcul...' 
                                    : '${_estimatedDistance.toStringAsFixed(1)} km',
                                Icons.straighten,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Order status
                        Text(
                          'Étape : ${_course.etape.libelle}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Direction : $_destinationLibelle',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),

                        _buildActionSuivante(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
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
  /// rien à franchir.
  Widget _buildActionSuivante() {
    final suivante = _course.prochaineEtape;

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
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  /// Le geste, pas l'état : le bouton dit ce que le livreur fait, l'étiquette
  /// d'étape au-dessus dit où il en est.
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

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
