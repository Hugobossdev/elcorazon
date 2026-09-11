import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:admin/services/admin_auth_service.dart';

/// **Chercher un lieu, et savoir ce qu'il y a à cet endroit.**
///
/// ## Ce que ce service remplace
///
/// Placer un établissement se faisait en tapant sa latitude et sa longitude au
/// clavier, dans deux champs texte. Personne ne connaît par cœur les
/// coordonnées d'une adresse : en pratique on les copiait depuis un autre
/// onglet, avec une chance sur deux de les intervertir — une longitude saisie
/// en latitude place un restaurant de Lomé au pôle, ce qui ne se voit qu'au
/// moment de la mise en service.
///
/// Deux sources, et elles ne font pas la même chose :
///
/// * **Places** (`eccore.PlacesRepository`) répond à « où est *ce nom* » —
///   l'administrateur tape « El Corazón Plateau », il obtient un point ;
/// * **le géocodage inverse du serveur** répond à « qu'y a-t-il *ici* » —
///   l'administrateur déplace un marqueur, il obtient un pays, une ville, un
///   quartier.
///
/// ## Deux clés, deux portées
///
/// Places est interrogé **depuis l'application**, avec la clé du back-office :
/// c'est ce qui permet les jetons de session, qui regroupent les frappes d'une
/// recherche et le détail final en une seule facturation. Le géocodage inverse
/// passe **par le serveur**, dont la clé est restreinte par adresse IP et dont
/// les réponses sont mises en cache — un marqueur qu'on déplace d'un pixel puis
/// qu'on ramène ne paie qu'une fois.
///
/// ## Ce que ce service ne fait pas
///
/// Il n'écrit rien. Une réponse de Google est une **proposition** : c'est
/// l'administrateur qui valide, et ce sont les formulaires qui enregistrent.
/// Rien n'écrase une donnée saisie à la main — c'est la règle « Google →
/// proposition → validation → enregistrement ».
class LieuService extends ChangeNotifier {
  static final LieuService _instance = LieuService._();

  factory LieuService() => _instance;

  LieuService._()
      : _placesInjecte = null,
        _geocodageInjecte = null;

  /// Instance isolée, alimentée par des dépôts donnés. Réservée aux tests.
  @visibleForTesting
  LieuService.avecDepots({
    required eccore.PlacesRepository places,
    required eccore.ReverseGeocodeRepository geocodage,
  })  : _placesInjecte = places,
        _geocodageInjecte = geocodage;

  final eccore.PlacesRepository? _placesInjecte;
  final eccore.ReverseGeocodeRepository? _geocodageInjecte;

  eccore.PlacesRepository get _places =>
      _placesInjecte ??
      eccore.PlacesRepository(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');

  eccore.ReverseGeocodeRepository get _geocodage =>
      _geocodageInjecte ??
      eccore.ReverseGeocodeRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.PlaceSuggestion> _suggestions = const [];
  bool _recherche = false;
  bool _resolution = false;
  String? _error;

  List<eccore.PlaceSuggestion> get suggestions => List.unmodifiable(_suggestions);

  /// Une recherche est-elle en cours ? L'écran grise alors la liste plutôt que
  /// de la vider : une liste qui clignote à chaque frappe est illisible.
  bool get isSearching => _recherche;

  /// Un point est-il en cours de résolution ? Le marqueur a déjà bougé, mais la
  /// fiche d'adresse n'est pas encore à jour.
  bool get isResolving => _resolution;

  String? get error => _error;

  /// La clé Places est-elle configurée ?
  ///
  /// L'écran s'en sert pour proposer la saisie manuelle plutôt qu'un champ de
  /// recherche qui ne rendrait jamais rien — un champ muet fait chercher la
  /// panne du côté du réseau.
  bool get rechercheDisponible => (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').isNotEmpty;

  // ------------------------------------------------------------- recherche

  /// Suggestions pour une saisie.
  ///
  /// [countryCode] borne la recherche au marché visé — en minuscules, comme
  /// l'attend `includedRegionCodes`. **Aucun pays n'est écrit ici** : l'écran
  /// fournit celui du formulaire, ce qui est la condition pour chercher au
  /// Cameroun comme au Togo.
  ///
  /// [autour] biaise les résultats sans les borner : une rue homonyme de la
  /// ville qu'on configure passe devant, les autres restent atteignables.
  Future<void> chercher(
    String saisie, {
    String? countryCode,
    eccore.GeoPoint? autour,
  }) async {
    _recherche = true;
    _error = null;
    notifyListeners();

    try {
      _suggestions = await _places.autocomplete(
        saisie,
        language: 'fr',
        countryCode: countryCode?.toLowerCase(),
        locationBias: autour,
      );
    } finally {
      _recherche = false;
      notifyListeners();
    }
  }

  /// Vide les suggestions — à la fermeture du champ, ou après un choix.
  void oublierLesSuggestions() {
    if (_suggestions.isEmpty) return;
    _suggestions = const [];
    notifyListeners();
  }

  /// Détail d'un lieu choisi dans la liste.
  ///
  /// Rend `null` quand Google ne rend ni point ni adresse : un lieu à demi lu
  /// produirait une position dont personne ne saurait qu'elle est fausse.
  Future<eccore.PlaceDetails?> detailDuLieu(String placeId) async {
    _resolution = true;
    notifyListeners();
    try {
      return await _places.getDetails(placeId, language: 'fr');
    } finally {
      _resolution = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------ géocodage inverse

  /// Ce qu'il y a à cet endroit — pays, région, ville, quartier, adresse.
  ///
  /// Rend `null` sur une panne du service, en renseignant [error] : l'écran
  /// garde alors la position et laisse remplir les champs à la main. Une
  /// position sans adresse reste une position valide — un point de retrait peut
  /// se trouver là où aucun service d'adressage ne nomme quoi que ce soit.
  Future<eccore.ReverseGeocodeResult?> quYATIl({
    required double latitude,
    required double longitude,
  }) async {
    _resolution = true;
    _error = null;
    notifyListeners();

    try {
      return await _geocodage.lookup(latitude: latitude, longitude: longitude);
    } on eccore.ApiException catch (e) {
      _error = e.status == 503
          ? 'Le géocodage n’est pas configuré sur le serveur. La position est '
                'conservée : renseignez l’adresse à la main.'
          : e.detail;
      eccore.Journal.trace('Lieu : géocodage inverse refusé — ${e.code}');
      return null;
    } finally {
      _resolution = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void reset() {
    _suggestions = const [];
    _recherche = false;
    _resolution = false;
    _error = null;
    notifyListeners();
  }
}
