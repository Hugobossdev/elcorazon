import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/presentation/reprise_de_commande.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/delivery_status_card.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/widgets/navigation_helper.dart';

/// Onglet « Mes commandes » de la barre inférieure.
///
/// ## Pourquoi il change d'habillage
///
/// Le design Stitch ne livre pas de maquette pour cet écran, mais il en livre
/// une pour la **barre inférieure** qui l'atteint. L'écran gardait donc une
/// barre supérieure en aplat rouge dégradé et des onglets blancs translucides,
/// juste au-dessus d'une navigation redessinée : le passage d'un onglet à
/// l'autre changeait d'application à vue d'œil.
///
/// Il prend ici la barre translucide et la bascule en pilule des autres
/// écrans, et confie ses trois états — vide, chargement, contenu — aux mêmes
/// composants que le reste de l'application.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AppService>(
      builder: (context, appService, child) {
        if (!appService.isLoggedIn) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: const GlassAppBar(title: 'Mes commandes', showBack: false),
            body: etats.EmptyStateWidget(
              title: 'Connectez-vous pour voir vos commandes',
              message:
                  'Vos commandes en cours et votre historique vous attendent.',
              icon: Icons.receipt_long_outlined,
              actionText: 'Se connecter',
              onAction: () => NavigationService.navigateToAuth(context),
            ),
          );
        }

        // Une panne de chargement n'est pas un historique vide.
        //
        // `_loadUserOrders` rattrapait toute erreur en posant une liste vide, et
        // cet écran affichait alors « Aucune commande passée — votre historique
        // apparaîtra ici ». Un client dont le réseau vient de couper, ou dont la
        // session a expiré, lisait donc une affirmation fausse sur son propre
        // compte, sans aucun moyen de réessayer.
        //
        // Même règle que la carte (`erreurCatalogue`, `menu_screen.dart`), qui
        // avait déjà été corrigée de ce défaut-là.
        if (appService.erreurHistorique != null && appService.orders.isEmpty) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: const GlassAppBar(title: 'Mes commandes', showBack: false),
            body: etats.EmptyStateWidget(
              title: 'Commandes indisponibles',
              message: '${appService.erreurHistorique!} '
                  'Vos commandes sont bien là — c’est leur lecture qui a échoué.',
              icon: Icons.cloud_off_rounded,
              actionText: 'Réessayer',
              onAction: () => appService.rechargerHistorique(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: GlassAppBar(
            title: 'Mes commandes',
            showBack: false,
            actions: [
              GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Filtrer et rechercher',
                filled: false,
                onPressed: () => context.navigateToEnhancedOrders(),
              ),
            ],
            bottom: SegmentedTabs(
              controller: _tabController,
              labels: const ['En cours', 'Historique'],
              icons: const [Icons.schedule_rounded, Icons.history_rounded],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _liste(
                commandes: appService.orders.where(_estEnCours).toList(),
                vide: const etats.EmptyStateWidget(
                  title: 'Aucune commande en cours',
                  message: 'Vos commandes actives apparaîtront ici.',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              _liste(
                commandes:
                    appService.orders.where((o) => !_estEnCours(o)).toList(),
                vide: const etats.EmptyStateWidget(
                  title: 'Aucune commande passée',
                  message: 'Votre historique apparaîtra ici.',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Une commande est « en cours » tant qu'elle n'est ni livrée ni close.
  ///
  /// `refunded` et `failed` rejoignent l'historique : ce sont des issues, pas
  /// des étapes. Les ranger parmi les commandes actives laissait une commande
  /// échouée en tête de liste, indéfiniment.
  bool _estEnCours(Order commande) {
    switch (commande.status) {
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
      case OrderStatus.failed:
        return false;
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.pickedUp:
      case OrderStatus.onTheWay:
        return true;
    }
  }

  Widget _liste({required List<Order> commandes, required Widget vide}) {
    if (commandes.isEmpty) {
      // Le geste de rafraîchissement doit rester possible quand la liste est
      // vide : c'est précisément là qu'on cherche à la remplir. Un `Center`
      // seul ne défile pas, et `RefreshIndicator` n'a alors rien à écouter.
      return RefreshIndicator(
        onRefresh: _rafraichir,
        child: LayoutBuilder(
          builder: (context, contraintes) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: contraintes.maxHeight),
              child: vide,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingM,
          DesignConstants.edgeMargin,
          DesignConstants.spacingXL,
        ),
        itemCount: commandes.length,
        itemBuilder: (context, index) {
          final commande = commandes[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeliveryStatusCard(
                order: commande,
                onTap: () => context.navigateToDeliveryTracking(commande.id),
              ),
              // « Reorder » de la maquette `my_orders`, sur les commandes
              // closes seulement — recommander une commande en cours de
              // livraison n'a pas de sens.
              if (!_estEnCours(commande))
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: DesignConstants.spacingM,
                  ),
                  child: ActionButton(
                    label: 'Recommander',
                    emphasis: ActionEmphasis.outlined,
                    icon: Icons.refresh_rounded,
                    height: 44,
                    onPressed: () => _recommander(commande),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Repose les articles d'une commande passée au panier.
  ///
  /// La logique vit dans `CartService.reprendreLaCommande`, partagée avec
  /// l'écran d'historique : deux implémentations de la même opération auraient
  /// fini par diverger, et celle-ci touche au panier.
  void _recommander(Order commande) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final appService = Provider.of<AppService>(context, listen: false);

    final resultat = cartService.reprendreLaCommande(
      [
        for (final item in commande.items)
          (
            menuItemId: item.menuItemId,
            nom: item.name,
            quantite: item.quantity,
            options: item.customizations,
          ),
      ],
      appService.menuItems,
    );

    if (!mounted) return;
    annoncerLaReprise(context, resultat);
  }

  /// Relit les commandes auprès du serveur.
  ///
  /// `AppService.initialize()` recharge la session, le menu **et** les
  /// commandes. C'est plus large que nécessaire, mais c'est le seul point
  /// d'entrée public : élargir la surface d'`AppService` pour un tirage vers
  /// le bas n'en vaut pas le prix.
  Future<void> _rafraichir() async {
    await Provider.of<AppService>(context, listen: false).initialize();
  }
}
