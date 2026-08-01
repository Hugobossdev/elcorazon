import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Campagnes de notifications — `/notifications/campaigns/` (Phase 6).
///
/// Le service a perdu les deux tiers de sa surface, et ce n'est pas une
/// simplification d'écriture : ce qui a disparu ne pouvait pas fonctionner.
///
/// * **La « prévision de ventes », la « prédiction de stock » et le « risque
///   d'attrition »** étaient calculés dans le navigateur, par des moyennes
///   pondérées à la main sur les lignes que Supabase avait bien voulu rendre.
///   Ils annonçaient un « niveau de confiance » qui ne mesurait rien, et
///   exigeaient que le back-office charge l'historique de commandes de tous les
///   clients. On ne remplace pas une prédiction par une autre : les chiffres
///   réels sont dans les rapports (`/analytics/reports/*`), et une vraie
///   prévision est un travail de modèle, pas de boucle `for` ;
/// * **le ciblage par liste d'identifiants** (`targetUserIds`) laissait l'écran
///   décider qui reçoit un envoi de masse. Le serveur n'expose que des segments
///   fermés — tous les clients, les livreurs, ceux qui ont commandé récemment,
///   ceux qui ne l'ont plus fait — parce qu'un ciblage libre est une requête
///   que personne n'a relue avant qu'elle ne parte à des milliers de gens ;
/// * **les « métriques » écrites par le client** (`updateCampaignMetrics`)
///   permettaient d'annoncer des ouvertures et des conversions inventées. Le
///   seul chiffre est désormais `recipientCount`, écrit par l'envoi lui-même.
///
/// Reste ce qu'est vraiment une campagne : on rédige, on estime, on envoie une
/// fois. Une campagne envoyée devient immuable — la corriger après coup ferait
/// afficher à l'historique un texte que personne n'a reçu.
class MarketingService extends ChangeNotifier {
  eccore.CampaignRepository get _campaignsApi =>
      eccore.CampaignRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.Campaign> _campaigns = [];
  final Map<String, int> _audienceEstimates = {};
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<eccore.Campaign> get campaigns => _campaigns;
  List<eccore.Campaign> get drafts =>
      _campaigns.where((c) => c.isDraft).toList();
  List<eccore.Campaign> get sent => _campaigns.where((c) => c.isSent).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _campaigns = await _campaignsApi.list();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Marketing : campagnes indisponibles — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rédige une campagne. Elle reste en brouillon : rien ne part ici.
  Future<eccore.Campaign?> createCampaign({
    required String title,
    required String body,
    required String audience,
    int segmentDays = 30,
  }) async {
    try {
      final cree = await _campaignsApi.create(
        title: title,
        body: body,
        audience: audience,
        segmentDays: segmentDays,
      );
      _campaigns = [cree, ..._campaigns];
      notifyListeners();
      return cree;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Marketing : rédaction refusée — ${e.code}');
      notifyListeners();
      return null;
    }
  }

  /// Corrige un brouillon.
  ///
  /// Le serveur refuse une campagne déjà envoyée (403) — l'écran le dit avant
  /// d'essayer, mais c'est lui qui tranche.
  Future<bool> updateCampaign({
    required String id,
    String? title,
    String? body,
    String? audience,
    int? segmentDays,
  }) async {
    try {
      final maj = await _campaignsApi.update(
        campaignId: id,
        title: title,
        body: body,
        audience: audience,
        segmentDays: segmentDays,
      );
      _remplacer(maj);
      // Le segment a pu changer : l'estimation d'audience ne vaut plus.
      _audienceEstimates.remove(id);
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 403
          ? "Une campagne envoyée ne se modifie plus : l'historique afficherait "
                "un texte que personne n'a reçu."
          : e.detail;
      debugPrint('Marketing : modification refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  /// Combien de personnes cette campagne viserait, si on l'envoyait.
  ///
  /// C'est un **majorant** : le serveur compte le segment, pas les envois
  /// aboutis, puisque le consentement au marketing ne se vérifie qu'à
  /// l'écriture de chaque notification. L'annoncer autrement ferait passer un
  /// refus de consentement pour une erreur d'envoi.
  Future<int?> estimateAudience(String id) async {
    try {
      final compte = await _campaignsApi.estimateAudience(id);
      _audienceEstimates[id] = compte;
      notifyListeners();
      return compte;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Marketing : estimation indisponible — ${e.code}');
      notifyListeners();
      return null;
    }
  }

  /// Dernière estimation connue pour cette campagne, sans appel réseau.
  int? knownAudience(String id) => _audienceEstimates[id];

  /// Envoie la campagne, une seule fois.
  ///
  /// Le rejeu est absorbé par le serveur plutôt que refusé : un double clic
  /// renvoie la campagne telle qu'elle est partie, au lieu d'une erreur qui
  /// ferait croire à un échec — et inviterait à réessayer.
  Future<bool> sendCampaign(String id) async {
    try {
      _remplacer(await _campaignsApi.send(id));
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Marketing : envoi refusé — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  void _remplacer(eccore.Campaign campagne) {
    final index = _campaigns.indexWhere((c) => c.id == campagne.id);
    if (index != -1) _campaigns[index] = campagne;
    notifyListeners();
  }
}
