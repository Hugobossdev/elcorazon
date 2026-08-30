import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
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
          return DeliveryStatusCard(
            order: commande,
            onTap: () => context.navigateToDeliveryTracking(commande.id),
          );
        },
      ),
    );
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
