import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/widgets/loading_widget.dart';
import 'package:admin/dialogs/notifications_dialog.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/screens/admin/admin_dashboard_screen.dart';
import 'package:admin/screens/admin/admin_roles_screen.dart';
import 'package:admin/screens/admin/advanced_order_management_screen.dart';
import 'package:admin/screens/admin/driver_management_screen.dart';
import 'package:admin/screens/admin/analytics_screen.dart';
import 'package:admin/screens/admin/category_management_screen.dart';
import 'package:admin/screens/admin/customization_management_screen.dart';
import 'package:admin/screens/admin/menu_management_screen.dart';
import 'package:admin/screens/admin/payments_screen.dart';
import 'package:admin/screens/admin/versements/remboursements_screen.dart';
import 'package:admin/screens/admin/versements/retraits_livreurs_screen.dart';
import 'package:admin/screens/admin/reseau/reseau_screen.dart';
import 'package:admin/screens/admin/selecteur_etablissement.dart';
import 'package:admin/screens/admin/marketing_screen.dart';
import 'package:admin/screens/admin/promotions_screen.dart';
import 'package:admin/screens/admin/gamification_management_screen.dart';
import 'package:admin/screens/admin/client_management_screen.dart';
import 'package:admin/screens/admin/avis_clients_screen.dart';
import 'package:admin/screens/admin/journal_audit_screen.dart';
import 'package:admin/screens/admin/service_client_screen.dart';
import 'package:admin/screens/admin/settings_screen.dart';
import 'package:admin/screens/admin/driver_map_screen.dart';
import 'package:admin/screens/admin/global_search_screen.dart';
import 'package:admin/screens/admin/active_deliveries_screen.dart';
import 'package:admin/screens/admin/driver_documents_dashboard_screen.dart';
import 'package:admin/screens/inventaire/ingredients_screen.dart';
import 'package:admin/screens/inventaire/recettes_screen.dart';
import 'package:admin/screens/inventaire/stock_screen.dart';
import 'package:admin/screens/inventaire/validations_screen.dart';
import 'package:admin/screens/kitchen/kitchen_screen.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/services/notification_center_service.dart';

/// Ce que le poste de cuisine affiche quand aucun établissement n'est résolu.
///
/// Les causes sont distinctes, et les confondre est le défaut constaté le
/// 21 septembre 2026 : le 403 d'un « Opérateur » sur la liste de gestion se
/// lisait « Aucun établissement rattaché », et il cherchait qui devait le
/// rattacher alors qu'il l'était déjà.
///
/// * **En cours de lecture** — le périmètre arrive, il n'y a rien à faire.
/// * **Échec** — sa nature ([NatureEchec]) choisit le titre et le geste :
///   « Réessayer » seulement devant une panne, jamais devant un refus.
/// * **Vide** — le compte ne supervise aucun établissement. Réessayer n'y
///   changera rien, et c'est au siège de rattacher la personne.
class _CuisineSansEtablissement extends StatelessWidget {
  const _CuisineSansEtablissement({this.quoi = 'le poste puisse afficher un service'});

  /// Ce que l'écran ne peut pas montrer sans établissement — la fin de la
  /// phrase « un responsable doit l'y rattacher avant que … ».
  final String quoi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perimetre = context.watch<RestaurantScopeService>();

    if (perimetre.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final echec = perimetre.echec;
    final (icone, titre, detail) = echec != null
        ? (echec.nature.icone, echec.nature.titre, echec.message)
        : (
            Icons.soup_kitchen_outlined,
            'Aucun établissement rattaché',
            'Ce compte ne supervise aucune cuisine. Un responsable du siège doit '
                'l’y rattacher avant que $quoi.',
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 48, color: theme.hintColor),
              const SizedBox(height: 16),
              Text(titre, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
              // Le bouton n'apparaît que devant une panne : proposer
              // « Réessayer » à qui n'est rattaché à rien, ou à qui n'en a pas
              // le droit, ferait boucler sur une réponse qui ne changera pas.
              if (echec != null && echec.nature.reessayable) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => unawaited(perimetre.resolve(force: true)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Modèle de données pour les groupes de navigation
class NavigationGroup {
  final String title;
  final List<NavigationItem> items;
  final IconData? icon;

  const NavigationGroup({
    required this.title,
    required this.items,
    this.icon,
  });
}

class NavigationItem {
  final String title;
  final IconData icon;
  final int index;
  final Color? color;

  /// La permission que le **serveur** exige pour l'écran ouvert par cette
  /// entrée (ADR-005), ou `null` quand il n'en demande aucune.
  ///
  /// ## Pourquoi elle est là
  ///
  /// `AdminAuthService.can(...)` existait et n'avait **aucun site d'appel** :
  /// les dix-huit entrées ci-dessous s'affichaient pour tout compte du
  /// personnel. Un opérateur voyait « Rôles & Accès », « Réseau »,
  /// « Paiements » ; il ouvrait l'écran, remplissait un formulaire, et
  /// récupérait un 403 à l'envoi. `AssignmentService` l'admet d'ailleurs en
  /// commentaire — « l'écran qui l'affiche ne lui est de toute façon pas
  /// destiné ».
  ///
  /// Le serveur reste l'autorité, et rien ici ne l'assouplit : masquer une
  /// entrée n'accorde ni ne retire quoi que ce soit. L'interface cesse
  /// seulement de promettre ce que le serveur refusera.
  ///
  /// Le nom est celui du registre serveur, repris tel quel. Une chaîne inventée
  /// masquerait l'entrée pour tout le monde, en silence — d'où le test qui
  /// vérifie qu'elles appartiennent toutes au registre.
  final String? permission;

  const NavigationItem({
    required this.title,
    required this.icon,
    required this.index,
    this.color,
    this.permission,
  });
}

/// Nouvelle interface de navigation admin moderne avec sidebar groupée
class AdminNavigationScreen extends StatefulWidget {
  const AdminNavigationScreen({super.key});

  @override
  State<AdminNavigationScreen> createState() => _AdminNavigationScreenState();
}

class _AdminNavigationScreenState extends State<AdminNavigationScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  /// Relecture du compteur de notifications non lues, qui allume la pastille.
  ///
  /// Une minute : le back-office n'a pas de push (voir
  /// `NotificationCenterService`), et c'est le rythme auquel une alerte de
  /// commande doit au plus tard devenir visible sans que personne n'ouvre rien.
  /// La route ne rend qu'un entier.
  Timer? _releveNotifications;

  @override
  void initState() {
    super.initState();
    final centre = NotificationCenterService();
    unawaited(centre.refreshUnreadCount());
    _releveNotifications = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(centre.refreshUnreadCount()),
    );
  }

  @override
  void dispose() {
    _releveNotifications?.cancel();
    super.dispose();
  }

  // État d'expansion des groupes dans la sidebar
  // ignore: unused_field
  final Map<String, bool> _expandedGroups = {
    'Opérations': true,
    'Catalogue': true,
  };

  // Définition de la structure de navigation
  static const List<NavigationGroup> _navigationGroups = [
    NavigationGroup(
      title: 'VUE D\'ENSEMBLE',
      items: [
        NavigationItem(
          title: 'Tableau de bord',
          icon: Icons.dashboard_rounded,
          index: 0,
        ),
        NavigationItem(
          title: 'Analyses & Stats',
          icon: Icons.analytics_rounded,
          index: 4,
          permission: 'analytics.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'OPÉRATIONS',
      items: [
        // En tête, et avant « Commandes » : c'est l'écran du coup de feu.
        //
        // Le poste existait depuis `42f24b0` et n'était atteignable que par un
        // bouton posé dans la barre d'outils de l'écran d'administration qu'il
        // remplaçait — mille sept cents lignes de filtres, d'exports et de
        // statistiques qu'un cuisinier devait traverser pour arriver chez lui.
        //
        // Même permission que les commandes : le poste les lit et les fait
        // avancer par `POST /orders/manage/{id}/status/`, sans autre droit.
        NavigationItem(
          title: 'Poste de cuisine',
          icon: Icons.soup_kitchen_outlined,
          index: 18,
          permission: 'orders.read',
        ),
        NavigationItem(
          title: 'Commandes',
          icon: Icons.shopping_cart_rounded,
          index: 2,
          permission: 'orders.read',
        ),
        NavigationItem(
          title: 'Livraisons actives',
          icon: Icons.local_shipping_rounded,
          index: 14,
          permission: 'orders.read',
        ),
        NavigationItem(
          title: 'Carte temps réel',
          icon: Icons.map_rounded,
          index: 11,
          permission: 'couriers.read',
        ),
      ],
    ),
    // L'argent qui entre, et celui qui sort.
    //
    // Les sorties n'avaient aucun écran : un remboursement demandé ici ne se
    // clôturait que dans l'administration Django, et une demande de retrait
    // livreur ne se soldait nulle part — ses gains restaient débités sans
    // qu'aucun versement puisse être constaté.
    NavigationGroup(
      title: 'CAISSE',
      items: [
        // Les encaissements suivent les commandes : c'est la même question
        // posée du côté de la caisse. Le service existait et n'était ouvert
        // par aucune entrée de menu.
        NavigationItem(
          title: 'Paiements',
          icon: Icons.payments_rounded,
          index: 16,
          // La liste se lit avec les commandes ; le remboursement, seul geste
          // d'écriture de l'écran, exige en plus `orders.refund`.
          permission: 'orders.read',
        ),
        NavigationItem(
          title: 'Remboursements',
          icon: Icons.currency_exchange_rounded,
          index: 24,
          // Lire suit les commandes ; constater exige `orders.refund`, que le
          // serveur vérifie et que l'écran suit pour son bouton.
          permission: 'orders.read',
        ),
        NavigationItem(
          title: 'Retraits livreurs',
          icon: Icons.account_balance_wallet_rounded,
          index: 23,
          // Constater ou refuser exige en plus `payouts.settle`.
          permission: 'payouts.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'CATALOGUE',
      items: [
        NavigationItem(
          title: 'Menu',
          icon: Icons.restaurant_menu_rounded,
          index: 1,
          permission: 'catalog.read',
        ),
        NavigationItem(
          title: 'Catégories',
          icon: Icons.category_rounded,
          index: 6,
          permission: 'catalog.read',
        ),
        NavigationItem(
          title: 'Personnalisations',
          icon: Icons.tune_rounded,
          index: 13,
          permission: 'catalog.read',
        ),
        // Ce que la clientèle dit des plats. Masquer un avis exige
        // `catalog.write`, que le serveur vérifie et journalise.
        NavigationItem(
          title: 'Avis clients',
          icon: Icons.reviews_rounded,
          index: 27,
          permission: 'catalog.read',
        ),
      ],
    ),
    // La matière — ce que la cuisine détient, consomme et perd.
    //
    // Recettes, réservation et rupture existaient côté serveur, et aucune
    // entrée n'y menait : personne ne pouvait enregistrer une livraison
    // autrement que par un `shell`. Le groupe vient après le catalogue parce
    // qu'il en est l'envers — ce qu'on vend, puis ce qu'il faut pour le faire.
    NavigationGroup(
      title: 'INVENTAIRE',
      items: [
        NavigationItem(
          title: 'Stock',
          icon: Icons.inventory_2_rounded,
          index: 19,
          // Lire suffit à ouvrir l'écran ; recevoir, déclarer une perte et
          // configurer demandent chacun leur permission, que le serveur vérifie
          // geste par geste et que l'écran suit pour ses boutons.
          permission: 'inventory.read',
        ),
        NavigationItem(
          title: 'Validations',
          icon: Icons.fact_check_rounded,
          index: 20,
          permission: 'inventory.read',
        ),
        NavigationItem(
          title: 'Recettes',
          icon: Icons.menu_book_rounded,
          index: 21,
          permission: 'recipes.read',
        ),
        NavigationItem(
          title: 'Ingrédients',
          icon: Icons.egg_alt_rounded,
          index: 22,
          permission: 'inventory.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'UTILISATEURS',
      items: [
        NavigationItem(
          title: 'Clients',
          icon: Icons.people_rounded,
          index: 5,
          permission: 'customers.read',
        ),
        // Ce que les clients écrivent. Les routes du support n'étaient
        // ouvertes qu'à eux : le back-office ne pouvait ni lire un ticket, ni
        // y répondre. Répondre et statuer exigent `support.write`.
        NavigationItem(
          title: 'Service client',
          icon: Icons.support_agent_rounded,
          index: 25,
          permission: 'support.read',
        ),
        NavigationItem(
          title: 'Livreurs',
          icon: Icons.delivery_dining_rounded,
          index: 3,
          permission: 'couriers.read',
        ),
        NavigationItem(
          title: 'Validation Docs',
          icon: Icons.verified_user_rounded,
          index: 15,
          // Lire les dossiers suffit à ouvrir l'écran ; approuver ou suspendre
          // demande `couriers.approve` et `couriers.suspend`, que le serveur
          // vérifie geste par geste.
          permission: 'couriers.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'MARKETING',
      items: [
        NavigationItem(
          title: 'Campagnes',
          icon: Icons.campaign_rounded,
          index: 8,
          permission: 'notifications.send',
        ),
        NavigationItem(
          title: 'Promotions',
          icon: Icons.local_offer_rounded,
          index: 9,
          permission: 'promotions.read',
        ),
        NavigationItem(
          title: 'Gamification',
          icon: Icons.emoji_events_rounded,
          index: 10,
          permission: 'gamification.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'RÉSEAU',
      items: [
        NavigationItem(
          title: 'Pays, villes, établissements',
          icon: Icons.public_rounded,
          index: 17,
          // `restaurants.read` ouvre l'écran ; ouvrir un pays ou une ville
          // relève en plus du siège (`assert_unscoped`), qu'aucune permission
          // nommée ne représente — un compte rattaché à un établissement y
          // verra donc ses écritures refusées, et c'est le bon comportement.
          permission: 'restaurants.read',
        ),
      ],
    ),
    NavigationGroup(
      title: 'SYSTÈME',
      items: [
        NavigationItem(
          title: 'Rôles & Accès',
          icon: Icons.admin_panel_settings_rounded,
          index: 7,
          permission: 'roles.read',
        ),
        // Écrit depuis longtemps, lisible nulle part. Le serveur le cloisonne :
        // un gérant n'y lit que ce qui touche ses établissements.
        NavigationItem(
          title: 'Journal d’audit',
          icon: Icons.history_edu_rounded,
          index: 26,
          permission: 'audit.read',
        ),
        NavigationItem(
          title: 'Paramètres',
          icon: Icons.settings_rounded,
          index: 12,
        ),
      ],
    ),
  ];

  // Items pour la BottomNavigationBar (Mobile uniquement).
  //
  // Les permissions reprennent celles de la barre latérale : la même entrée ne
  // peut pas être refusée sur un écran large et offerte sur un téléphone.
  static const List<NavigationItem> _mobileNavItems = [
    NavigationItem(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      index: 0,
    ),
    NavigationItem(
      title: 'Menu',
      icon: Icons.restaurant_menu_rounded,
      index: 1,
      permission: 'catalog.read',
    ),
    NavigationItem(
      title: 'Commandes',
      icon: Icons.shopping_cart_rounded,
      index: 2,
      permission: 'orders.read',
    ),
    NavigationItem(
      title: 'Livreurs',
      icon: Icons.delivery_dining_rounded,
      index: 3,
      permission: 'couriers.read',
    ),
  ];

  /// Ouvre un écran de la navigation — ce qu'appellent les raccourcis du
  /// tableau de bord, qui ouvraient leur écran par `Navigator.push`, hors de
  /// cette navigation et de son filtre de permissions.
  ///
  /// Un index que ce compte n'a pas le droit d'ouvrir est ignoré : le
  /// raccourci ne doit pas être une porte dérobée vers un écran que la barre
  /// latérale lui cache.
  void _ouvrirEcran(int index) {
    final auth = context.read<AdminAuthService>();
    final autorise = _navigationGroups
        .expand((groupe) => groupe.items)
        .where((entree) => entree.index == index)
        .any((entree) => entree.permission == null || auth.can(entree.permission!));
    if (autorise) setState(() => _selectedIndex = index);
  }

  Widget _getCurrentScreen() {
    Widget screen;
    switch (_selectedIndex) {
      case 0:
        screen = AdminDashboardScreen(ouvrirEcran: _ouvrirEcran);
        break;
      case 1:
        screen = const MenuManagementScreen();
        break;
      case 2:
        screen = const AdvancedOrderManagementScreen();
        break;
      case 3:
        screen = const DriverManagementScreen();
        break;
      case 4:
        screen = const AnalyticsScreen();
        break;
      case 5:
        screen = const ClientManagementScreen();
        break;
      case 6:
        screen = const CategoryManagementScreen();
        break;
      case 7:
        screen = const AdminRolesScreen();
        break;
      case 8:
        screen = const MarketingScreen();
        break;
      case 9:
        screen = const PromotionsScreen();
        break;
      case 10:
        screen = const GamificationManagementScreen();
        break;
      case 11:
        screen = const DriverMapScreen();
        break;
      case 12:
        screen = const SettingsScreen();
        break;
      case 13:
        screen = const CustomizationManagementScreen();
        break;
      case 14:
        screen = const ActiveDeliveriesScreen();
        break;
      case 15:
        screen = const DriverDocumentsDashboardScreen();
        break;
      case 16:
        screen = const PaymentsScreen();
        break;
      case 17:
        screen = const ReseauScreen();
        break;
      case 18:
        // Le seul écran de cette liste qui dépende du périmètre courant : le
        // poste est **mono-établissement**, un cuisinier est dans une cuisine,
        // et mêler deux cartes ferait préparer un plat pour l'autre bout de la
        // ville.
        //
        // `watch` et non `read` : quand on change d'établissement depuis le
        // sélecteur de la barre supérieure, le poste doit suivre. Avec `read`,
        // il continuerait d'afficher les commandes de la cuisine précédente
        // sans que son titre cesse pour autant d'être juste.
        final etablissement = context.watch<RestaurantScopeService>().current;
        screen = etablissement == null
            ? const _CuisineSansEtablissement()
            : KitchenScreen(restaurant: etablissement);
        break;
      case 19:
      case 20:
      case 21:
        // Le stock, sa file de validation et les recettes sont ceux **d'une**
        // cuisine, comme le poste : ils suivent le sélecteur d'établissement.
        final cuisine = context.watch<RestaurantScopeService>().current;
        if (cuisine == null) {
          screen = const _CuisineSansEtablissement(quoi: 'son inventaire puisse s’afficher');
        } else if (_selectedIndex == 19) {
          screen = StockScreen(restaurant: cuisine);
        } else if (_selectedIndex == 20) {
          screen = ValidationsScreen(restaurant: cuisine);
        } else {
          screen = RecettesScreen(restaurant: cuisine);
        }
        break;
      case 22:
        // Le référentiel, lui, est celui de l'enseigne : il ne dépend
        // d'aucune cuisine.
        screen = const IngredientsScreen();
        break;
      case 23:
        screen = const RetraitsLivreursScreen();
        break;
      case 24:
        screen = const RemboursementsScreen();
        break;
      case 25:
        screen = const ServiceClientScreen();
        break;
      case 26:
        screen = const JournalAuditScreen();
        break;
      case 27:
        screen = const AvisClientsScreen();
        break;
      default:
        screen = AdminDashboardScreen(ouvrirEcran: _ouvrirEcran);
    }

    return KeyedSubtree(
      key: ValueKey(_selectedIndex),
      child: RepaintBoundary(child: _SafeScreenWrapper(child: screen)),
    );
  }

  /// Les groupes que ce compte a le droit d'ouvrir — ADR-005.
  ///
  /// Un groupe dont toutes les entrées sont refusées disparaît avec elles : un
  /// intitulé « MARKETING » suivi de rien n'apprend qu'une chose, c'est qu'on
  /// n'y a pas droit, et c'est justement ce qu'un menu n'a pas à annoncer.
  ///
  /// Le serveur reste l'autorité : ce filtre n'accorde rien et ne retire rien.
  /// Il empêche seulement l'interface de promettre ce que le serveur refusera.
  List<NavigationGroup> _groupesAutorises(AdminAuthService auth) {
    final groupes = <NavigationGroup>[];
    for (final groupe in _navigationGroups) {
      final entrees = [
        for (final entree in groupe.items)
          if (entree.permission == null || auth.can(entree.permission!)) entree,
      ];
      if (entrees.isNotEmpty) {
        groupes.add(
          NavigationGroup(
            title: groupe.title,
            items: entrees,
            icon: groupe.icon,
          ),
        );
      }
    }
    return groupes;
  }

  /// Les entrées du bandeau mobile, même règle.
  List<NavigationItem> _entreesMobileAutorisees(AdminAuthService auth) => [
        for (final entree in _mobileNavItems)
          if (entree.permission == null || auth.can(entree.permission!)) entree,
      ];

  String _getCurrentTitle() {
    for (final group in _navigationGroups) {
      for (final item in group.items) {
        if (item.index == _selectedIndex) {
          return item.title;
        }
      }
    }
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAuthService>(
      builder: (context, adminAuthService, child) {
        if (adminAuthService.isLoading) {
          return const Scaffold(body: LoadingWidget(message: 'Chargement...'));
        }

        if (!adminAuthService.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/admin-login');
            }
          });
          return const Scaffold(
            body: LoadingWidget(
              message: 'Vérification de l\'authentification...',
            ),
          );
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isMobile = MediaQuery.of(context).size.width < 1024; // Tablet breakpoint

        if (isMobile) {
          return Scaffold(
            appBar: _buildMobileAppBar(context, adminAuthService, theme),
            body: _getCurrentScreen(),
            bottomNavigationBar: _buildMobileBottomNav(theme),
            drawer: _buildMobileDrawer(context, adminAuthService, theme),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildModernSidebar(context, adminAuthService, theme),
              Expanded(
                child: Column(
                  children: [
                    _buildModernAppBar(context, adminAuthService, theme),
                    Expanded(
                      child: Container(
                        color: scheme.surface,
                        child: _getCurrentScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _itemAccentColor(BuildContext context, NavigationItem item) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    // Couleurs "sémantiques" stables par section (pas de hardcoded Colors.*).
    switch (item.index) {
      case 0: // Dashboard
        return sem.info;
      case 4: // Analytics
        return scheme.tertiary;
      case 2: // Orders
        return sem.warning;
      case 14: // Active deliveries
        return sem.danger;
      case 11: // Map
        return scheme.secondary;
      case 1: // Menu
        return sem.success;
      case 6: // Categories
        return scheme.primary;
      case 13: // Customizations
        return scheme.tertiary;
      case 5: // Clients
        return scheme.primary;
      case 3: // Drivers
        return scheme.secondary;
      case 15: // Docs validation
        return sem.success;
      case 8: // Marketing
        return scheme.primary;
      case 9: // Promotions
        return sem.warning;
      case 10: // Gamification
        return scheme.primary;
      case 7: // Roles
        return scheme.primary;
      case 16: // Paiements
        return sem.success;
      case 23: // Retraits livreurs
        return sem.warning;
      case 24: // Remboursements
        return sem.danger;
      case 25: // Service client
        return sem.info;
      case 26: // Journal d'audit
        return scheme.onSurfaceVariant;
      case 12: // Settings
        return scheme.onSurfaceVariant;
      default:
        return scheme.primary;
    }
  }

  // ===========================================================================
  // SIDEBAR (DESKTOP)
  // ===========================================================================

  Widget _buildModernSidebar(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    final sem = AdminColorTokens.semantic(theme.colorScheme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isSidebarExpanded ? 280 : 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(context, theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _groupesAutorises(adminAuth).map((group) {
                  return _buildNavigationGroup(group, theme);
                }).toList(),
              ),
            ),
          ),
          _buildSidebarFooter(context, adminAuth, theme),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, ThemeData theme) {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 24 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 24,
                  );
                },
              ),
            ),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'El Corazón',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Administration',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_open_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onPressed: () => setState(() => _isSidebarExpanded = false),
              tooltip: 'Réduire le menu',
              splashRadius: 24,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationGroup(NavigationGroup group, ThemeData theme) {
    if (!_isSidebarExpanded) {
      // Version compacte (juste les icônes)
      return Column(
        children: [
          ...group.items.map((item) => _buildNavItemCompact(item, theme)),
          const SizedBox(height: 8),
          Divider(
            color: theme.dividerColor.withValues(alpha: 0.1),
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            group.title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...group.items.map((item) => _buildNavItem(item, theme)),
      ],
    );
  }

  Widget _buildNavItem(NavigationItem item, ThemeData theme) {
    final isSelected = _selectedIndex == item.index;
    final primaryColor = item.color ?? _itemAccentColor(context, item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = item.index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.1)
                  : theme.colorScheme.surface.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : theme.colorScheme.surface.withValues(alpha: 0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemCompact(NavigationItem item, ThemeData theme) {
    final isSelected = _selectedIndex == item.index;
    final primaryColor = item.color ?? _itemAccentColor(context, item);

    return Tooltip(
      message: item.title,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = item.index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.1)
                    : theme.colorScheme.surface.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.2)
                      : theme.colorScheme.surface.withValues(alpha: 0),
                ),
              ),
              child: Icon(
                item.icon,
                size: 22,
                color: isSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: _isSidebarExpanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (adminAuth.currentAdmin?.fullName ?? 'A')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminAuth.nomAffiche,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        adminAuth.roleLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: theme.colorScheme.error,
                  onPressed: () => _logout(context),
                  tooltip: 'Déconnexion',
                ),
              ],
            )
          : IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              ),
              onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            ),
    );
  }

  // ===========================================================================
  // APP BAR (DESKTOP)
  // ===========================================================================

  Widget _buildModernAppBar(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getCurrentTitle(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bienvenue sur votre espace d\'administration',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Sur quel établissement porte tout ce que montre cet écran. Absent
          // quand le compte n'en supervise qu'un — il n'y a alors rien à
          // choisir.
          const SelecteurEtablissement(),
          const SizedBox(width: 12),
          _buildAppBarAction(
            context,
            icon: Icons.search,
            tooltip: 'Recherche globale',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _buildAppBarAction(
            context,
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            // Allumée en dur jusqu'ici : elle annonçait des notifications en
            // permanence, et n'apprenait donc plus rien à personne.
            hasBadge: context.watch<NotificationCenterService>().unreadCount > 0,
            onTap: () => _showNotifications(context),
          ),
          const SizedBox(width: 12),
          _buildAppBarAction(
            context,
            icon: Icons.settings_outlined,
            tooltip: 'Paramètres',
            onTap: () => _showSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarAction(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                if (hasBadge)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE UI
  // ===========================================================================

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    return AppBar(
      title: Text(
        _getCurrentTitle(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: context.watch<NotificationCenterService>().unreadCount > 0,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined),
          ),
          tooltip: 'Notifications',
          onPressed: () => _showNotifications(context),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav(ThemeData theme) {
    final sem = AdminColorTokens.semantic(theme.colorScheme);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: sem.shadow,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _entreesMobileAutorisees(context.read<AdminAuthService>())
                .map((item) {
              final isSelected = _selectedIndex == item.index;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = item.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    AdminAuthService adminAuth,
    ThemeData theme,
  ) {
    final scheme = theme.colorScheme;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: scheme.onPrimary.withValues(alpha: 0.18),
              child: Text(
                (adminAuth.currentAdmin?.fullName ?? 'A').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimary,
                ),
              ),
            ),
            accountName: Text(
              adminAuth.nomAffiche,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              adminAuth.roleLabel,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._groupesAutorises(context.read<AdminAuthService>()).map((group) {
                  return ExpansionTile(
                    title: Text(
                      group.title,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    initiallyExpanded: true,
                    children: group.items.map((item) {
                      return ListTile(
                        leading: Icon(
                          item.icon,
                          color: _selectedIndex == item.index
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: _selectedIndex == item.index
                                ? theme.colorScheme.primary
                                : null,
                            fontWeight:
                                _selectedIndex == item.index ? FontWeight.bold : null,
                          ),
                        ),
                        selected: _selectedIndex == item.index,
                        onTap: () {
                          setState(() => _selectedIndex = item.index);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                }),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: Text(
                    'Déconnexion',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  void _showNotifications(BuildContext context) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => const NotificationsDialog(),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _logout(BuildContext context) async {
    final adminAuth = Provider.of<AdminAuthService>(context, listen: false);
    await adminAuth.logoutAdmin();
    if (context.mounted) {
      unawaited(Navigator.of(context).pushReplacementNamed('/admin-login'));
    }
  }
}

/// Wrapper pour garantir que le layout est prêt avant les interactions
class _SafeScreenWrapper extends StatefulWidget {
  final Widget child;

  const _SafeScreenWrapper({required this.child});

  @override
  State<_SafeScreenWrapper> createState() => _SafeScreenWrapperState();
}

class _SafeScreenWrapperState extends State<_SafeScreenWrapper> {
  bool _hasLayout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _hasLayout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        if (!_hasLayout) {
          return IgnorePointer(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: widget.child,
            ),
          );
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: widget.child,
        );
      },
    );
  }
}
