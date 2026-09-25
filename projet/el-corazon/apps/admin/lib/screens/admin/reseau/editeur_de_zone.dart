import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:admin/screens/admin/reseau/brouillon_de_zone.dart';

/// L'éditeur cartographique d'une zone : un cercle ou un polygone.
///
/// ## Ce qu'il remplace
///
/// La saisie d'une zone se faisait en deux champs — centre et rayon en
/// kilomètres. Un quartier ne se décrit pas par un disque : il suit une route,
/// une lagune, une limite de commune. Le serveur acceptait déjà un polygone ;
/// aucun écran ne permettait d'en dessiner un.
///
/// ## Les gestes
///
/// * **Cercle** — toucher la carte place le centre (ou glisser son repère), le
///   curseur règle le rayon.
/// * **Polygone** — chaque toucher ajoute un sommet ; un sommet se déplace en le
///   glissant, et se retire en touchant sa bulle. « Annuler » retire le dernier.
///
/// Les autres zones de la cuisine sont dessinées en gris : c'est ce qui permet
/// de voir un chevauchement avant de l'enregistrer.
///
/// L'écran rend la forme dessinée, ou `null` si on l'abandonne. Il n'envoie
/// rien lui-même : c'est la fiche de zone qui enregistre, et qui affiche le
/// refus du serveur s'il y en a un.
class EditeurDeZone extends StatefulWidget {
  const EditeurDeZone({
    required this.cadrage,
    this.brouillon,
    this.voisines = const [],
    this.titre = 'Dessiner la zone',
    super.key,
  });

  /// Où ouvrir la carte quand rien n'est encore dessiné — la cuisine.
  final eccore.GeoPoint cadrage;

  /// La forme à rouvrir ; un polygone vide si `null`.
  final BrouillonDeZone? brouillon;

  /// Les autres zones de la cuisine, montrées pour repérer un chevauchement.
  final List<eccore.DeliveryZone> voisines;
  final String titre;

  static Future<eccore.FormeDeZone?> ouvrir(
    BuildContext context, {
    required eccore.GeoPoint cadrage,
    BrouillonDeZone? brouillon,
    List<eccore.DeliveryZone> voisines = const [],
  }) {
    return Navigator.of(context).push<eccore.FormeDeZone>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EditeurDeZone(cadrage: cadrage, brouillon: brouillon, voisines: voisines),
      ),
    );
  }

  @override
  State<EditeurDeZone> createState() => _EditeurDeZoneState();
}

class _EditeurDeZoneState extends State<EditeurDeZone> {
  late final BrouillonDeZone _brouillon = widget.brouillon ?? BrouillonDeZone.polygone();

  static LatLng _latLng(eccore.GeoPoint point) => LatLng(point.latitude, point.longitude);
  static eccore.GeoPoint _point(LatLng position) =>
      eccore.GeoPoint(position.latitude, position.longitude);

  eccore.GeoPoint get _depart {
    if (_brouillon.estCercle && _brouillon.centre != null) return _brouillon.centre!;
    if (_brouillon.sommets.isNotEmpty) return _brouillon.sommets.first;
    return widget.cadrage;
  }

  Set<Polygon> _polygones(ColorScheme couleurs) {
    return {
      for (final (index, voisine) in widget.voisines.indexed)
        if (voisine.sommets.length >= 3)
          Polygon(
            polygonId: PolygonId('voisine-$index'),
            points: voisine.sommets.map(_latLng).toList(),
            strokeWidth: 1,
            strokeColor: Colors.grey.shade600,
            fillColor: Colors.grey.withValues(alpha: 0.15),
          ),
      if (!_brouillon.estCercle && _brouillon.sommets.length >= 3)
        Polygon(
          polygonId: const PolygonId('trace'),
          points: _brouillon.sommets.map(_latLng).toList(),
          strokeWidth: 3,
          strokeColor: couleurs.primary,
          fillColor: couleurs.primary.withValues(alpha: 0.2),
        ),
    };
  }

  Set<Polyline> _lignes(ColorScheme couleurs) {
    // Deux sommets ne font pas encore une surface : on montre le trait, pour
    // que le deuxième toucher ne paraisse pas perdu.
    if (_brouillon.estCercle || _brouillon.sommets.length != 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('trace'),
        points: _brouillon.sommets.map(_latLng).toList(),
        color: couleurs.primary,
        width: 3,
      ),
    };
  }

  Set<Circle> _cercles(ColorScheme couleurs) {
    final centre = _brouillon.centre;
    if (!_brouillon.estCercle || centre == null) return const {};
    return {
      Circle(
        circleId: const CircleId('trace'),
        center: _latLng(centre),
        radius: _brouillon.rayonMetres.toDouble(),
        strokeWidth: 3,
        strokeColor: couleurs.primary,
        fillColor: couleurs.primary.withValues(alpha: 0.2),
      ),
    };
  }

  Set<Marker> _reperes() {
    if (_brouillon.estCercle) {
      final centre = _brouillon.centre;
      if (centre == null) return const {};
      return {
        Marker(
          markerId: const MarkerId('centre'),
          position: _latLng(centre),
          draggable: true,
          onDragEnd: (position) => setState(() => _brouillon.toucher(_point(position))),
          infoWindow: const InfoWindow(title: 'Centre de la zone'),
        ),
      };
    }
    return {
      for (final (index, sommet) in _brouillon.sommets.indexed)
        Marker(
          markerId: MarkerId('sommet-$index'),
          position: _latLng(sommet),
          draggable: true,
          onDragEnd: (position) =>
              setState(() => _brouillon.deplacerSommet(index, _point(position))),
          infoWindow: InfoWindow(
            title: 'Sommet ${index + 1}',
            snippet: 'Touchez ici pour le retirer',
            onTap: () => setState(() => _brouillon.retirerSommet(index)),
          ),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final manque = _brouillon.manque;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        actions: [
          IconButton(
            tooltip: 'Tout effacer',
            onPressed: () => setState(_brouillon.effacer),
            icon: const Icon(Icons.layers_clear_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.polyline_outlined), label: Text('Polygone')),
                ButtonSegment(value: true, icon: Icon(Icons.circle_outlined), label: Text('Cercle')),
              ],
              selected: {_brouillon.estCercle},
              onSelectionChanged: (choix) =>
                  setState(() => _brouillon.basculer(versCercle: choix.first)),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _latLng(_depart), zoom: 13),
              onTap: (position) => setState(() => _brouillon.toucher(_point(position))),
              polygons: _polygones(couleurs),
              polylines: _lignes(couleurs),
              circles: _cercles(couleurs),
              markers: _reperes(),
              myLocationButtonEnabled: false,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_brouillon.estCercle)
                    Row(
                      children: [
                        const Text('Rayon'),
                        Expanded(
                          child: Slider(
                            min: BrouillonDeZone.rayonMin.toDouble(),
                            max: BrouillonDeZone.rayonMax.toDouble(),
                            divisions: (BrouillonDeZone.rayonMax - BrouillonDeZone.rayonMin) ~/ 100,
                            value: _brouillon.rayonMetres.toDouble(),
                            label: _libelleRayon(_brouillon.rayonMetres),
                            onChanged: (valeur) =>
                                setState(() => _brouillon.changerRayon(valeur.round())),
                          ),
                        ),
                        Text(_libelleRayon(_brouillon.rayonMetres)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_brouillon.sommets.length} sommet'
                            '${_brouillon.sommets.length > 1 ? 's' : ''} — touchez la carte pour en ajouter',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _brouillon.sommets.isEmpty
                              ? null
                              : () => setState(_brouillon.annulerDernier),
                          icon: const Icon(Icons.undo),
                          label: const Text('Annuler'),
                        ),
                      ],
                    ),
                  if (manque != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(manque, style: TextStyle(color: couleurs.onSurfaceVariant)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Abandonner'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _brouillon.estEnregistrable
                              ? () => Navigator.of(context).pop(_brouillon.forme)
                              : null,
                          child: const Text('Valider la forme'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _libelleRayon(int metres) =>
      metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';
}
