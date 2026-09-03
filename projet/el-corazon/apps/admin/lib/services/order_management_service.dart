import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/filtres_supervision.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Supervision des commandes — `/api/v1/orders/manage/` (Phase 6).
///
/// Le périmètre visible n'est plus décidé ici : le serveur ne rend que les
/// commandes des établissements auxquels le compte est rattaché, et refuse les
/// gestes dont il n'a pas la permission. L'implémentation Supabase lisait la
/// table `orders` en entier et se contentait de masquer des boutons.
class OrderManagementService extends ChangeNotifier {
  eccore.ManagedOrderRepository get _orders =>
      eccore.ManagedOrderRepository(apiClient: AdminAuthService().apiClient);

  /// La **fenêtre agrégée** : un an de commandes, chargée à la demande.
  ///
  /// Sert aux compteurs, aux alertes et aux écrans qui raisonnent sur
  /// l'ensemble — carte, livraisons actives, historique d'un livreur. Ce n'est
  /// **pas** ce qu'affiche la liste de supervision, qui est paginée.
  List<eccore.Order> _allOrders = [];
  bool _isLoading = false;
  bool _fenetreChargee = false;

  List<eccore.Order> get allOrders => _allOrders;
  bool get isLoading => _isLoading;

  /// La fenêtre agrégée a-t-elle été lue au moins une fois ? Un écran qui
  /// affiche des compteurs doit distinguer « zéro commande » de « pas encore
  /// chargé » — les deux donnent zéro, et un seul mérite un indicateur.
  bool get fenetreChargee => _fenetreChargee;

  // ------------------------------------------------------------ pagination

  /// La page affichée par la liste de supervision.
  eccore.Page<eccore.Order>? _page;

  /// Les filtres qui ont produit [_page]. Conservés pour que « page suivante »
  /// suive la **même** recherche, et pour pouvoir la rejouer après un
  /// changement de statut reçu en temps réel.
  FiltresCommandes _filtres = const FiltresCommandes();

  bool _pageEnCours = false;
  String? _pageErreur;

  /// Les commandes de la page courante. Vide tant qu'aucune page n'est lue.
  List<eccore.Order> get pageCourante => _page?.results ?? const [];

  /// Le nombre total de commandes **correspondant aux filtres**, tel que le
  /// serveur le compte. C'est ce qu'on affiche à côté de « page 2 sur 17 » ;
  /// le déduire du nombre de lignes reçues donnerait le compte d'une page.
  int get totalFiltre => _page?.count ?? 0;

  bool get aPageSuivante => _page?.hasNext ?? false;
  bool get aPagePrecedente => _page?.hasPrevious ?? false;
  bool get pageEnCours => _pageEnCours;
  String? get pageErreur => _pageErreur;
  FiltresCommandes get filtres => _filtres;

  /// Rang de la page affichée, à partir de 1.
  int get numeroDePage => _numeroDePage;
  int _numeroDePage = 1;

  /// Nombre de pages, ou 1 quand il n'y a rien.
  int get nombreDePages {
    final total = totalFiltre;
    if (total == 0) return 1;
    return (total + _filtres.taillePage - 1) ~/ _filtres.taillePage;
  }

  /// Instance **sans chargement**, alimentée par une liste donnée.
  ///
  /// Réservée aux tests : le constructeur ordinaire programme une lecture
  /// serveur au premier frame, ce qui est le bon comportement dans
  /// l'application et une dépendance réseau inutile dans un test qui vérifie
  /// une moyenne. Même procédé que `RestaurantScopeService.avecLecture`.
  @visibleForTesting
  OrderManagementService.pourTests(List<eccore.Order> commandes) : _allOrders = commandes;

  OrderManagementService() {
    // **Aucun chargement au démarrage.**
    //
    // Le constructeur lançait `_loadAllOrders()` au premier frame, c'est-à-dire
    // qu'ouvrir n'importe quel écran du back-office téléchargeait un an de
    // commandes, page après page, avant même qu'un écran en ait besoin. La
    // fenêtre agrégée se charge maintenant à la première demande
    // ([ensureWindowLoaded]), et la liste que l'opérateur parcourt ne passe
    // plus par elle du tout : elle demande **une page** ([loadPage]).
    //
    // Le temps réel est branché depuis `DashboardRealtimeService` : un
    // changement de statut arrive de lui-même et provoque la relecture de
    // **cette** commande ([applyStatusChange]), pas de la liste.
  }

  void _setLoading(bool value) {
    _isLoading = value;
    // Defer notifications to avoid setState/markNeedsBuild during build
    Future.microtask(() => notifyListeners());
  }

  /// Profondeur d'historique chargée par la supervision.
  ///
  /// Le dépôt suit `next` jusqu'au bout : sans borne, chaque ouverture de
  /// l'écran télécharge **toutes** les commandes jamais passées, page après
  /// page, pour en afficher la fin. Un an couvre le filtre le plus large de
  /// l'interface (« 1 an », sur l'historique d'un livreur) ; au-delà, ce sont
  /// les rapports qui répondent, et eux agrègent côté serveur.
  static const Duration _profondeur = Duration(days: 365);

  /// Charge la fenêtre agrégée si elle ne l'est pas déjà.
  ///
  /// À appeler par les écrans qui raisonnent sur l'ensemble — compteurs,
  /// alertes, carte. Un écran qui affiche une liste n'a pas à l'appeler : il
  /// demande une page.
  Future<void> ensureWindowLoaded() async {
    if (_fenetreChargee || _isLoading) return;
    await _loadAllOrders();
  }

  /// Charger les commandes de la fenêtre de supervision.
  Future<void> _loadAllOrders() async {
    _setLoading(true);
    try {
      final remote = await _orders.list(
        placedFrom: DateTime.now().subtract(_profondeur),
      );
      _allOrders = remote;
      _fenetreChargee = true;
      eccore.Journal.trace('OrderManagementService: ${_allOrders.length} commande(s)');
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: chargement impossible — ${e.code}');
      _allOrders = [];
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------------------------------------ liste paginée

  /// Charge la première page pour les filtres donnés.
  ///
  /// Un changement de filtre **remet la pagination à zéro** : rester en page 4
  /// après avoir changé de statut afficherait la page 4 d'une autre liste, et
  /// « aucun résultat » y voudrait dire « pas sur cette page-là ».
  Future<void> loadPage(FiltresCommandes filtres) async {
    _filtres = filtres;
    _numeroDePage = 1;
    // Les compteurs partent en parallèle de la page : ils portent sur la même
    // sélection, et les enchaîner doublerait l'attente avant le premier
    // affichage.
    unawaited(refreshCounts());
    await _lire(
      () => _orders.listPage(
        status: filtres.statut?.versServeur,
        search: filtres.recherche.trim().isEmpty ? null : filtres.recherche.trim(),
        placedFrom: filtres.depuis,
        placedTo: filtres.jusqua,
        restaurantSlug: filtres.restaurantSlug,
        pageSize: filtres.taillePage,
      ),
    );
  }

  /// Le nombre de commandes par statut, pour les onglets.
  ///
  /// Vide tant qu'il n'a pas été lu : un onglet affiche alors son libellé nu
  /// plutôt qu'un « (0) » qui serait faux.
  Map<String, int> _comptesParStatut = const {};
  Map<String, int> get comptesParStatut => Map.unmodifiable(_comptesParStatut);

  /// Le compte d'un statut, ou `null` s'il n'est pas encore connu.
  int? compteDe(StatutCommande statut) => _comptesParStatut[statut.versServeur];

  /// Recharge les compteurs d'onglets, **avec les filtres courants**.
  ///
  /// Sans les filtres, un onglet annoncerait douze commandes et en afficherait
  /// trois — celles que la recherche a retenues.
  ///
  /// Un échec laisse les compteurs précédents en place plutôt que de les vider :
  /// des libellés qui perdent leur nombre à chaque coupure réseau clignotent
  /// pour rien.
  Future<void> refreshCounts() async {
    try {
      _comptesParStatut = await _orders.countsByStatus(
        restaurantSlug: _filtres.restaurantSlug,
        search: _filtres.recherche,
        placedFrom: _filtres.depuis,
        placedTo: _filtres.jusqua,
      );
      notifyListeners();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: compteurs indisponibles — ${e.code}');
    }
  }

  /// Rejoue la page affichée, mêmes filtres et même rang.
  ///
  /// C'est ce que fait le bouton « Recharger », et ce que déclenche une
  /// reconnexion du canal temps réel : pendant la coupure, des commandes ont pu
  /// entrer ou sortir de la sélection.
  Future<void> reloadPage() async {
    final page = _page;
    if (page == null) {
      await loadPage(_filtres);
      return;
    }
    // On rejoue le **rang** courant plutôt que l'URL `previous`+1 : l'URL de la
    // page courante n'est pas rendue par le serveur, seules ses voisines le
    // sont.
    final rang = _numeroDePage;
    await loadPage(_filtres);
    for (var i = 1; i < rang && aPageSuivante; i++) {
      await nextPage();
    }
  }

  Future<void> nextPage() async {
    final url = _page?.next;
    if (url == null) return;
    _numeroDePage++;
    await _lire(() => _orders.pageAt(url));
  }

  Future<void> previousPage() async {
    final url = _page?.previous;
    if (url == null) return;
    _numeroDePage = _numeroDePage > 1 ? _numeroDePage - 1 : 1;
    await _lire(() => _orders.pageAt(url));
  }

  Future<void> _lire(Future<eccore.Page<eccore.Order>> Function() lecture) async {
    _pageEnCours = true;
    _pageErreur = null;
    notifyListeners();

    try {
      _page = await lecture();
    } on eccore.ApiException catch (e) {
      // La page précédente reste affichée : la vider sur une coupure réseau
      // ferait disparaître un service en cours sous les yeux de l'opérateur.
      _pageErreur = e.detail;
      eccore.Journal.trace('OrderManagementService: page indisponible — ${e.code}');
    } finally {
      _pageEnCours = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ temps réel

  /// Applique un changement de statut annoncé par le canal temps réel.
  ///
  /// **Une commande relue, pas une liste rechargée.** Le message porte le
  /// statut, mais pas `allowed_transitions` : reconstruire la commande à partir
  /// de la charge donnerait des boutons faux. Une lecture ciblée coûte une
  /// requête par changement réel — à comparer aux vingt lignes qu'un
  /// rechargement de page relirait pour n'en changer qu'une.
  ///
  /// Rend `true` si la commande était affichée. Un `false` signifie qu'elle est
  /// hors de la sélection courante : à l'écran d'en informer, plutôt que de
  /// l'insérer de force dans une page dont elle romprait l'ordre et le compte.
  Future<bool> applyStatusChange(String orderId) async {
    final dansLaPage = pageCourante.any((o) => o.id == orderId);
    final dansLaFenetre = _allOrders.any((o) => o.id == orderId);
    if (!dansLaPage && !dansLaFenetre) return false;

    try {
      final maj = await _orders.getById(orderId);
      // Une commande qui change de statut quitte un onglet et en rejoint un
      // autre : deux compteurs au moins sont périmés.
      unawaited(refreshCounts());
      if (dansLaFenetre) _replaceLocally(maj);
      if (dansLaPage) {
        _page = eccore.Page<eccore.Order>(
          results: [
            for (final commande in pageCourante)
              if (commande.id == orderId) maj else commande,
          ],
          count: _page!.count,
          next: _page!.next,
          previous: _page!.previous,
        );
        notifyListeners();
      }
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: relecture impossible — ${e.code}');
      return false;
    }
  }

  /// Fait avancer le statut d'une commande.
  ///
  /// La machine à états est côté serveur : une transition impossible sort en
  /// 409 **avec les cibles autorisées**. Elle n'est pas rejouée ici — deux
  /// graphes finiraient par diverger, et c'est l'écran qui afficherait des
  /// boutons menant à un refus.
  ///
  /// L'annulation ne passe pas par ici : voir [cancelOrder], qui exige une
  /// permission distincte et un motif.
  Future<bool> updateOrderStatus(String orderId, StatutCommande newStatus) async {
    if (newStatus == StatutCommande.annulee) {
      return cancelOrder(orderId, 'Annulée depuis la supervision');
    }

    try {
      final updated = await _orders.updateStatus(
        orderId: orderId,
        status: newStatus.versServeur,
      );
      _replaceLocally(updated);
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: transition refusée — ${e.code}');
      return false;
    }
  }

  void _replaceLocally(eccore.Order order) {
    final index = _allOrders.indexWhere((existing) => existing.id == order.id);
    if (index != -1) {
      _allOrders[index] = order;
    } else {
      _allOrders.insert(0, order);
    }
    Future.microtask(notifyListeners);
  }

  /// Confirmer une commande
  Future<bool> confirmOrder(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.confirmee);
  }

  /// Commencer la préparation d'une commande
  Future<bool> startPreparingOrder(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.enPreparation);
  }

  /// Marquer une commande comme prête
  Future<bool> markOrderReady(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.prete);
  }

  /// Marquer une commande comme récupérée
  Future<bool> markOrderPickedUp(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.recuperee);
  }

  /// Marquer une commande comme en route
  Future<bool> markOrderOnTheWay(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.enRoute);
  }

  /// Marquer une commande comme livrée
  Future<bool> markOrderDelivered(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.livree);
  }

  /// Annuler une commande
  Future<bool> cancelOrderStatus(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.annulee);
  }

  /// Accepter une commande
  Future<bool> acceptOrder(String orderId) async {
    return await updateOrderStatus(orderId, StatutCommande.confirmee);
  }

  /// Refuser une commande
  /// Refuse une commande : c'est une annulation, avec son motif.
  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    final motif = reason?.trim();
    return cancelOrder(
      orderId,
      motif == null || motif.isEmpty ? 'Commande refusée' : motif,
    );
  }

  // `processRefund` a été retiré : il journalisait « remboursement non
  // branché » et rendait `false`, quel que soit le montant. Un remboursement
  // est un mouvement de paiement — il exige la transaction à rembourser et un
  // motif, que seul un écran peut collecter. Il vit dans `PaymentsService`,
  // appelé depuis la fiche d'une commande.

  /// Annule une commande — permission `orders.cancel`, motif obligatoire.
  ///
  /// Le motif n'est pas décoratif : l'opérateur annule la commande d'un tiers,
  /// qui sera remboursé et rappellera pour savoir pourquoi.
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final updated = await _orders.cancel(orderId: orderId, reason: reason);
      _replaceLocally(updated);
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: annulation refusée — ${e.code}');
      return false;
    }
  }

  /// Propose la course d'une commande à un livreur — permission
  /// `orders.assign_courier`.
  ///
  /// « Proposer » et non « assigner » : le livreur accepte ou refuse. L'ancienne
  /// version écrivait `delivery_person_id` sur la commande, ce qui affectait
  /// quelqu'un sans lui demander — et sans vérifier qu'il était en ligne ni son
  /// dossier validé.
  ///
  /// [courierId] est l'identifiant du **dossier livreur**, celui que rend
  /// `/delivery/couriers/`.
  Future<bool> assignDriver(String orderId, String courierId) async {
    try {
      await eccore.ManagedCourierRepository(apiClient: AdminAuthService().apiClient)
          .offer(orderId: orderId, courierId: courierId);
      await refresh();
      return true;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: affectation refusée — ${e.code}');
      return false;
    }
  }

  /// Filtrer les commandes par date
  List<eccore.Order> filterByDateRange(DateTime startDate, DateTime endDate) {
    return _allOrders.where((order) {
      return order.passeeLe.isAfter(startDate.subtract(const Duration(days: 1))) &&
          order.passeeLe.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Obtenir les commandes en attente
  List<eccore.Order> getPendingOrders() {
    return _allOrders.where((order) => order.statut == StatutCommande.enAttente).toList();
  }

  /// Obtenir les commandes par statut (filtre en mémoire)
  List<eccore.Order> getOrdersByStatus(StatutCommande status) {
    return _allOrders.where((order) => order.statut == status).toList();
  }

  /// Statuts d'une commande encore en cours — celle sur laquelle la
  /// supervision peut encore agir. Les terminales (livrée, annulée,
  /// remboursée, échouée) ne peuvent être ni urgentes ni en retard : leur
  /// sort est joué.
  static const Set<StatutCommande> _enCours = {
    StatutCommande.enAttente,
    StatutCommande.confirmee,
    StatutCommande.enPreparation,
    StatutCommande.prete,
    StatutCommande.recuperee,
    StatutCommande.enRoute,
  };

  /// Au-delà de ce délai sans être confirmée ni préparée, une commande est
  /// signalée. C'est un seuil d'attention pour l'exploitation, pas une règle
  /// métier : rien ne se décide sur ce chiffre côté serveur.
  static const Duration _delaiUrgence = Duration(minutes: 20);

  /// Commandes qui traînent en début de parcours.
  ///
  /// L'écran affichait un bandeau d'alerte alimenté par une liste vide écrite
  /// en dur : la section ne s'affichait jamais, et une commande oubliée en
  /// cuisine ne se voyait qu'en parcourant les onglets.
  List<eccore.Order> get urgentOrders => urgentAmong(_allOrders);

  /// Commandes en cours dont l'heure de livraison annoncée est dépassée.
  List<eccore.Order> get overdueOrders => overdueAmong(_allOrders);

  /// Sélection pure, exposée à part des accesseurs d'instance.
  ///
  /// [now] est un paramètre plutôt qu'un `DateTime.now()` interne : ce sont des
  /// règles **temporelles**, et une règle temporelle qui lit l'horloge en son
  /// sein ne se vérifie qu'en attendant. L'écran omet l'argument ; les tests le
  /// fournissent.
  static List<eccore.Order> urgentAmong(List<eccore.Order> orders, {DateTime? now}) {
    final maintenant = now ?? DateTime.now();
    return orders
        .where(
          (order) =>
              (order.statut == StatutCommande.enAttente ||
                  order.statut == StatutCommande.confirmee) &&
              maintenant.difference(order.passeeLe) > _delaiUrgence,
        )
        .toList()
      // La plus ancienne d'abord : c'est celle qui attend le plus.
      ..sort((a, b) => a.passeeLe.compareTo(b.passeeLe));
  }

  /// Commandes en cours dont l'heure de livraison annoncée est dépassée.
  ///
  /// Le délai annoncé vient de la zone (`estimated_delivery_minutes`), donc du
  /// serveur : le retard se mesure sur la promesse faite au client, et non sur
  /// une constante du back-office. Une commande sans heure annoncée n'est pas
  /// en retard — elle est seulement sans promesse, ce qui n'est pas la même
  /// chose et ne doit pas déclencher d'alerte.
  static List<eccore.Order> overdueAmong(List<eccore.Order> orders, {DateTime? now}) {
    final maintenant = now ?? DateTime.now();
    return orders
        .where(
          (order) =>
              _enCours.contains(order.statut) &&
              order.estimatedDeliveryAt != null &&
              maintenant.isAfter(order.estimatedDeliveryAt!),
        )
        .toList()
      ..sort(
        (a, b) => a.estimatedDeliveryAt!.compareTo(b.estimatedDeliveryAt!),
      );
  }

  // `loadOrdersByStatusFromDB` et `loadRecentOrdersFromDB` ont été retirées.
  //
  // Elles rechargeaient depuis le serveur ce que ce service tient déjà en
  // mémoire, et leurs deux appelants les invoquaient depuis une méthode
  // `build` : le futur était recréé à chaque reconstruction, donc à chaque
  // frappe dans le champ de recherche et à chaque notification. Les écrans
  // filtrent maintenant [allOrders], qui est la même donnée — et la même pour
  // les compteurs affichés au-dessus, ce qui n'était pas garanti quand les
  // deux venaient de requêtes distinctes.

  /// La **forme détaillée** d'une commande — ses lignes et ses transitions.
  ///
  /// Indispensable, et elle manquait. `GET /orders/manage/` rend la forme de
  /// liste, qui ne porte ni `lines` ni `status_events` (`OrderSerializer` vs
  /// `OrderDetailSerializer`). La fiche d'une commande recevait donc l'objet de
  /// la liste et affichait invariablement « Aucun article trouvé dans cette
  /// commande » — sur toutes les commandes, y compris celles de dix plats. Le
  /// back-office ne permettait pas de savoir ce qu'un client avait commandé.
  Future<eccore.Order?> loadDetail(String orderId) async {
    try {
      final detail = await _orders.getById(orderId);
      _replaceLocally(detail);
      return detail;
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace('OrderManagementService: fiche indisponible — ${e.code}');
      return null;
    }
  }

  /// Les [limit] commandes les plus récentes.
  Future<List<eccore.Order>> loadRecentOrdersFromDB({int limit = 5}) async {
    try {
      final remote = await _orders.list();
      return remote.take(limit).toList();
    } on eccore.ApiException catch (e) {
      eccore.Journal.trace(
          'OrderManagementService: commandes récentes indisponibles — ${e.code}',
          );
      return [];
    }
  }

  /// Obtenir les commandes d'aujourd'hui
  List<eccore.Order> getTodayOrders() {
    final today = DateTime.now();
    return _allOrders
        .where(
          (order) =>
              order.passeeLe.year == today.year &&
              order.passeeLe.month == today.month &&
              order.passeeLe.day == today.day,
        )
        .toList();
  }

  /// Obtenir les commandes de cette semaine
  List<eccore.Order> getThisWeekOrders() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return _allOrders
        .where(
          (order) =>
              order.passeeLe.isAfter(startOfWeek) && order.passeeLe.isBefore(endOfWeek),
        )
        .toList();
  }

  /// Obtenir les commandes de ce mois
  List<eccore.Order> getThisMonthOrders() {
    final now = DateTime.now();
    return _allOrders
        .where(
          (order) => order.passeeLe.year == now.year && order.passeeLe.month == now.month,
        )
        .toList();
  }

  // `searchOrders` a été retiré : il rendait une liste filtrée que son seul
  // appelant jetait (`service.searchOrders(value);`), si bien que la barre de
  // recherche de la supervision ne filtrait rien. La recherche est désormais
  // un état d'écran, appliqué là où la liste est construite — un service
  // partagé n'a pas à porter le champ de saisie d'un écran.

  /// Obtenir les statistiques des commandes
  Map<String, dynamic> getOrderStats() {
    final totalOrders = _allOrders.length;
    final pendingOrders =
        _allOrders.where((o) => o.statut == StatutCommande.enAttente).length;
    final confirmedOrders =
        _allOrders.where((o) => o.statut == StatutCommande.confirmee).length;
    final preparingOrders =
        _allOrders.where((o) => o.statut == StatutCommande.enPreparation).length;
    final readyOrders = _allOrders.where((o) => o.statut == StatutCommande.prete).length;
    final pickedUpOrders =
        _allOrders.where((o) => o.statut == StatutCommande.recuperee).length;
    final onTheWayOrders =
        _allOrders.where((o) => o.statut == StatutCommande.enRoute).length;
    final deliveredOrders =
        _allOrders.where((o) => o.statut == StatutCommande.livree).length;
    final cancelledOrders =
        _allOrders.where((o) => o.statut == StatutCommande.annulee).length;

    final totalRevenue = _allOrders
        .where((o) => o.statut == StatutCommande.livree)
        .fold(0.0, (sum, order) => sum + order.totalAffiche);

    final averageOrderValue = deliveredOrders > 0 ? totalRevenue / deliveredOrders : 0.0;

    return {
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'confirmed_orders': confirmedOrders,
      'preparing_orders': preparingOrders,
      'ready_orders': readyOrders,
      'picked_up_orders': pickedUpOrders,
      'on_the_way_orders': onTheWayOrders,
      'delivered_orders': deliveredOrders,
      'cancelled_orders': cancelledOrders,
      'total_revenue': totalRevenue.isNaN || totalRevenue.isInfinite ? 0.0 : totalRevenue,
      'average_order_value': averageOrderValue.isNaN || averageOrderValue.isInfinite
          ? 0.0
          : averageOrderValue,
    };
  }

  /// Recharger les données (méthode publique).
  ///
  /// Recharge **les deux** : la fenêtre agrégée si elle avait été lue, et la
  /// page affichée. C'est le geste du bouton « Recharger », et il doit rendre
  /// l'écran entier cohérent — pas seulement la moitié qu'on regarde.
  ///
  /// La fenêtre n'est pas chargée si elle ne l'avait jamais été : « recharger »
  /// ne doit pas déclencher un téléchargement d'un an que personne n'a demandé.
  Future<void> refresh() async {
    eccore.Journal.trace('🔄 Rafraîchissement manuel des commandes...');
    await Future.wait([
      if (_fenetreChargee) _loadAllOrders(),
      if (_page != null) reloadPage(),
    ]);
  }

  /// Obtenir les commandes nécessitant une attention
  List<eccore.Order> getOrdersNeedingAttention() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      // Commandes en attente depuis plus de 30 minutes
      if (order.statut == StatutCommande.enAttente) {
        final timeDiff = now.difference(order.passeeLe);
        if (timeDiff.inMinutes > 30) return true;
      }

      // Une annulation ne réclame l'attention que si de l'argent est déjà
      // passé : les espèces n'ont jamais quitté le client.
      if (order.statut == StatutCommande.annulee && order.moyenPaiement.estPrepaye) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Obtenir les commandes programmées
  List<eccore.Order> getScheduledOrders() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      return order.estimatedDeliveryAt != null && order.estimatedDeliveryAt!.isAfter(now);
    }).toList();
  }

  /// Obtenir les commandes en retard
  List<eccore.Order> getDelayedOrders() {
    final now = DateTime.now();
    return _allOrders.where((order) {
      if (order.estimatedDeliveryAt == null) return false;
      if (order.statut == StatutCommande.livree) return false;
      if (order.statut == StatutCommande.annulee) return false;

      return now.isAfter(order.estimatedDeliveryAt!);
    }).toList();
  }

  // `archiveOldOrders` a été retirée. Elle comptait les commandes anciennes,
  // écrivait le total dans le journal, expliquait en commentaire que « dans un
  // vrai système on pourrait déplacer ces commandes » — puis rendait `true`.
  // Un appelant en concluait que l'archivage avait eu lieu.

  /// Obtenir le résumé journalier
  Map<String, dynamic> getDailySummary(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayOrders = filterByDateRange(dayStart, dayEnd);

    final deliveredOrders = dayOrders.where((o) => o.statut == StatutCommande.livree);
    final revenue = deliveredOrders.fold(0.0, (sum, order) => sum + order.totalAffiche);
    final avgOrderValue =
        deliveredOrders.isNotEmpty ? revenue / deliveredOrders.length : 0.0;

    final statusBreakdown = <String, int>{};
    for (final order in dayOrders) {
      final statusName = order.statut.libelle;
      statusBreakdown[statusName] = (statusBreakdown[statusName] ?? 0) + 1;
    }

    return {
      'date': date.toIso8601String(),
      'total_orders': dayOrders.length,
      'completed_orders': deliveredOrders.length,
      'revenue': revenue,
      'average_order_value': avgOrderValue,
      'status_breakdown': statusBreakdown,
    };
  }

  /// Obtenir les tendances de commandes
  Map<String, dynamic> getOrderTrends({int days = 7}) {
    final List<Map<String, dynamic>> trends = [];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final summary = getDailySummary(date);
      trends.add(summary);
    }

    // Calculer les tendances
    final firstDay = trends.first;
    final lastDay = trends.last;

    // `trends` porte des `Map<String, dynamic>` : on type les quatre valeurs
    // lues plutôt que de calculer sur du `dynamic`, où une clé absente
    // n'échouerait qu'à l'exécution.
    final commandesDebut = firstDay['total_orders']! as num;
    final commandesFin = lastDay['total_orders']! as num;
    final revenuDebut = firstDay['revenue']! as num;
    final revenuFin = lastDay['revenue']! as num;

    final orderGrowth = commandesFin - commandesDebut;
    final revenueGrowth = revenuFin - revenuDebut;

    final orderGrowthPercent =
        commandesDebut > 0 ? (orderGrowth / commandesDebut) * 100 : 0.0;

    final revenueGrowthPercent =
        revenuDebut > 0 ? (revenueGrowth / revenuDebut) * 100 : 0.0;

    return {
      'trends': trends,
      'order_growth': orderGrowth,
      'revenue_growth': revenueGrowth,
      'order_growth_percent': orderGrowthPercent,
      'revenue_growth_percent': revenueGrowthPercent,
      'period_days': days,
    };
  }

  /// Obtenir les heures de pointe
  Map<String, dynamic> getPeakHours() {
    final hourCounts = <int, int>{};

    for (final order in _allOrders) {
      final hour = order.passeeLe.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    int peakHour = 0;
    int maxOrders = 0;

    hourCounts.forEach((hour, count) {
      if (count > maxOrders) {
        maxOrders = count;
        peakHour = hour;
      }
    });

    return {
      'peak_hour': peakHour,
      'peak_orders': maxOrders,
      'hour_distribution': hourCounts,
    };
  }

  /// Obtenir les produits les plus commandés
  Map<String, dynamic> getMostOrderedItems({int limit = 10}) {
    final itemCounts = <String, int>{};

    for (final order in _allOrders) {
      for (final item in order.lines) {
        itemCounts[item.itemName] = (itemCounts[item.itemName] ?? 0) + item.quantity;
      }
    }

    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'top_items': sortedItems
          .take(limit)
          .map(
            (e) => {
              'name': e.key,
              'quantity': e.value,
            },
          )
          .toList(),
    };
  }

  /// Statistiques de livraison, mesurées sur ce qui a **réellement** eu lieu.
  ///
  /// Ce bloc annonçait trois chiffres qu'il n'avait pas :
  ///
  /// * le « temps moyen de livraison » était `estimated_delivery_at − placed_at`,
  ///   c'est-à-dire le délai **promis** au client au moment de la commande. Il
  ///   ne bougeait pas d'un pouce quand les livraisons prenaient une heure de
  ///   plus, puisque c'est la promesse qu'il moyennait, jamais la réalité ;
  /// * le « taux de livraison à l'heure » comptait les commandes dont cette
  ///   même promesse tenait dans les 60 minutes — une propriété du barème de
  ///   zone, sans aucun rapport avec la ponctualité ;
  /// * les commandes sans heure annoncée étaient purement écartées du calcul,
  ///   ce qui flattait la moyenne au lieu de la laisser incomplète.
  ///
  /// Le serveur horodate la livraison (`delivered_at`, `apps/orders/models.py`)
  /// et le socle le lit. Le temps de livraison est donc `delivered_at −
  /// placed_at`, et la ponctualité se juge en comparant `delivered_at` à
  /// l'heure annoncée — ce qui est la définition du mot.
  Map<String, dynamic> getDeliveryStats() {
    // Une commande livrée sans horodatage de livraison ne peut rien mesurer :
    // on ne l'inclut ni au numérateur ni au dénominateur, plutôt que de lui
    // prêter une durée.
    final livrees = _allOrders
        .where((o) => o.statut == StatutCommande.livree && o.deliveredAt != null)
        .toList();

    if (livrees.isEmpty) {
      return const {
        'measured_orders': 0,
        'on_time_rate': 0.0,
        'on_time_measured': 0,
        'average_delivery_time': 0.0,
        'fastest_delivery': 0.0,
        'slowest_delivery': 0.0,
      };
    }

    var total = 0.0;
    var plusRapide = double.infinity;
    var plusLente = 0.0;

    for (final order in livrees) {
      final minutes = order.deliveredAt!.difference(order.passeeLe).inMinutes.toDouble();
      total += minutes;
      if (minutes < plusRapide) plusRapide = minutes;
      if (minutes > plusLente) plusLente = minutes;
    }

    // La ponctualité ne se juge que sur les commandes qui portaient une
    // promesse. Sans heure annoncée, il n'y a rien à tenir — et rien à manquer.
    final avecPromesse = livrees.where((o) => o.estimatedDeliveryAt != null).toList();
    final aLHeure =
        avecPromesse.where((o) => !o.deliveredAt!.isAfter(o.estimatedDeliveryAt!)).length;

    return {
      'measured_orders': livrees.length,
      'on_time_measured': avecPromesse.length,
      'on_time_rate': avecPromesse.isEmpty ? 0.0 : aLHeure * 100 / avecPromesse.length,
      'average_delivery_time': total / livrees.length,
      'fastest_delivery': plusRapide == double.infinity ? 0.0 : plusRapide,
      'slowest_delivery': plusLente,
    };
  }

  /// Chiffres de la section « Performance ».
  ///
  /// La « satisfaction client » qui s'y trouvait a disparu, et son remplacement
  /// n'est pas un autre calcul : elle n'en avait pas. C'était
  /// `(1 − taux d'annulation) × 0,7 + ponctualité × 0,3`, multiplié par cinq et
  /// affiché sous une étoile, sur cinq — la forme exacte d'une note de clients.
  /// Aucun client n'y avait rien noté. Les notes existent, sur le dossier des
  /// livreurs (`rating_average`, alimenté par `/delivery/orders/{id}/rating/`),
  /// et c'est l'écran de la flotte qui les affiche.
  ///
  /// À sa place, un chiffre que ces commandes portent vraiment : la part de ce
  /// qui a été annulé.
  Map<String, dynamic> getPerformanceStats() {
    final livraison = getDeliveryStats();
    final stats = getOrderStats();

    final total = stats['total_orders'] as int? ?? 0;
    final annulees = stats['cancelled_orders'] as int? ?? 0;

    return {
      'average_delivery_time': livraison['average_delivery_time'] ?? 0.0,
      'measured_orders': livraison['measured_orders'] ?? 0,
      'on_time_rate': livraison['on_time_rate'] ?? 0.0,
      'on_time_measured': livraison['on_time_measured'] ?? 0,
      'cancellation_rate': total == 0 ? 0.0 : annulees * 100 / total,
      'fastest_delivery': livraison['fastest_delivery'] ?? 0.0,
      'slowest_delivery': livraison['slowest_delivery'] ?? 0.0,
    };
  }
}
