import 'package:elcora_fast/models/cart_item.dart' as cart_item;
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/cart_item_card.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Écran du panier.
///
/// ## Trois blocs, et une barre
///
/// La maquette empile les lignes, le code promotionnel et le récapitulatif,
/// puis ancre en bas une barre qui répète le total et porte l'action. La
/// répétition du total est voulue : le récapitulatif se trouve souvent hors de
/// l'écran au moment où l'on décide de valider.
///
/// ## Ce que la refonte corrige au passage
///
/// Les lignes passaient par `DesignEnhancementService.createEnhancedCartItemCard`,
/// qui **reconstruisait un `CartItem` de toutes pièces** — identifiants vidés,
/// personnalisations perdues — et à qui cet écran passait la description
/// littérale « Plat délicieux ». Les suppléments choisis à l'écran de
/// personnalisation n'apparaissaient donc jamais dans le panier, alors qu'ils
/// étaient bien facturés. La ligne reçoit désormais le vrai `CartItem`.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Mon panier',
        actions: [
          Consumer<CartService>(
            builder: (context, cartService, child) {
              if (cartService.isEmpty) return const SizedBox(width: 44);
              return GlassIconButton(
                icon: Icons.delete_sweep_rounded,
                tooltip: 'Vider le panier',
                filled: false,
                onPressed: () => _showClearCartDialog(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isEmpty) return _panierVide(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingL,
            ),
            children: [
              for (var index = 0; index < cartService.items.length; index++)
                CartItemCard(
                  item: cartService.items[index],
                  onQuantityChanged: (quantite) => _changerQuantite(
                    cartService,
                    index,
                    quantite,
                  ),
                  onRemove: () => _showDeleteItemDialog(
                    context,
                    cartService.items[index],
                    index,
                    cartService,
                  ),
                ),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.goBack(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Ajouter d’autres articles'),
                ),
              ),
              const SizedBox(height: DesignConstants.spacingM),
              _ChampCodePromo(cartService: cartService),
              const SizedBox(height: DesignConstants.spacingM),
              _Recapitulatif(cartService: cartService),
              _Suggestions(cartService: cartService),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isEmpty) return const SizedBox.shrink();

          return GlassBottomBar(
            child: StickySummaryBar(
              label: cartService.hasQuote ? 'Total' : 'Total hors livraison',
              amount: PriceFormatter.format(cartService.total),
              action: ActionButton(
                label: 'Commander',
                emphasis: ActionEmphasis.gradient,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => _commander(context),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  /// Le décrément s'arrête à un : passer à zéro effacerait la ligne sans rien
  /// demander, et un appui de trop sur le moins est vite arrivé. C'est la
  /// corbeille, avec sa confirmation, qui retire.
  void _changerQuantite(CartService cartService, int index, int quantite) {
    if (quantite < 1) return;
    cartService.updateItemQuantity(index, quantite);
  }

  Future<void> _commander(BuildContext context) async {
    final appService = context.read<AppService>();

    if (!appService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour valider votre commande'),
        ),
      );
      NavigationService.navigateToAuth(context);
      return;
    }

    await context.navigateToCheckout();
  }

  Widget _panierVide(BuildContext context) {
    return EmptyStateWidget(
      title: 'Votre panier est vide',
      message: 'Ajoutez des plats et ils apparaîtront ici.',
      icon: Icons.shopping_cart_outlined,
      actionText: 'Découvrir le menu',
      onAction: () => context.goBack(),
    );
  }

  void _showDeleteItemDialog(
    BuildContext context,
    cart_item.CartItem cartItem,
    int index,
    CartService cartService,
  ) {
    context.showEnhancedDialog(
      title: 'Retirer l’article',
      content: 'Retirer « ${cartItem.name} » de votre panier ?',
      confirmText: 'Retirer',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () {
        cartService.removeItem(index);
        context.showSuccessMessage('${cartItem.name} retiré du panier');
      },
      onCancel: () {},
    );
  }

  void _showClearCartDialog(BuildContext context) {
    context.showEnhancedDialog(
      title: 'Vider le panier',
      content: 'Retirer tous les articles de votre panier ?',
      confirmText: 'Vider',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () {
        context.read<CartService>().clear();
        context.showSuccessMessage('Panier vidé');
      },
      onCancel: () {},
    );
  }
}

// ------------------------------------------------------------------- promo

/// Saisie du code promotionnel, en ligne.
///
/// La maquette la met dans le panier plutôt que derrière un écran dédié, et
/// c'est le bon endroit : le code se saisit en même temps qu'on relit son
/// total. L'écran dédié reste accessible depuis le règlement, où l'adresse est
/// connue et le devis complet.
///
/// La vérification passe par `CartService.appliquerCodePromo`, donc par
/// `POST /orders/preview/` : aucune remise n'est calculée ici.
class _ChampCodePromo extends StatefulWidget {
  const _ChampCodePromo({required this.cartService});

  final CartService cartService;

  @override
  State<_ChampCodePromo> createState() => _ChampCodePromoState();
}

class _ChampCodePromoState extends State<_ChampCodePromo> {
  final _controleur = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _appliquer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final erreur = await widget.cartService.appliquerCodePromo(
      _controleur.text,
    );

    if (!mounted) return;
    setState(() {
      _enCours = false;
      _erreur = erreur;
    });

    if (erreur == null) {
      _controleur.clear();
      context.showSuccessMessage('Code promo appliqué');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applique = widget.cartService.promoCode;

    if (applique != null && applique.isNotEmpty) {
      return SectionCard(
        child: Row(
          children: [
            Icon(
              Icons.local_activity_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: DesignConstants.spacingS + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    applique,
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Remise de ${PriceFormatter.format(widget.cartService.discount)}',
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.cartService.removePromoCode,
              child: const Text('Retirer'),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_activity_outlined,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: DesignConstants.spacingS + 2),
              Expanded(
                child: TextField(
                  controller: _controleur,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _enCours ? null : _appliquer(),
                  style: AppTypography.bodyLg(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Code promo',
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: AppTypography.bodyLg(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignConstants.spacingS),
              ActionButton(
                label: 'Appliquer',
                expand: false,
                height: 40,
                isLoading: _enCours,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: theme.colorScheme.primary,
                onPressed: _appliquer,
              ),
            ],
          ),
          if (_erreur != null) ...[
            const SizedBox(height: DesignConstants.spacingS),
            Text(
              _erreur!,
              style: AppTypography.bodyMd(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ récapitulatif

class _Recapitulatif extends StatelessWidget {
  const _Recapitulatif({required this.cartService});

  final CartService cartService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = cartService.itemCount;
    final pluriel = articles > 1 ? 's' : '';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Récapitulatif',
            style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          SummaryRow(
            label: 'Sous-total',
            subtitle: '$articles article$pluriel',
            value: PriceFormatter.format(cartService.subtotal),
          ),
          // Tant qu'aucune adresse n'est choisie, personne ne connaît le prix
          // de la course : elle dépend de la zone d'arrivée. Afficher « 0 F »
          // se lirait « offerte », et « 500 F » serait un montant que le
          // serveur ne confirmerait presque jamais.
          if (cartService.hasQuote)
            SummaryRow(
              label: 'Livraison',
              value: PriceFormatter.format(cartService.deliveryFee),
            )
          else
            const SummaryRow(
              label: 'Livraison',
              value: 'à la validation',
              subtitle: 'Selon votre zone de livraison',
            ),
          if (cartService.discount > 0)
            SummaryRow(
              label: cartService.promoCode == null
                  ? 'Remise'
                  : 'Remise (${cartService.promoCode})',
              value: PriceFormatter.format(-cartService.discount),
              isDiscount: true,
            ),
          const SummaryDivider(),
          SummaryRow(
            label: cartService.hasQuote ? 'Total' : 'Total hors livraison',
            value: PriceFormatter.format(cartService.total),
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- suggestions

/// Plats populaires absents du panier.
///
/// Ils réemploient la carte du menu plutôt qu'une copie locale : la copie
/// d'avant enfermait une photo de 100 px et son texte dans une boîte de
/// 160 px, où le bouton d'ajout passait sous le bord.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.cartService});

  final CartService cartService;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final auPanier = cartService.items.map((e) => e.menuItemId).toSet();
        final suggestions = appService.menuItems
            .where(
              (item) =>
                  !auPanier.contains(item.id) &&
                  item.isPopular &&
                  item.isAvailable,
            )
            .take(6)
            .toList();

        if (suggestions.isEmpty) return const SizedBox.shrink();

        const largeurCarte = 170.0;

        return Padding(
          padding: const EdgeInsets.only(top: DesignConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Cela irait bien avec',
                subtitle: 'Les plats les plus commandés',
              ),
              const SizedBox(height: DesignConstants.spacingM),
              SizedBox(
                height: MenuItemCard.hauteurPour(context, largeurCarte),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: DesignConstants.spacingM),
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    return SizedBox(
                      width: largeurCarte,
                      child: MenuItemCard(
                        item: item,
                        onTap: () => context.navigateToItemCustomization(item),
                        onAddToCart: () => context.addToCartOrCustomize(item),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
