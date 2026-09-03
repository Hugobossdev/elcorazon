import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/assignment_service.dart';
import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/dialogues/annulation_commande.dart';
import 'package:admin/presentation/dialogues/assignation_livreur.dart';
import 'package:admin/presentation/dialogues/changement_statut.dart';
import 'package:admin/presentation/barre_pagination.dart';
import 'package:admin/presentation/dialogues/contact_commande.dart';
import 'package:admin/presentation/dialogues/details_commande.dart';
import 'package:admin/presentation/filtres_supervision.dart';
import 'package:admin/presentation/export_commandes.dart';
import 'package:admin/presentation/onglets/statistiques_commandes.dart';
import 'package:admin/presentation/tri_commandes.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/ui/ui.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show AppEmoji;

/// La supervision des commandes — **le seul écran** qui la fasse.
///
/// Pourquoi cet écran a absorbé l'autre
/// ------------------------------------
///
/// Deux implémentations concurrentes coexistaient. Celle-ci, ouverte par le
/// menu ; et `order_management_screen`, atteignable seulement en cliquant un
/// résultat de la recherche transverse — laquelle ouvrait d'ailleurs la liste
/// entière plutôt que la commande cherchée.
///
/// Elles ne faisaient pas la même chose, et c'est le pire des cas : chacune
/// avait ce qui manquait à l'autre. Le remboursement, l'ouverture sur une
/// carte, l'appel au destinataire et l'export CSV n'existaient que dans la
/// seconde, c'est-à-dire nulle part où l'exploitation aille. Deux écrans qui
/// se ressemblent finissent par diverger ; deux écrans qui divergent
/// obligent à savoir lequel on regarde.
///
/// Ce qui a été repris de l'autre écran : la carte et l'appel au destinataire
/// (extraits dans `dialogues/contact_commande.dart`), l'export CSV (extrait
/// dans `presentation/export_commandes.dart`), et la fenêtre temporelle —
/// devenue un **filtre de requête** au lieu d'un filtre d'affichage.
///
/// Ce qui n'a **pas** été repris : le filtre par zone. Ses mots-clés étaient
/// des quartiers de Dakar (« Yoff », « Pikine », « Almadies ») alors que
/// l'établissement est à Lomé — deux de ses trois choix ne rendaient jamais
/// rien et le troisième rendait tout, ce que son propre commentaire
/// documentait. Il est remplacé par un filtre **par établissement**, qui part
/// au serveur (`restaurant__slug`) et filtre réellement.
class AdvancedOrderManagementScreen extends StatefulWidget {
  const AdvancedOrderManagementScreen({super.key});

  @override
  State<AdvancedOrderManagementScreen> createState() =>
      _AdvancedOrderManagementScreenState();
}

class _AdvancedOrderManagementScreenState extends State<AdvancedOrderManagementScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  /// La sélection courante — statut, recherche, fenêtre, établissement, tri.
  ///
  /// Une valeur unique et immuable plutôt que cinq champs épars : avec la
  /// pagination, changer un filtre doit à la fois repartir en page 1 et
  /// transmettre **tous** les autres termes. Les réunir rend les deux
  /// impossibles à oublier.
  FiltresCommandes _filtres = const FiltresCommandes();

  /// Anti-rebond de la recherche.
  ///
  /// La recherche part maintenant au serveur : émettre une requête par frappe
  /// enverrait six appels pour « Kodjo ». Trois cents millisecondes après la
  /// dernière touche, c'est une requête.
  Timer? _rebond;

  /// Commandes changées **hors** de la sélection affichée, signalées par le
  /// canal temps réel. Elles ne peuvent pas être insérées dans une page sans
  /// en rompre l'ordre et le compte : on les annonce, l'opérateur recharge.
  int _changementsHorsSelection = 0;

  StreamSubscription<ChangementDeStatut>? _abonnementChangements;
  StreamSubscription<void>? _abonnementReconnexions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onOngletChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Les courses en cours : c'est ce qui dit quelle commande a déjà un
      // porteur, donc si le bouton doit lire « Assigner » ou « Réassigner ».
      unawaited(context.read<AssignmentService>().refresh());
      unawaited(context.read<RestaurantScopeService>().resolve());
      unawaited(_recharger());
      _brancherLeTempsReel();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rebond?.cancel();
    unawaited(_abonnementChangements?.cancel());
    unawaited(_abonnementReconnexions?.cancel());
    _tabController
      ..removeListener(_onOngletChange)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Le canal se ferme quand l'application passe en arrière-plan, et se rouvre
  /// au retour.
  ///
  /// Un socket laissé ouvert derrière un écran verrouillé consomme pour des
  /// événements que personne ne lit ; et au retour, l'état local a vieilli —
  /// d'où le rechargement de la page, qui rattrape ce que la coupure a fait
  /// manquer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final temps = context.read<DashboardRealtimeService>();
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(temps.connect());
        unawaited(_recharger());
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(temps.disconnect());
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _brancherLeTempsReel() {
    final temps = context.read<DashboardRealtimeService>();

    _abonnementChangements = temps.changements.listen((changement) async {
      if (!mounted) return;
      // **Une commande relue, pas une page rechargée.** `applyStatusChange`
      // rend `false` quand la commande n'est pas affichée : elle est alors
      // hors de la sélection, et l'insérer romprait la pagination.
      final appliquee = await context
          .read<OrderManagementService>()
          .applyStatusChange(changement.orderId);
      if (!mounted) return;
      if (!appliquee) setState(() => _changementsHorsSelection++);
    });

    _abonnementReconnexions = temps.reconnexions.listen((_) {
      // À la reconnexion, des événements ont pu passer pendant la coupure.
      // Recharger la page est plus simple et plus juste que de rejouer un
      // historique sur une liste paginée.
      if (mounted) unawaited(_recharger());
    });

    unawaited(temps.connect());
  }

  void _onOngletChange() {
    if (!mounted || _tabController.indexIsChanging) return;
    final statut = _statutDeLOnglet(_tabController.index);

    // L'onglet **est** le filtre de statut : il part au serveur. Les cinq
    // onglets filtraient jusqu'ici la liste déjà chargée, ce qui obligeait à
    // la charger entière pour n'en montrer qu'un cinquième.
    _appliquer(
      _filtres.copyWith(statut: statut, effacerStatut: statut == null),
    );
  }

  /// Applique une nouvelle sélection.
  ///
  /// Ne relance une requête que si la **requête** change : modifier le tri,
  /// qui reste local à la page, ne doit pas rappeler le serveur.
  void _appliquer(FiltresCommandes filtres) {
    final memeRequete = _filtres.memeRequeteQue(filtres);
    setState(() => _filtres = filtres);
    if (!memeRequete) unawaited(_recharger());
  }

  /// Charge la première page de la sélection courante.
  Future<void> _recharger() async {
    if (!mounted) return;
    setState(() => _changementsHorsSelection = 0);
    await context.read<OrderManagementService>().loadPage(_filtres);
  }

  /// Recharge tout : la page **et** la fenêtre agrégée si elle est chargée.
  ///
  /// C'est ce que fait le bouton « Recharger », qui doit rendre l'écran entier
  /// cohérent et pas seulement la moitié qu'on regarde.
  Future<void> _rechargerTout() async {
    if (!mounted) return;
    setState(() => _changementsHorsSelection = 0);
    await Future.wait([
      context.read<OrderManagementService>().refresh(),
      context.read<AssignmentService>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    // Pas d'AppBar ici car il est déjà géré par AdminNavigationScreen
    // IMPORTANT: cette page peut être affichée dans une arborescence sans ancêtre Material.
    // Or certains widgets Material (TextField, etc.) l'exigent.
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          // Barre d'actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              boxShadow: [
                BoxShadow(
                  color: sem.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Référence, destinataire, téléphone, adresse…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _appliquer(_filtres.copyWith(recherche: ''));
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                    ),
                    // La recherche part au **serveur** : elle porte donc sur
                    // tout l'historique de la sélection et non sur la page
                    // affichée. Un filtre local aurait répondu « aucun
                    // résultat » là où il fallait lire « pas sur cette page ».
                    onChanged: (valeur) {
                      setState(() {});
                      _rebond?.cancel();
                      _rebond = Timer(
                        const Duration(milliseconds: 300),
                        () => _appliquer(_filtres.copyWith(recherche: valeur)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Consumer<DashboardRealtimeService>(
                  builder: (context, temps, child) => PastilleTempsReel(etat: temps.etat),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showFilterDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.filter_list),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _rechargerTout,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _exportOrders,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.download, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Les onglets, avec le nombre réel de commandes de chacun.
          //
          // `tabAlignment: TabAlignment.start` — sans lui, un `TabBar`
          // défilant laisse un décalage devant le premier onglet, et « Vue
          // d'ensemble » commençait hors du bord visible.
          //
          // Le libellé passe sous l'icône plutôt qu'à côté : sept onglets côte
          // à côte débordaient l'écran, et le dernier — « Prêtes » — était
          // coupé en deux. Le `TabBar` défile de toute façon ; ce qui change,
          // c'est qu'il faut beaucoup moins défiler.
          Container(
            color: scheme.surface,
            child: Consumer<OrderManagementService>(
              builder: (context, service, child) => TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: scheme.primary,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: [
                  for (final onglet in _onglets)
                    Tab(
                      icon: Icon(onglet.icone, size: 20),
                      // Le nombre n'apparaît que s'il est connu : « (0) »
                      // pendant le chargement annoncerait une file vide.
                      text: switch (onglet.statut) {
                        null => onglet.libelle,
                        final statut => switch (service.compteDe(statut)) {
                            null => onglet.libelle,
                            final n => '${onglet.libelle} ($n)',
                          },
                      },
                    ),
                ],
              ),
            ),
          ),
          // Ce qui a changé hors de la sélection affichée.
          BandeauNouveautes(
            nombre: _changementsHorsSelection,
            onRecharger: () => unawaited(_recharger()),
          ),
          // Contenu
          Expanded(
            child: Consumer<OrderManagementService>(
              builder: (context, orderService, child) {
                // **Deux régimes, et c'est voulu.**
                //
                // « Vue d'ensemble » et « Statistiques » raisonnent sur
                // l'ensemble : compteurs, alertes, chiffre d'affaires. Ils
                // lisent la fenêtre agrégée, chargée à la demande.
                //
                // Les cinq onglets de statut affichent une **liste qu'on
                // parcourt** : ils lisent une page, filtrée par le serveur.
                // Les faire lire la fenêtre agrégée obligeait à télécharger un
                // an de commandes pour en montrer vingt.
                final agregats = _tabController.index == 0 || _tabController.index == 6;
                if (agregats) {
                  return _OngletAgrege(
                    orderService: orderService,
                    statistiques: _tabController.index == 6,
                    construireVue: () => _buildOverviewTab(context, orderService),
                  );
                }

                return _buildListeCommandes(context, orderService);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// La liste paginée d'un onglet de statut.
  ///
  /// Les cinq onglets partageaient déjà une seule méthode ; ils partagent
  /// désormais aussi la pagination, le message de vide et l'erreur — il n'y a
  /// qu'un chemin, donc qu'un comportement à vérifier.
  Widget _buildListeCommandes(
    BuildContext context,
    OrderManagementService orderService,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final commandes = commandesAffichees(
      orderService.pageCourante,
      // La recherche est déjà faite par le serveur : la refaire ici
      // n'écarterait rien de plus et masquerait un écart de contrat.
      tri: _filtres.tri,
    );

    return Column(
      children: [
        if (orderService.pageErreur != null)
          _BandeauErreur(
            message: orderService.pageErreur!,
            onReessayer: () => unawaited(_recharger()),
          ),
        Expanded(
          child: orderService.pageEnCours && commandes.isEmpty
              ? const LoadingWidget(message: 'Chargement des commandes…')
              : commandes.isEmpty
                  ? _buildEmptyState(context, _messageVide())
                  : RefreshIndicator(
                      onRefresh: _recharger,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: commandes.length,
                        itemBuilder: (context, index) => _buildOrderCard(
                          context,
                          commandes[index],
                          orderService,
                        ),
                      ),
                    ),
        ),
        BarrePagination(
          numeroDePage: orderService.numeroDePage,
          nombreDePages: orderService.nombreDePages,
          total: orderService.totalFiltre,
          enCours: orderService.pageEnCours,
          onPrecedente: orderService.aPagePrecedente
              ? () => unawaited(orderService.previousPage())
              : null,
          onSuivante: orderService.aPageSuivante
              ? () => unawaited(orderService.nextPage())
              : null,
        ),
        if (_filtres.actifs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: Text(
                'Effacer les filtres (${_filtres.nombreActifs})',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              onPressed: () {
                _searchController.clear();
                _appliquer(
                  FiltresCommandes(statut: _statutDeLOnglet(_tabController.index)),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Ce qu'on affiche quand la sélection ne rend rien.
  ///
  /// Distingue « aucune commande à cette étape » de « aucune ne correspond à
  /// la recherche » : les deux se corrigent différemment, et un message unique
  /// enverrait chercher au mauvais endroit.
  String _messageVide() {
    if (_filtres.recherche.trim().isNotEmpty) {
      return 'Aucune commande ne correspond à « ${_filtres.recherche.trim()} »';
    }
    if (_filtres.fenetre != FenetreCommandes.toutes) {
      return 'Aucune commande sur cette étape pour la période choisie '
          '(${_filtres.fenetre.libelle.toLowerCase()}).';
    }
    return 'Aucune commande à cette étape.';
  }

  Widget _buildOverviewTab(
    BuildContext context,
    OrderManagementService orderService,
  ) {
    final stats = orderService.getOrderStats();
    final urgentOrders = orderService.urgentOrders;
    final overdueOrders = orderService.overdueOrders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques principales
          _buildStatsGrid(context, stats),
          const SizedBox(height: 20),

          // Alertes
          if (urgentOrders.isNotEmpty || overdueOrders.isNotEmpty) ...[
            _buildAlertsSection(context, urgentOrders, overdueOrders),
            const SizedBox(height: 20),
          ],

          // Commandes récentes
          _buildRecentOrdersSection(context, orderService),
          const SizedBox(height: 20),

          // Performance
          _buildPerformanceSection(context, orderService),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          context,
          'Total commandes',
          '${stats['total_orders'] ?? 0}',
          Icons.receipt_long,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatCard(
          context,
          'En attente',
          '${stats['pending_orders'] ?? 0}',
          Icons.pending,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).warning,
        ),
        _buildStatCard(
          context,
          'En préparation',
          '${stats['preparing_orders'] ?? 0}',
          Icons.restaurant,
          Theme.of(context).colorScheme.tertiary,
        ),
        _buildStatCard(
          context,
          'Livrées',
          '${stats['delivered_orders'] ?? 0}',
          Icons.check_circle,
          AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
        ),
        _buildStatCard(
          context,
          'Revenus totaux',
          PriceFormatter.format(
            (stats['total_revenue'] as num?)?.toDouble() ?? 0.0,
          ),
          Icons.monetization_on,
          Theme.of(context).colorScheme.secondary,
        ),
        _buildStatCard(
          context,
          'Panier moyen',
          PriceFormatter.format(
            (stats['average_order_value'] as num?)?.toDouble() ?? 0.0,
          ),
          Icons.shopping_cart,
          Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(
    BuildContext context,
    List<eccore.Order> urgentOrders,
    List<eccore.Order> overdueOrders,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: sem.danger),
                const SizedBox(width: 8),
                Text(
                  'Alertes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sem.danger,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (urgentOrders.isNotEmpty) ...[
              Text(
                '${urgentOrders.length} commande(s) urgente(s)',
                style: TextStyle(color: sem.danger),
              ),
              const SizedBox(height: 4),
            ],
            if (overdueOrders.isNotEmpty) ...[
              Text(
                '${overdueOrders.length} commande(s) en retard',
                style: TextStyle(color: sem.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Les cinq commandes les plus récentes.
  ///
  /// Prises dans la liste en mémoire, qui arrive déjà triée par le serveur
  /// (`-placed_at`). Cette section appelait `loadRecentOrdersFromDB()` depuis
  /// son `builder` : un aller-retour réseau complet à chaque reconstruction de
  /// l'onglet, pour cinq lignes qu'on avait sous la main.
  Widget _buildRecentOrdersSection(
    BuildContext context,
    OrderManagementService orderService,
  ) {
    final recentes = orderService.allOrders.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commandes récentes',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recentes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucune commande récente'),
                ),
              )
            else
              ...recentes.map(
                (order) => _buildOrderListItem(context, order, orderService),
              ),
          ],
        ),
      ),
    );
  }

  /// Ce que ces commandes disent de l'exploitation.
  ///
  /// Trois chiffres, et les trois se lisent maintenant dans les données. La
  /// version précédente affichait « Satisfaction : 4.2/5 » sous une étoile, à
  /// partir d'une formule interne — aucune note de client n'entrait dans ce
  /// nombre. Les notes existent bien, sur le dossier des livreurs, et c'est
  /// l'écran de la flotte qui les montre.
  ///
  /// Le nombre de commandes mesurées est affiché avec la moyenne : « 34 min »
  /// sur deux livraisons et « 34 min » sur six cents ne se lisent pas de la
  /// même façon, et l'opérateur n'a aucun moyen de deviner lequel il regarde.
  Widget _buildPerformanceSection(
    BuildContext context,
    OrderManagementService orderService,
  ) {
    final stats = orderService.getPerformanceStats();
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final mesurees = stats['measured_orders'] as int? ?? 0;
    final ponctualite = stats['on_time_measured'] as int? ?? 0;
    final moyenne = (stats['average_delivery_time'] as num?)?.toDouble() ?? 0.0;
    final tauxALHeure = (stats['on_time_rate'] as num?)?.toDouble() ?? 0.0;
    final tauxAnnulation = (stats['cancellation_rate'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    mesurees == 0
                        ? 'Temps de livraison'
                        : 'Temps moyen · $mesurees livraison(s)',
                    mesurees == 0 ? '—' : '${moyenne.round()} min',
                    Icons.timer,
                    scheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    ponctualite == 0
                        ? 'Livraison à temps'
                        : 'À temps · $ponctualite annoncée(s)',
                    ponctualite == 0 ? '—' : '${tauxALHeure.toStringAsFixed(0)} %',
                    Icons.schedule,
                    sem.success,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceItem(
                    context,
                    'Annulations',
                    '${tauxAnnulation.toStringAsFixed(1)} %',
                    Icons.cancel_outlined,
                    sem.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mesurees == 0
                  ? 'Aucune livraison horodatée sur la période : ces '
                      'chiffres apparaîtront dès la première commande livrée.'
                  : "Mesuré sur l'écart entre l'heure de commande et l'heure de "
                      'livraison enregistrée par le serveur.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // `_buildOrdersTab` et `_buildOrdersList` ont disparu avec la pagination :
  // le premier filtrait la fenêtre agrégée par statut, le second appliquait la
  // recherche à la liste ainsi obtenue. Les deux gestes sont maintenant faits
  // par le serveur, et `_buildListeCommandes` affiche ce qu'il rend.

  Widget _buildOrderCard(
    BuildContext context,
    eccore.Order order,
    OrderManagementService orderService,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleurDeStatut(order.statut, Theme.of(context).colorScheme)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.statut.libelle,
                    style: TextStyle(
                      color: couleurDeStatut(order.statut, Theme.of(context).colorScheme),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  PriceFormatter.format(order.totalAffiche),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // La **référence** et non huit caractères d'UUID : c'est le
              // numéro que le client donne au téléphone, celui du ticket, et
              // celui que la recherche trouve. `#01A01534` ne se dicte pas.
              order.reference.isEmpty
                  ? 'Commande ${order.id.substring(0, 8).toUpperCase()}'
                  : 'Commande ${order.reference}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              // Le compteur vient du **serveur** (`items_count`), pas de la
              // longueur de `lines` : la forme liste ne porte pas les lignes,
              // si bien que toutes les commandes affichaient « 0 article ».
              //
              // C'est la somme des quantités : deux burgers et une pizza font
              // trois articles, pas deux lignes.
              '${order.itemsCount} article${order.itemsCount > 1 ? 's' : ''}'
              ' • ${heureCommande(order.passeeLe)}'
              ' • ${ancienneteCommande(order.passeeLe)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            _DestinataireEtPorteur(order: order),
            const SizedBox(height: 8),

            Text(
              order.adresseComplete,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _ActionsCommande(order: order, orderService: orderService),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(
    BuildContext context,
    eccore.Order order,
    OrderManagementService orderService,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: couleurDeStatut(order.statut, Theme.of(context).colorScheme)
            .withValues(alpha: 0.1),
        // Décorative : le libellé de l'étape est dans le sous-titre.
        child: AppEmoji(
          order.statut.illustration,
          size: AppEmoji.tailleXS,
          decoratif: true,
        ),
      ),
      title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
      subtitle: Text(
        '${order.statut.libelle} • ${PriceFormatter.format(order.totalAffiche)}',
      ),
      trailing: Text(ancienneteCommande(order.passeeLe)),
      onTap: () => afficherDetailsCommande(context, order),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // Méthode _showSearchDialog supprimée car la recherche est maintenant intégrée directement dans l'interface

  /// Les filtres qui ne tiennent pas dans la barre : période, établissement,
  /// tri, taille de page.
  ///
  /// Le statut n'y est pas — les onglets **sont** le filtre de statut, et un
  /// second filtre global, invisible depuis l'onglet courant, ne pouvait que
  /// le contredire.
  void _showFilterDialog() {
    final perimetre = context.read<RestaurantScopeService>();

    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void poser(FiltresCommandes filtres) {
            setDialogState(() {});
            _appliquer(filtres);
          }

          return AlertDialog(
            title: const Text('Filtrer et trier'),
            content: SizedBox(
              width: (MediaQuery.of(context).size.width * 0.9).clamp(320.0, 460.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<FenetreCommandes>(
                      initialValue: _filtres.fenetre,
                      decoration: const InputDecoration(
                        labelText: 'Période',
                        helperText: 'Bornée côté serveur : la pagination porte '
                            'sur cette période.',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final fenetre in FenetreCommandes.values)
                          DropdownMenuItem(
                            value: fenetre,
                            child: Text(fenetre.libelle),
                          ),
                      ],
                      onChanged: (fenetre) {
                        if (fenetre != null) {
                          poser(_filtres.copyWith(fenetre: fenetre));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Le filtre par établissement remplace l'ancien « filtre
                    // par zone », dont les mots-clés étaient des quartiers de
                    // Dakar pour un restaurant de Lomé. Celui-ci part au
                    // serveur et filtre réellement.
                    if (perimetre.hasChoice) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: _filtres.restaurantSlug,
                        decoration: const InputDecoration(
                          labelText: 'Établissement',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            child: Text('Tout mon périmètre'),
                          ),
                          for (final etablissement in perimetre.restaurants)
                            DropdownMenuItem(
                              value: etablissement.slug,
                              child: Text(etablissement.name),
                            ),
                        ],
                        onChanged: (slug) => poser(
                          _filtres.copyWith(
                            restaurantSlug: slug,
                            effacerRestaurant: slug == null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<TriCommandes>(
                      initialValue: _filtres.tri,
                      decoration: const InputDecoration(
                        labelText: 'Trier',
                        helperText: 'Le tri porte sur la page affichée.',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final option in TriCommandes.values)
                          DropdownMenuItem(
                            value: option,
                            child: Text(option.libelle),
                          ),
                      ],
                      onChanged: (option) {
                        if (option != null) poser(_filtres.copyWith(tri: option));
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _filtres.taillePage,
                      decoration: const InputDecoration(
                        labelText: 'Commandes par page',
                        border: OutlineInputBorder(),
                      ),
                      // 100 est le plafond du serveur (`max_page_size`) :
                      // proposer davantage ferait afficher une page plus
                      // petite que celle qu'on a demandée.
                      items: const [
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: (taille) {
                        if (taille != null) {
                          poser(_filtres.copyWith(taillePage: taille));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  poser(
                    FiltresCommandes(
                      statut: _statutDeLOnglet(_tabController.index),
                    ),
                  );
                },
                child: const Text('Tout effacer'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Exporte les commandes de l'onglet courant, telles qu'elles sont affichées.
  ///
  /// Ce bouton affichait « Export des commandes en cours… » et rendait la main
  /// sans rien produire : ni fichier, ni presse-papier, ni requête. Le bandeau
  /// annonçait un travail qui n'était pas engagé, et l'opérateur attendait un
  /// téléchargement qui n'arrivait jamais.
  ///
  /// L'export porte sur ce que l'écran montre — recherche et tri compris — et
  /// non sur toute la base : c'est la sélection que l'opérateur vient de
  /// composer qu'il veut dans son tableur.
  Future<void> _exportOrders() async {
    final service = context.read<OrderManagementService>();
    // La page affichée, dans l'ordre affiché. Exporter tout l'historique
    // depuis un bouton silencieux relancerait les centaines de requêtes que la
    // pagination vient d'éviter ; l'opérateur qui veut plus élargit sa fenêtre
    // ou sa taille de page, et le voit.
    final commandes = commandesAffichees(
      service.pageCourante,
      tri: _filtres.tri,
    );

    if (commandes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande à exporter.')),
      );
      return;
    }

    // Le presse-papier plutôt qu'un fichier : cela fonctionne sur les six
    // plateformes sans paquet supplémentaire, sans chemin à choisir sur bureau
    // et sans permission d'écriture sur mobile.
    await Clipboard.setData(ClipboardData(text: commandesEnCsv(commandes)));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${commandes.length} commande(s) copiée(s) au format CSV — '
          'collez dans un tableur.',
        ),
        backgroundColor: AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
      ),
    );
  }

  /// Les sept onglets, dans l'ordre du service.
  ///
  /// Une table plutôt que sept `Tab` littéraux et un `switch` séparé : les
  /// deux devaient rester d'accord sur l'ordre, et rien ne l'imposait — un
  /// onglet inséré au milieu aurait filtré sur le statut du voisin.
  static const List<_Onglet> _onglets = [
    _Onglet('Vue d’ensemble', Icons.dashboard, null),
    _Onglet('En attente', Icons.pending, StatutCommande.enAttente),
    _Onglet('Confirmées', Icons.verified, StatutCommande.confirmee),
    _Onglet('En préparation', Icons.restaurant, StatutCommande.enPreparation),
    _Onglet('Prêtes', Icons.check_circle, StatutCommande.prete),
    _Onglet('En livraison', Icons.delivery_dining, StatutCommande.enRoute),
    _Onglet('Statistiques', Icons.analytics, null),
  ];

  static StatutCommande? _statutDeLOnglet(int index) => switch (index) {
        1 => StatutCommande.enAttente,
        2 => StatutCommande.confirmee,
        3 => StatutCommande.enPreparation,
        4 => StatutCommande.prete,
        5 => StatutCommande.enRoute,
        _ => null,
      };
}

/// Les gestes possibles sur une commande, **tels que le serveur les déclare**.
///
/// Les boutons étaient codés en dur, un `if` par statut : « En attente » →
/// Confirmer, « Confirmée » → Préparer, et ainsi de suite. Trois choses en
/// découlaient :
///
/// * la table des transitions vivait à deux endroits — dans
///   `apps/orders/states.py` et dans cette suite de conditions — et rien ne les
///   tenait d'accord. Le serveur rend pourtant `allowed_transitions` sur chaque
///   commande, précisément pour que le client n'ait pas à la recopier ;
/// * il n'y avait **aucun moyen d'annuler une commande** depuis l'écran des
///   commandes. `cancelOrder` existait dans le service, avec sa permission et
///   son motif obligatoire, et aucun bouton ne l'appelait — un opérateur
///   découvrant une rupture en cuisine n'avait rien à cliquer ;
/// * une commande récupérée ou en route n'offrait rien du tout, y compris quand
///   le serveur acceptait encore une étape.
///
/// L'annulation est **séparée** des autres transitions parce que le serveur la
/// sépare : elle exige `orders.cancel`, un motif, et passe par sa propre route.
/// La mélanger aux étapes d'avancement ferait d'`orders.update_status` un droit
/// d'annuler.
class _ActionsCommande extends StatefulWidget {
  const _ActionsCommande({required this.order, required this.orderService});

  final eccore.Order order;
  final OrderManagementService orderService;

  @override
  State<_ActionsCommande> createState() => _ActionsCommandeState();
}

class _ActionsCommandeState extends State<_ActionsCommande> {
  /// Le geste en cours, ou `null`.
  ///
  /// **Un seul à la fois, et c'est ce qui empêche le double clic.** Un
  /// opérateur pressé cliquait « Confirmer » deux fois : la seconde requête
  /// partait sur une commande déjà confirmée et revenait en 409, avec un
  /// bandeau d'erreur sur un geste qui venait pourtant de réussir.
  ///
  /// Porté par la carte plutôt que par l'écran : confirmer une commande ne
  /// doit pas figer les dix-neuf autres lignes de la page.
  String? _gesteEnCours;

  eccore.Order get order => widget.order;
  OrderManagementService get orderService => widget.orderService;

  /// Exécute un geste en tenant le verrou, quoi qu'il arrive.
  ///
  /// Le `finally` compte : sans lui, un refus du serveur laisserait le bouton
  /// désactivé pour toujours, et la commande deviendrait intouchable jusqu'au
  /// rechargement de l'écran.
  Future<void> _executer(String cle, Future<void> Function() geste) async {
    if (_gesteEnCours != null) return;
    setState(() => _gesteEnCours = cle);
    try {
      await geste();
    } finally {
      if (mounted) setState(() => _gesteEnCours = null);
    }
  }

  /// Les étapes qu'on fait avancer depuis cet écran.
  ///
  /// **Toutes** celles que le serveur accepte, y compris les trois dernières.
  /// Elles appartiennent au livreur, qui les horodate depuis son application au
  /// moment où elles ont lieu — mais le back-office doit pouvoir les poser
  /// quand ce chemin est coupé : un téléphone déchargé, une application
  /// désinstallée, un livreur qui rentre sans avoir clos sa course. Les retirer
  /// laisserait la commande bloquée sans autre issue que l'annulation, qui
  /// dirait le contraire de ce qui s'est passé.
  ///
  /// Ce que l'écran fait, en revanche, c'est **les distinguer** : elles portent
  /// une couleur neutre et un message de confirmation qui rappelle à qui elles
  /// reviennent normalement (voir [_messageDAvancement]).
  static const Map<String, StatutCommande> _avancement = {
    'confirmed': StatutCommande.confirmee,
    'preparing': StatutCommande.enPreparation,
    'ready': StatutCommande.prete,
    'picked_up': StatutCommande.recuperee,
    'on_the_way': StatutCommande.enRoute,
    'delivered': StatutCommande.livree,
  };

  /// Les étapes que le livreur pose d'ordinaire lui-même.
  static const _etapesDuLivreur = {
    StatutCommande.recuperee,
    StatutCommande.enRoute,
    StatutCommande.livree,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    final etapes = [
      for (final cible in order.allowedTransitions)
        if (_avancement[cible] case final statut?) statut,
    ];
    final annulable = order.allowedTransitions.contains('cancelled');
    final aAffecter = order.statut == StatutCommande.prete;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 130,
          child: CustomButton(
            text: 'Voir détails',
            onPressed: () => afficherDetailsCommande(context, order),
            variant: ButtonVariant.outlined,
            height: 36,
          ),
        ),
        // Les deux gestes qui n'existaient que dans l'écran secondaire, celui
        // qu'aucune entrée de menu n'ouvrait. Ce sont exactement ceux dont on a
        // besoin quand une livraison coince.
        IconButton.outlined(
          icon: const Icon(Icons.map_outlined, size: 18),
          tooltip: 'Situer sur une carte',
          onPressed: () => unawaited(situerLaCommande(context, order)),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.phone_outlined, size: 18),
          // Désactivé plutôt que muet : un bouton qui répond « aucun numéro »
          // après le clic fait croire à une panne. Son infobulle dit pourquoi.
          tooltip: order.recipientPhone.isEmpty
              ? 'Aucun numéro sur cette commande'
              : 'Appeler ${order.recipientPhone}',
          onPressed: order.recipientPhone.isEmpty
              ? null
              : () => unawaited(contacterLeDestinataire(context, order)),
        ),
        for (final statut in etapes)
          SizedBox(
            width: 150,
            child: CustomButton(
              text: _libelleDAvancement(statut),
              isLoading: _gesteEnCours == statut.versServeur,
              // `null` désactive le bouton pendant qu'un autre geste tourne :
              // c'est ce qui empêche « Confirmer » puis « Annuler » en rafale
              // sur la même commande.
              onPressed: _gesteEnCours != null
                  ? null
                  : () => unawaited(
                        _executer(
                          statut.versServeur,
                          () => confirmerChangementStatut(
                            context: context,
                            order: order,
                            nouveauStatut: statut,
                            orderService: orderService,
                            message: _messageDAvancement(statut),
                          ),
                        ),
                      ),
              color: switch (statut) {
                StatutCommande.confirmee => sem.success,
                StatutCommande.prete => sem.warning,
                // Neutres : ce sont les étapes du livreur, posées ici par
                // exception. Les colorer comme le geste courant inviterait à
                // les cliquer par habitude.
                _ when _etapesDuLivreur.contains(statut) => scheme.onSurfaceVariant,
                _ => scheme.primary,
              },
              height: 36,
            ),
          ),
        if (aAffecter)
          SizedBox(
            width: 170,
            child: Consumer2<DriverManagementService, AssignmentService>(
              builder: (context, driverService, assignments, child) {
                final porteur = assignments.courierNameOf(order.id);
                return CustomButton(
                  text: porteur == null ? 'Assigner livreur' : 'Réassigner',
                  isLoading: _gesteEnCours == 'assign',
                  onPressed: _gesteEnCours != null
                      ? null
                      : () => unawaited(
                    afficherAssignationLivreur(
                      context: context,
                      order: order,
                      orderService: orderService,
                      driverService: driverService,
                    ).then((_) {
                      if (context.mounted) {
                        unawaited(context.read<AssignmentService>().refresh());
                      }
                    }),
                  ),
                  color: scheme.primary,
                  height: 36,
                );
              },
            ),
          ),
        if (annulable)
          SizedBox(
            width: 120,
            child: CustomButton(
              text: 'Annuler',
              isLoading: _gesteEnCours == 'cancelled',
              onPressed: _gesteEnCours != null
                  ? null
                  : () => unawaited(
                        _executer(
                          'cancelled',
                          () => annulerCommande(
                            context: context,
                            order: order,
                            orderService: orderService,
                          ),
                        ),
                      ),
              color: sem.danger,
              height: 36,
            ),
          ),
      ],
    );
  }

  static String _libelleDAvancement(StatutCommande statut) => switch (statut) {
        StatutCommande.confirmee => 'Confirmer',
        StatutCommande.enPreparation => 'Préparer',
        StatutCommande.prete => 'Marquer prête',
        StatutCommande.recuperee => 'Marquer récupérée',
        StatutCommande.enRoute => 'Marquer en route',
        StatutCommande.livree => 'Marquer livrée',
        _ => statut.libelle,
      };

  static String _messageDAvancement(StatutCommande statut) => switch (statut) {
        StatutCommande.confirmee =>
          'Voulez-vous confirmer cette commande ?\n\nElle passe en file de '
              'préparation et le client en est averti.',
        StatutCommande.enPreparation =>
          'Voulez-vous lancer la préparation ?\n\nLa cuisine engage les '
              'denrées à partir de maintenant.',
        StatutCommande.prete =>
          'Voulez-vous marquer cette commande comme prête ?\n\nElle devient '
              'proposable à un livreur.',
        StatutCommande.recuperee ||
        StatutCommande.enRoute ||
        StatutCommande.livree =>
          'Cette étape est normalement posée par le livreur, depuis son '
              'application, au moment où elle a lieu.\n\nNe la posez ici que si '
              'ce chemin est coupé — téléphone déchargé, course close en '
              'retard. L'
              'horodatage enregistré sera celui de maintenant.',
        _ => 'Confirmez le changement de statut.',
      };
}

/// Un onglet qui raisonne sur **l'ensemble** et non sur une page.
///
/// « Vue d'ensemble » et « Statistiques » comptent, moyennent et alertent : ils
/// ont besoin de la fenêtre agrégée, que le service ne charge plus au
/// démarrage. Ce widget la demande à son montage — c'est le seul endroit d'où
/// elle est réclamée, ce qui garantit qu'ouvrir la liste des commandes ne la
/// déclenche pas.
///
/// Il distingue « pas encore chargé » de « zéro commande ». Les deux donnent
/// des compteurs à zéro, et un seul mérite un indicateur : afficher « 0
/// commande, 0 F CFA » pendant le chargement fait croire à une journée vide.
class _OngletAgrege extends StatefulWidget {
  const _OngletAgrege({
    required this.orderService,
    required this.statistiques,
    required this.construireVue,
  });

  final OrderManagementService orderService;

  /// `true` pour l'onglet « Statistiques », `false` pour « Vue d'ensemble ».
  final bool statistiques;

  final Widget Function() construireVue;

  @override
  State<_OngletAgrege> createState() => _OngletAgregeState();
}

class _OngletAgregeState extends State<_OngletAgrege> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.orderService.ensureWindowLoaded());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.orderService;

    if (!service.fenetreChargee) {
      return LoadingWidget(
        message: service.isLoading
            ? 'Chargement de la période de supervision…'
            : 'Préparation…',
      );
    }

    return SizedBox.expand(
      child: widget.statistiques
          ? OngletStatistiques(orderService: service)
          : widget.construireVue(),
    );
  }
}

/// L'erreur d'une page, affichée **au-dessus** de la liste et non à sa place.
///
/// La page précédente reste lisible : la vider sur une coupure réseau ferait
/// disparaître un service en cours sous les yeux de l'opérateur, au moment
/// précis où il en a besoin.
class _BandeauErreur extends StatelessWidget {
  const _BandeauErreur({required this.message, required this.onReessayer});

  final String message;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

/// Qui reçoit la commande, et qui la porte.
///
/// Pourquoi ce bloc existe
/// -----------------------
///
/// La carte affichait le statut, le montant et l'adresse — et **pas le nom du
/// client**, alors que `recipient_name` et `recipient_phone` sont sur la
/// commande depuis le premier jour. Un opérateur qui voulait savoir qui
/// attendait devait ouvrir la fiche.
///
/// Le livreur vient de la course, pas de la commande : `AssignmentService` les
/// charge toutes en un appel, et cette carte y lit la sienne sans requête
/// supplémentaire. `apps.orders` ne dépend pas d'`apps.delivery` (ADR-002), la
/// commande ne saura donc jamais qui la livre.
class _DestinataireEtPorteur extends StatelessWidget {
  const _DestinataireEtPorteur({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return Consumer<AssignmentService>(
      builder: (context, courses, child) {
        final porteur = courses.courierNameOf(order.id);

        return Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Info(
              icone: Icons.person_outline,
              // « Destinataire non renseigné » et non un nom inventé : on
              // commande pour un collègue, pour ses parents, et le champ peut
              // rester vide.
              texte: order.recipientName.isEmpty
                  ? 'Destinataire non renseigné'
                  : order.recipientName,
              style: style,
            ),
            if (order.recipientPhone.isNotEmpty)
              _Info(
                icone: Icons.phone_outlined,
                texte: order.recipientPhone,
                style: style,
              ),
            _Info(
              icone: order.moyenPaiement.icone,
              texte: order.moyenPaiement.libelle,
              style: style,
            ),
            // Le livreur n'apparaît que s'il y en a un : une ligne « Livreur :
            // — » sur chaque commande en attente n'apprend rien et allonge la
            // carte.
            if (porteur != null)
              _Info(
                icone: Icons.delivery_dining_outlined,
                texte: porteur,
                style: style?.copyWith(
                  color: AdminColorTokens.semantic(scheme).success,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Une icône et son texte, qui ne débordent pas.
class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.texte, this.style});

  final IconData icone;
  final String texte;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: style?.color),
        const SizedBox(width: 4),
        // Borné : une adresse ou un nom très long pousserait la ligne hors de
        // la carte, et un `Wrap` ne coupe pas un enfant trop large — il le
        // laisse déborder.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            texte,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Un onglet de la supervision : son libellé, son icône, son statut.
///
/// [statut] vaut `null` pour les deux onglets qui ne filtrent pas — « Vue
/// d'ensemble » et « Statistiques » — ce qui est exactement la condition qui
/// décide s'ils affichent un compteur.
class _Onglet {
  const _Onglet(this.libelle, this.icone, this.statut);

  final String libelle;
  final IconData icone;
  final StatutCommande? statut;
}
