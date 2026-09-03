import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/services/admin_auth_service.dart';

/// Qui porte quelle commande — `/delivery/manage/assignments/` (Phase 6).
///
/// Ce service comble le trou le plus visible du back-office : **rien ne disait
/// au personnel quel livreur transporte une commande.**
///
/// Le manque était écrit dans le code, à un seul endroit, et se propageait à
/// six : `CommandeAffichee.livreurAffecte` rendait `null`, toujours, avec un
/// commentaire expliquant que le sérialiseur de supervision ne porte pas le
/// livreur. C'était exact — et ça le reste : `apps.orders` ne dépend pas
/// d'`apps.delivery` (ADR-002), donc une commande ne saura jamais qui la
/// livre. La réponse se lit du côté de la livraison, sur une route de
/// supervision qui n'existait pas et qui existe maintenant.
///
/// Conséquences visibles du `null` d'avant :
///
/// * « Livraisons actives » affichait chaque course sans porteur ;
/// * la carte de supervision ne posait jamais le trait entre un livreur et sa
///   commande ;
/// * le bouton d'affectation proposait toujours « Assigner », jamais
///   « Réassigner », y compris sur une commande déjà confiée ;
/// * l'historique et les statistiques d'un livreur étaient systématiquement
///   vides — ils filtraient les commandes sur un identifiant absent.
///
/// **Une seule requête pour tout un écran.** [refresh] charge les courses
/// vivantes du périmètre et les range par commande ; un écran qui affiche
/// trente livraisons ne fait pas trente appels. [loadFor] existe pour la fiche
/// d'une commande, où l'on n'en veut qu'une.
class AssignmentService extends ChangeNotifier {
  eccore.ManagedAssignmentRepository get _courses =>
      eccore.ManagedAssignmentRepository(apiClient: AdminAuthService().apiClient);

  Map<String, eccore.Assignment> _parCommande = const {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Courses vivantes, indexées par identifiant de commande.
  Map<String, eccore.Assignment> get parCommande => Map.unmodifiable(_parCommande);

  /// La course en cours d'une commande, ou `null` si personne ne la porte.
  eccore.Assignment? assignmentOf(String orderId) => _parCommande[orderId];

  /// Le **dossier livreur** qui porte cette commande — l'identifiant que rend
  /// `/delivery/couriers/`, celui qu'attendent les écrans de la flotte.
  String? courierIdOf(String orderId) => _parCommande[orderId]?.courier.id;

  /// Le nom du porteur, tel qu'on l'annonce au téléphone.
  String? courierNameOf(String orderId) => _parCommande[orderId]?.courier.fullName;

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _parCommande = await _courses.activeByOrder();
      eccore.Journal.trace(
          'AssignmentService: ${_parCommande.length} course(s) en cours',
          );
    } on eccore.ApiException catch (e) {
      // 403 sans `orders.read` : le compte ne supervise pas les commandes, et
      // l'écran qui l'affiche ne lui est de toute façon pas destiné. Pas une
      // panne — inutile de l'annoncer comme telle.
      _error = e.status == 403 ? null : e.detail;
      eccore.Journal.trace('AssignmentService: courses indisponibles — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// La course d'une seule commande, mise en cache au passage.
  ///
  /// Rend `null` quand personne ne la porte **et** quand la lecture échoue :
  /// la fiche d'une commande affiche alors « Aucun livreur affecté », ce qui
  /// est vrai dans le premier cas et prudent dans le second — annoncer un
  /// porteur qu'on n'a pas pu lire serait pire.
  Future<eccore.Assignment?> loadFor(String orderId) async {
    try {
      final course = await _courses.activeFor(orderId);
      _parCommande = {
        ..._parCommande,
        if (course != null) orderId: course,
      };
      notifyListeners();
      return course;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('AssignmentService: course indisponible — ${e.code}');
      return null;
    }
  }

  /// Les courses d'un livreur, **historique compris** — c'est ce que demandent
  /// son historique et ses statistiques, qui portent sur ce qu'il a fait et non
  /// sur ce qu'il fait à cet instant.
  Future<List<eccore.Assignment>> historyOf(String courierId) async {
    try {
      return await _courses.list(courierId: courierId);
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('AssignmentService: historique indisponible — ${e.code}');
      return const [];
    }
  }
}
