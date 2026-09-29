import 'package:elcorazon_core/src/geography/delivery_zone.dart';
import 'package:elcorazon_core/src/geography/zone_schedule.dart';
import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';

/// Gestes du cycle de vie d'une zone — `backend/apps/geography/zone_actions.py`.
///
/// Les zones de ville (`/geography/manage/zones/`) et les zones propres à une
/// cuisine (`/restaurants/manage/zones/`) exposent les mêmes gestes aux mêmes
/// adresses relatives ; seul le préfixe change, et le serveur décide qui a le
/// droit. [ZoneLifecycleRepository.ville] et [ZoneLifecycleRepository.cuisine]
/// choisissent le préfixe, rien d'autre.
///
/// Aucun geste n'est simulé : chaque méthode rend la zone **telle que le
/// serveur l'a écrite**, ou lève l'erreur qu'il a rendue (409 pour une
/// transition interdite, 403 hors périmètre).
class ZoneLifecycleRepository {
  ZoneLifecycleRepository.ville({required this.apiClient}) : _chemin = '/geography/manage/zones/';

  ZoneLifecycleRepository.cuisine({required this.apiClient})
      : _chemin = '/restaurants/manage/zones/';

  final ApiClient apiClient;
  final String _chemin;

  Future<DeliveryZone> _geste(String zoneId, String geste, Map<String, dynamic> corps) async {
    final reponse = await apiClient.post('$_chemin$zoneId/$geste/', data: corps);
    return DeliveryZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  /// La fiche telle que le serveur la tient — après une écriture d'horaires ou
  /// d'exception, qui ne rendent pas la zone entière.
  Future<DeliveryZone> relire(String zoneId) async {
    final reponse = await apiClient.get('$_chemin$zoneId/');
    return DeliveryZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  /// Brouillon → en revue.
  Future<DeliveryZone> soumettre(String zoneId) => _geste(zoneId, 'submit', const {});

  /// En revue → brouillon.
  Future<DeliveryZone> renvoyerEnBrouillon(String zoneId, {String motif = ''}) =>
      _geste(zoneId, 'return-to-draft', {'reason': motif});

  /// En revue → publiée.
  Future<DeliveryZone> publier(String zoneId) => _geste(zoneId, 'publish', const {});

  /// Publiée → suspendue. Le motif est exigé par le serveur.
  Future<DeliveryZone> suspendre(
    String zoneId, {
    required String motif,
    DateTime? finPrevue,
  }) =>
      _geste(zoneId, 'suspend', {
        'reason': motif,
        if (finPrevue != null) 'expected_end_at': finPrevue.toUtc().toIso8601String(),
      });

  /// Suspendue → publiée.
  Future<DeliveryZone> reactiver(String zoneId) => _geste(zoneId, 'activate', const {});

  /// → archivée, sans retour.
  Future<DeliveryZone> archiver(String zoneId, {String motif = ''}) =>
      _geste(zoneId, 'archive', {'reason': motif});

  /// Copie en brouillon — barème, contour et horaires, jamais l'historique.
  Future<DeliveryZone> dupliquer(String zoneId, {required String nom}) =>
      _geste(zoneId, 'duplicate', {'name': nom});

  /// Remplace la semaine entière. Une liste vide rend la zone à sa cuisine.
  Future<List<HoraireDeZone>> ecrireHoraires(
    String zoneId,
    List<HoraireDeZone> horaires,
  ) async {
    final reponse = await apiClient.put(
      '$_chemin$zoneId/schedule/',
      data: {
        'hours': [for (final h in horaires) h.toJson()],
      },
    );
    return [
      for (final h in (reponse.data as Map<String, dynamic>)['hours'] as List)
        HoraireDeZone.fromJson(h as Map<String, dynamic>),
    ];
  }

  Future<ExceptionDeZone> ajouterException(
    String zoneId, {
    required String nature,
    required DateTime debut,
    required DateTime fin,
    String motif = '',
  }) async {
    final reponse = await apiClient.post(
      '$_chemin$zoneId/exceptions/',
      data: {
        'kind': nature,
        'starts_at': debut.toUtc().toIso8601String(),
        'ends_at': fin.toUtc().toIso8601String(),
        'reason': motif,
      },
    );
    return ExceptionDeZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  Future<void> retirerException(String zoneId, String exceptionId) async {
    await apiClient.delete('$_chemin$zoneId/exceptions/$exceptionId/');
  }
}

/// Prévisualisation d'un import GeoJSON, rendue **sans rien créer**.
class ApercuImportZone {
  const ApercuImportZone({
    required this.contour,
    required this.polygones,
    required this.trous,
    required this.chevauchements,
  });

  factory ApercuImportZone.fromJson(Map<String, dynamic> json) => ApercuImportZone(
        contour: json['boundary'] as Map<String, dynamic>,
        polygones: json['polygons'] as int,
        trous: json['holes'] as int,
        chevauchements: [
          for (final c in json['overlaps'] as List? ?? const [])
            (c as Map<String, dynamic>)['name'] as String,
        ],
      );

  /// Le contour normalisé par le serveur — c'est lui que la carte dessine.
  final Map<String, dynamic> contour;
  final int polygones;
  final int trous;
  final List<String> chevauchements;
}

/// Import d'un contour GeoJSON — `POST /geography/manage/zones/import/`.
class ZoneImportRepository {
  ZoneImportRepository({required this.apiClient});

  final ApiClient apiClient;

  static const _chemin = '/geography/manage/zones/import/';

  /// Valide tout, sans rien écrire. Un 400 porte la phrase à montrer.
  Future<ApercuImportZone> previsualiser({
    required String cityId,
    required String nom,
    required Object geojson,
  }) async {
    final reponse = await apiClient.post(
      _chemin,
      data: {'city': cityId, 'name': nom, 'geojson': geojson, 'dry_run': true},
    );
    return ApercuImportZone.fromJson(reponse.data as Map<String, dynamic>);
  }

  /// Crée la zone **en brouillon**, au barème nul, à relire avant soumission.
  Future<DeliveryZone> importer({
    required String cityId,
    required String nom,
    required Object geojson,
  }) async {
    final reponse = await apiClient.post(
      _chemin,
      data: {'city': cityId, 'name': nom, 'geojson': geojson, 'dry_run': false},
    );
    return DeliveryZone.fromJson(reponse.data as Map<String, dynamic>);
  }
}

/// Zone résumée, telle que la rend l'outil de couverture.
class ZoneBreve {
  const ZoneBreve({
    required this.id,
    required this.nom,
    required this.statut,
    required this.priorite,
    required this.ville,
    this.cuisine,
    this.surfaceKm2,
    this.rang,
    this.exclueCar,
    this.rouvreLe,
    this.distanceM,
  });

  factory ZoneBreve.fromJson(Map<String, dynamic> json) => ZoneBreve(
        id: json['id'] as String,
        nom: json['name'] as String,
        statut: json['status'] as String,
        priorite: json['priority'] as int? ?? 0,
        ville: json['city'] as String? ?? '',
        cuisine: json['restaurant'] as String?,
        surfaceKm2: (json['surface_km2'] as num?)?.toDouble(),
        rang: json['rank'] as int?,
        exclueCar: json['excluded_because'] as String?,
        rouvreLe:
            json['reopens_at'] is String ? DateTime.tryParse(json['reopens_at'] as String) : null,
        distanceM: json['distance_m'] as int?,
      );

  final String id;
  final String nom;
  final String statut;
  final int priorite;
  final String ville;
  final String? cuisine;
  final double? surfaceKm2;
  final int? rang;

  /// Nul si elle concourait ; sinon un statut, `closed`, `other_kitchen` ou
  /// `other_city`.
  final String? exclueCar;
  final DateTime? rouvreLe;
  final int? distanceM;
}

/// Un livreur vu depuis une zone : éligible, ou écarté pour un motif stable
/// (`account_disabled`, `not_verified`, `offline`, `busy`, `out_of_zone`,
/// `other_kitchen`).
class LivreurDeZone {
  const LivreurDeZone({
    required this.id,
    required this.nom,
    required this.enLigne,
    required this.eligible,
    this.motif,
  });

  factory LivreurDeZone.fromJson(Map<String, dynamic> json) => LivreurDeZone(
        id: json['id'] as String,
        nom: json['name'] as String? ?? '',
        enLigne: json['is_online'] as bool? ?? false,
        eligible: json['eligible'] as bool? ?? false,
        motif: json['reason'] as String?,
      );

  final String id;
  final String nom;
  final bool enLigne;
  final bool eligible;
  final String? motif;

  static String libelleMotif(String? motif) => switch (motif) {
        null => 'Éligible',
        'account_disabled' => 'Compte désactivé',
        'not_verified' => 'Dossier non validé',
        'offline' => 'Hors ligne',
        'busy' => 'Occupé (course en cours)',
        'out_of_zone' => 'Hors de ses zones',
        'other_kitchen' => 'Rattaché à une autre cuisine',
        _ => motif,
      };
}

/// Cuisine qui livre une zone, et son état.
class CuisineDeZone {
  const CuisineDeZone({
    required this.slug,
    required this.nom,
    required this.statut,
    required this.ville,
    required this.peutCommander,
    required this.commandesEnCours,
    this.motif,
    this.distanceM,
  });

  factory CuisineDeZone.fromJson(Map<String, dynamic> json) => CuisineDeZone(
        slug: json['slug'] as String,
        nom: json['name'] as String,
        statut: json['status'] as String? ?? '',
        ville: json['city'] as String? ?? '',
        peutCommander: json['can_order_now'] as bool? ?? false,
        commandesEnCours: json['active_orders'] as int? ?? 0,
        motif: json['unavailable_code'] as String?,
        distanceM: json['distance_m'] as int?,
      );

  final String slug;
  final String nom;
  final String statut;
  final String ville;
  final bool peutCommander;
  final int commandesEnCours;
  final String? motif;
  final int? distanceM;
}

/// Diagnostic d'une adresse — `POST /delivery/coverage-test/`.
class RapportDeCouverture {
  const RapportDeCouverture({
    required this.disponible,
    required this.candidates,
    this.motif,
    this.raison,
    this.zone,
    this.raisonDuChoix,
    this.pays,
    this.ville,
    this.cuisine,
    this.distanceM,
    this.frais,
    this.fraisBruts,
    this.gratuite,
    this.delaiMinutes,
    this.commandeMinimum,
    this.francoDes,
    this.livreurs,
    this.zoneLaPlusProche,
  });

  factory RapportDeCouverture.fromJson(Map<String, dynamic> json) {
    Money? argent(Object? v) => v == null ? null : Money.fromJson(v as Map<String, dynamic>);
    final cuisine = json['kitchen'] as Map<String, dynamic>?;
    return RapportDeCouverture(
      disponible: json['available'] as bool,
      motif: json['unavailable_code'] as String?,
      raison: json['reason'] as String?,
      zone: json['zone'] == null ? null : ZoneBreve.fromJson(json['zone'] as Map<String, dynamic>),
      raisonDuChoix: json['selection_reason'] as String?,
      candidates: [
        for (final c in json['candidates'] as List? ?? const [])
          ZoneBreve.fromJson(c as Map<String, dynamic>),
      ],
      pays: json['country'] as String?,
      ville: json['city'] as String?,
      cuisine:
          cuisine == null ? null : CuisineDeZone.fromJson({...cuisine, 'city': json['city'] ?? ''}),
      distanceM: json['distance_m'] as int?,
      frais: argent(json['delivery_fee']),
      fraisBruts: argent(json['gross_fee']),
      gratuite: json['is_free'] as bool?,
      delaiMinutes: json['estimated_minutes'] as int?,
      commandeMinimum: argent(json['min_order_amount']),
      francoDes: argent(json['free_delivery_threshold']),
      livreurs: json['couriers'] == null
          ? null
          : [
              for (final l in json['couriers'] as List)
                LivreurDeZone.fromJson(l as Map<String, dynamic>),
            ],
      zoneLaPlusProche: json['nearest_zone'] == null
          ? null
          : ZoneBreve.fromJson(json['nearest_zone'] as Map<String, dynamic>),
    );
  }

  final bool disponible;
  final String? motif;
  final String? raison;
  final ZoneBreve? zone;
  final String? raisonDuChoix;
  final List<ZoneBreve> candidates;
  final String? pays;
  final String? ville;
  final CuisineDeZone? cuisine;
  final int? distanceM;
  final Money? frais;
  final Money? fraisBruts;
  final bool? gratuite;
  final int? delaiMinutes;
  final Money? commandeMinimum;
  final Money? francoDes;

  /// Nul quand le compte n'a pas `couriers.read` ou que la cuisine sort de
  /// son périmètre — le serveur tait la flotte, l'écran ne l'invente pas.
  final List<LivreurDeZone>? livreurs;
  final ZoneBreve? zoneLaPlusProche;
}

/// L'outil « Tester une adresse » et la vue d'une zone depuis ses cuisines et
/// sa flotte — tout vient du serveur, qui applique la règle de la commande.
class CoverageRepository {
  CoverageRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<RapportDeCouverture> tester({
    required double latitude,
    required double longitude,
    Money? sousTotal,
    String? cuisineSlug,
    DateTime? a,
  }) async {
    final reponse = await apiClient.post(
      '/delivery/coverage-test/',
      data: {
        'lat': latitude,
        'lon': longitude,
        if (sousTotal != null) 'subtotal': sousTotal.toJson(),
        if (cuisineSlug != null && cuisineSlug.isNotEmpty) 'restaurant': cuisineSlug,
        if (a != null) 'at': a.toUtc().toIso8601String(),
      },
    );
    return RapportDeCouverture.fromJson(reponse.data as Map<String, dynamic>);
  }

  Future<List<CuisineDeZone>> cuisinesDe(String zoneId) async {
    final reponse = await apiClient.get('/delivery/zones/$zoneId/kitchens/');
    return [
      for (final c in (reponse.data as Map<String, dynamic>)['kitchens'] as List)
        CuisineDeZone.fromJson(c as Map<String, dynamic>),
    ];
  }

  /// Livreurs par cuisine : `{slug de cuisine: livreurs}`.
  Future<Map<String, List<LivreurDeZone>>> livreursDe(String zoneId) async {
    final reponse = await apiClient.get('/delivery/zones/$zoneId/couriers/');
    return {
      for (final bloc in (reponse.data as Map<String, dynamic>)['kitchens'] as List)
        (bloc as Map<String, dynamic>)['kitchen'] as String: [
          for (final l in bloc['couriers'] as List)
            LivreurDeZone.fromJson(l as Map<String, dynamic>),
        ],
    };
  }
}
