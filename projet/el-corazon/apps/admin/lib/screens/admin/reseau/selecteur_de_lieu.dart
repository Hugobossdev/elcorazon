import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/lieu_service.dart';

/// Ce qu'un lieu choisi rapporte au formulaire qui l'a demandé.
///
/// Tout est facultatif sauf la position : au large ou en zone non adressée,
/// Google ne rend ni ville ni pays, et inventer une valeur serait pire que de
/// n'en rendre aucune. Le formulaire remplit alors ce qu'il peut et laisse
/// l'administrateur compléter.
class LieuChoisi {
  const LieuChoisi({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
    this.city,
    this.country,
    this.countryCode,
    this.district,
    this.placeId,
  });

  final double latitude;
  final double longitude;

  /// Nom du lieu, quand il vient d'une recherche Places. Nul quand la position
  /// a été posée à la main sur la carte : un point n'a pas de nom.
  final String? name;

  final String? address;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? district;
  final String? placeId;
}

/// **Poser un point sur une carte, plutôt que taper des coordonnées.**
///
/// ## Ce que cet écran remplace
///
/// Deux champs texte, « Latitude » et « Longitude ». Personne ne connaît par
/// cœur les coordonnées d'une adresse : on les copiait depuis un autre onglet,
/// avec une chance sur deux de les intervertir. Une longitude saisie en
/// latitude place un restaurant de Lomé au pôle — et cela ne se voit qu'à la
/// mise en service, quand le contrôle de complétude signale que la position
/// tombe hors de sa zone.
///
/// ## Trois façons de désigner un point, et pourquoi les trois
///
/// * **chercher un nom** — « El Corazón Plateau », « Boulevard du 13 Janvier ».
///   C'est le geste naturel, et il donne l'adresse et la ville en prime ;
/// * **toucher la carte** — pour un lieu qu'aucun service d'adressage ne nomme,
///   ce qui est fréquent hors des centres-villes ;
/// * **déplacer le marqueur** — pour ajuster de quelques mètres le point de
///   retrait à l'entrée de service plutôt qu'au milieu du bâtiment.
///
/// Les trois convergent vers la même chose : une position, puis un géocodage
/// inverse qui dit ce qu'il y a là.
///
/// ## Rien n'est écrasé sans validation
///
/// Ce que Google rend est une **proposition**, affichée dans un panneau que
/// l'administrateur lit avant de valider. L'écran ne renvoie rien tant qu'on
/// n'a pas appuyé sur « Utiliser ce lieu » : c'est ce qui rend sûr de bouger le
/// marqueur pour regarder, puis de revenir en arrière.
class SelecteurDeLieu extends StatefulWidget {
  const SelecteurDeLieu({
    required this.titre,
    this.positionInitiale,
    this.countryCode,
    super.key,
  });

  final String titre;

  /// Où ouvrir la carte. Le centre de la ville qu'on configure, ou la position
  /// actuelle de l'établissement qu'on corrige.
  ///
  /// Nul, la carte s'ouvre sur un cadrage large : mieux vaut un monde entier
  /// qu'un point au large du golfe de Guinée, qui est ce que donne (0, 0).
  final eccore.GeoPoint? positionInitiale;

  /// Borne la recherche au marché visé. **Jamais écrit en dur** : c'est le
  /// formulaire appelant qui le fournit, ce qui permet de chercher au Cameroun
  /// comme au Togo.
  final String? countryCode;

  /// Ouvre l'écran et rend le lieu retenu, ou `null` si l'on est revenu en
  /// arrière.
  static Future<LieuChoisi?> ouvrir(
    BuildContext context, {
    required String titre,
    eccore.GeoPoint? positionInitiale,
    String? countryCode,
  }) {
    return Navigator.of(context).push<LieuChoisi>(
      MaterialPageRoute<LieuChoisi>(
        builder: (_) => SelecteurDeLieu(
          titre: titre,
          positionInitiale: positionInitiale,
          countryCode: countryCode,
        ),
      ),
    );
  }

  @override
  State<SelecteurDeLieu> createState() => _SelecteurDeLieuState();
}

class _SelecteurDeLieuState extends State<SelecteurDeLieu> {
  final _recherche = TextEditingController();
  GoogleMapController? _carte;

  /// Position retenue. Nulle tant que rien n'a été posé — le bouton de
  /// validation est alors inerte, plutôt que d'enregistrer (0, 0).
  LatLng? _position;

  /// Ce que le serveur dit du point courant. Nul pendant la résolution, et
  /// après un échec — auquel cas la position reste, et les champs se
  /// remplissent à la main.
  eccore.ReverseGeocodeResult? _adresse;

  /// Nom du lieu, quand il vient d'une recherche. Effacé dès qu'on déplace le
  /// marqueur : le nom désignait *ce* point, pas celui d'à côté.
  String? _nom;
  String? _placeId;

  /// Anti-rebond de la saisie. Sans lui, chaque lettre part chez Google — et
  /// chaque lettre est facturée.
  Timer? _frappe;

  @override
  void initState() {
    super.initState();
    final depart = widget.positionInitiale;
    if (depart != null) {
      _position = LatLng(depart.latitude, depart.longitude);
      // Un point déjà connu est résolu d'emblée : l'écran s'ouvre alors avec
      // son adresse, ce qui permet de vérifier qu'on corrige le bon lieu.
      WidgetsBinding.instance.addPostFrameCallback((_) => _resoudre());
    }
  }

  @override
  void dispose() {
    _frappe?.cancel();
    _recherche.dispose();
    _carte?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- recherche

  void _saisie(String valeur) {
    _frappe?.cancel();
    // 350 ms : le temps d'une frappe hésitante, sans que la liste traîne
    // derrière quelqu'un qui tape vite.
    _frappe = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final autour = _position;
      context.read<LieuService>().chercher(
            valeur,
            countryCode: widget.countryCode,
            autour: autour == null
                ? null
                : eccore.GeoPoint(autour.latitude, autour.longitude),
          );
    });
  }

  Future<void> _choisirLaSuggestion(eccore.PlaceSuggestion suggestion) async {
    final service = context.read<LieuService>();
    service.oublierLesSuggestions();
    FocusScope.of(context).unfocus();

    final detail = await service.detailDuLieu(suggestion.placeId);
    if (!mounted || detail == null) return;

    setState(() {
      _position = LatLng(detail.location.latitude, detail.location.longitude);
      _nom = suggestion.description.split(',').first.trim();
      _placeId = detail.placeId;
      // Les composants du détail suffisent : on ne redemande pas au serveur ce
      // que Places vient de rendre. Le géocodage inverse sert au marqueur
      // déplacé, pas au lieu choisi par son nom.
      _adresse = eccore.ReverseGeocodeResult(
        latitude: detail.location.latitude,
        longitude: detail.location.longitude,
        formattedAddress: detail.formattedAddress,
        placeId: detail.placeId,
        city: detail.city,
        country: detail.country,
        countryCode: detail.countryCode,
        district: detail.neighborhood,
      );
    });
    _recadrer();
  }

  // --------------------------------------------------------------- carte

  Future<void> _poser(LatLng point) async {
    setState(() {
      _position = point;
      // Le nom et l'identifiant de lieu appartenaient au point précédent :
      // les garder ferait enregistrer « El Corazón Plateau » sur des
      // coordonnées situées deux rues plus loin.
      _nom = null;
      _placeId = null;
      _adresse = null;
    });
    await _resoudre();
  }

  Future<void> _resoudre() async {
    final point = _position;
    if (point == null) return;

    final resultat = await context.read<LieuService>().quYATIl(
          latitude: point.latitude,
          longitude: point.longitude,
        );
    if (mounted) setState(() => _adresse = resultat);
  }

  void _recadrer() {
    final point = _position;
    if (point == null || _carte == null) return;
    _carte!.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
  }

  void _valider() {
    final point = _position;
    if (point == null) return;
    final adresse = _adresse;

    Navigator.of(context).pop(
      LieuChoisi(
        latitude: point.latitude,
        longitude: point.longitude,
        name: _nom,
        // La ligne de rue plutôt que l'adresse complète : la ville et le pays
        // ont leurs propres champs dans le formulaire, et les répéter dans
        // celui de l'adresse produit « Rue X, Lomé, Togo — Lomé — Togo ».
        address: adresse?.streetLine ?? adresse?.formattedAddress,
        city: adresse?.city,
        country: adresse?.country,
        countryCode: adresse?.countryCode,
        district: adresse?.district,
        placeId: _placeId ?? adresse?.placeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<LieuService>(
      builder: (context, lieu, _) {
        final point = _position;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.titre),
            actions: [
              if (point != null)
                IconButton(
                  tooltip: 'Recentrer sur le point',
                  onPressed: _recadrer,
                  icon: const Icon(Icons.center_focus_strong),
                ),
            ],
          ),
          body: Column(
            children: [
              _BarreDeRecherche(
                controller: _recherche,
                disponible: lieu.rechercheDisponible,
                enCours: lieu.isSearching,
                onChanged: _saisie,
                onVider: () {
                  _recherche.clear();
                  lieu.oublierLesSuggestions();
                },
              ),
              if (lieu.suggestions.isNotEmpty)
                _ListeDeSuggestions(
                  suggestions: lieu.suggestions,
                  onChoisi: _choisirLaSuggestion,
                ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: point ?? const LatLng(0, 0),
                        // Zoom large sans point de départ : mieux vaut un monde
                        // entier qu'un cadrage serré sur (0, 0), au large du
                        // golfe de Guinée.
                        zoom: point == null ? 2 : 16,
                      ),
                      onMapCreated: (controleur) => _carte = controleur,
                      onTap: _poser,
                      markers: point == null
                          ? const {}
                          : {
                              Marker(
                                markerId: const MarkerId('lieu'),
                                position: point,
                                draggable: true,
                                onDragEnd: _poser,
                                infoWindow: InfoWindow(
                                  title: _nom ?? 'Position choisie',
                                  snippet: _adresse?.formattedAddress,
                                ),
                              ),
                            },
                      myLocationButtonEnabled: false,
                    ),
                    if (lieu.isResolving)
                      const Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(child: _Pastille(texte: 'Lecture de l’adresse…')),
                      ),
                    if (point == null)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _Pastille(
                          texte: lieu.rechercheDisponible
                              ? 'Cherchez un lieu, ou touchez la carte.'
                              : 'Touchez la carte pour poser le point.',
                        ),
                      ),
                  ],
                ),
              ),
              _Apercu(
                position: point,
                nom: _nom,
                adresse: _adresse,
                erreur: lieu.error,
                scheme: scheme,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: point == null ? null : _valider,
                icon: const Icon(Icons.check),
                label: const Text('Utiliser ce lieu'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarreDeRecherche extends StatelessWidget {
  const _BarreDeRecherche({
    required this.controller,
    required this.disponible,
    required this.enCours,
    required this.onChanged,
    required this.onVider,
  });

  final TextEditingController controller;
  final bool disponible;
  final bool enCours;
  final ValueChanged<String> onChanged;
  final VoidCallback onVider;

  @override
  Widget build(BuildContext context) {
    if (!disponible) {
      // Un champ de recherche qui ne rend jamais rien fait chercher la panne du
      // côté du réseau. Mieux vaut dire que la clé manque, et rappeler que la
      // carte reste utilisable.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          'Recherche de lieux indisponible : GOOGLE_MAPS_API_KEY n’est pas '
          'renseignée. Touchez la carte pour poser le point.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher un établissement ou une adresse',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: enCours
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (controller.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close), onPressed: onVider)),
        ),
      ),
    );
  }
}

class _ListeDeSuggestions extends StatelessWidget {
  const _ListeDeSuggestions({required this.suggestions, required this.onChoisi});

  final List<eccore.PlaceSuggestion> suggestions;
  final ValueChanged<eccore.PlaceSuggestion> onChoisi;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      child: ConstrainedBox(
        // Bornée : une liste qui mange la carte empêche de vérifier le lieu
        // qu'on est en train de choisir.
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined, size: 20),
              title: Text(suggestion.description, maxLines: 2),
              onTap: () => onChoisi(suggestion),
            );
          },
        ),
      ),
    );
  }
}

/// Ce que l'administrateur lit **avant** de valider.
///
/// C'est le panneau qui rend la chaîne « Google → proposition → validation »
/// visible : sans lui, l'écran renverrait des champs remplis sans que personne
/// ait vu ce qu'ils contiennent.
class _Apercu extends StatelessWidget {
  const _Apercu({
    required this.position,
    required this.nom,
    required this.adresse,
    required this.erreur,
    required this.scheme,
  });

  final LatLng? position;
  final String? nom;
  final eccore.ReverseGeocodeResult? adresse;
  final String? erreur;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    if (position == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nom != null && nom!.isNotEmpty)
            Text(nom!, style: Theme.of(context).textTheme.titleMedium),
          if (adresse?.formattedAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                adresse!.formattedAddress!,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Champ(intitule: 'Latitude', valeur: position!.latitude.toStringAsFixed(6)),
              _Champ(intitule: 'Longitude', valeur: position!.longitude.toStringAsFixed(6)),
              if (adresse?.city != null) _Champ(intitule: 'Ville', valeur: adresse!.city!),
              if (adresse?.district != null)
                _Champ(intitule: 'Quartier', valeur: adresse!.district!),
              if (adresse?.country != null)
                _Champ(
                  intitule: 'Pays',
                  valeur: '${adresse!.country}'
                      '${adresse!.countryCode != null ? ' (${adresse!.countryCode})' : ''}',
                ),
            ],
          ),
          if (erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                erreur!,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  const _Champ({required this.intitule, required this.valeur});

  final String intitule;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          intitule.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(valeur, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(fontSize: 12, color: scheme.onInverseSurface),
      ),
    );
  }
}
