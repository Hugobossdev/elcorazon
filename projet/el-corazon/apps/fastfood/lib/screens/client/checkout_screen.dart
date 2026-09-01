import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/presentation/adresse.dart';
import 'package:elcora_fast/presentation/frais_de_livraison.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/widgets/delivery_fee_breakdown_card.dart';
import 'package:elcora_fast/widgets/zone_not_serviceable_dialog.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
import 'package:elcora_fast/screens/client/payment_screen.dart';
import 'package:elcora_fast/screens/client/address_selector_screen.dart';

/// Écran de finalisation de commande
class CheckoutScreen extends StatefulWidget {
  final String? existingOrderId;
  final List<CartItem>? preloadedItems;
  final double? preloadedTotal;

  const CheckoutScreen({
    super.key,
    this.existingOrderId,
    this.preloadedItems,
    this.preloadedTotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPayment = PaymentMethod
      .cash; // Par défaut: cash (mobile money, credit card et debit card désactivés)
  bool _isLoading = false;
  bool _isCalculatingDeliveryFee = false;

  /// Vrai dès qu'on a tenté de commander sans adresse. Ce n'est qu'à ce
  /// moment que la carte d'adresse se signale en rouge : la souligner dès
  /// l'ouverture reprocherait au client de ne pas avoir fait ce qu'on ne lui
  /// a pas encore demandé.
  bool _adresseReclamee = false;
  eccore.Address? _selectedAddress;
  // La distance et le délai estimé ne sont plus recopiés ici : ils vivent sur
  // `_deliveryBreakdown`, d'où l'écran les lit déjà.
  FraisDeLivraison? _deliveryBreakdown;

  final AddressService _addressService = AddressService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
    // S'assurer que le wallet n'est pas sélectionné (fonctionnalité désactivée)
    if (_selectedPayment == PaymentMethod.wallet) {
      _selectedPayment = PaymentMethod.cash;
    }
    // S'assurer que mobile money, credit card et debit card ne sont pas sélectionnés (désactivés)
    if (_selectedPayment == PaymentMethod.mobileMoney ||
        _selectedPayment == PaymentMethod.creditCard ||
        _selectedPayment == PaymentMethod.debitCard) {
      _selectedPayment = PaymentMethod.cash;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Pré-remplit l'adresse de livraison.
  ///
  /// Le carnet est ouvert par la session (`AppService`), pas par cet écran :
  /// il appelait `initialize()`, qui ne lisait que le cache local et ne
  /// contactait jamais le serveur. On reprend le choix déjà mémorisé — celui
  /// que le client a fait à sa commande précédente — avant de retomber sur
  /// l'adresse par défaut.
  Future<void> _loadUserAddress() async {
    try {
      final address = _addressService.selectedAddress ??
          _addressService.defaultAddress ??
          _addressService.addresses.firstOrNull;

      if (address == null) {
        _addressController.text = '';
        return;
      }

      _selectedAddress = address;
      _addressController.text = address.uneLigne;
      await _calculateDeliveryFeeForAddress(address);
    } catch (e) {
      eccore.Journal.trace('Erreur chargement adresse: $e');
      _addressController.text = '';
    }
  }

  /// Demande au serveur le chiffrage de la commande pour cette adresse.
  ///
  /// L'écran calculait auparavant lui-même les frais, puis les poussait dans
  /// le panier. Il les **lit** désormais : `CartService.refreshQuote` appelle
  /// `POST /orders/preview/`, qui emprunte le chemin de calcul de la création
  /// de commande. Ce qui s'affiche ici est donc, au centime près, ce qui sera
  /// facturé.
  Future<void> _calculateDeliveryFeeForAddress(eccore.Address? address) async {
    if (address == null) return;

    setState(() {
      _isCalculatingDeliveryFee = true;
    });

    try {
      final cartService = context.read<CartService>();
      await cartService.refreshQuote(address: address);

      final breakdown = await _deliveryFeeService.breakdownForAddress(
        address: address,
        promoCode: cartService.promoCode ?? '',
      );

      if (mounted) {
        setState(() {
          _deliveryBreakdown = breakdown;
        });

        if (!breakdown.isInServiceableZone && mounted) {
          await ZoneNotServiceableDialog.show(
            context,
            onChooseAnotherAddress: _selectAddress,
          );
        }
      }
    } catch (e) {
      // Le serveur a refusé de chiffrer — adresse hors zone, minimum de
      // commande non atteint, article devenu indisponible. Aucun montant de
      // secours n'est fabriqué : le bouton de commande reste inactif tant
      // qu'aucun devis n'est arrivé.
      eccore.Journal.trace('Devis de commande indisponible : $e');
      if (mounted) {
        setState(() {
          _deliveryBreakdown = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is eccore.ApiException
                  ? e.detail
                  : 'Impossible de chiffrer la commande pour le moment.',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingDeliveryFee = false;
        });
      }
    }
  }

  // Plus de rattrapage de coordonnées ici : une `eccore.Address` en porte toujours,
  // par construction. Cet écran géocodait l'adresse choisie quand elle n'en
  // avait pas — un rattrapage qui n'existait que parce que le carnet laissait
  // créer des adresses sans point, et qui n'a plus d'objet.

  Future<void> _selectAddress() async {
    final selected = await Navigator.of(context).push<eccore.Address>(
      MaterialPageRoute(
        builder: (context) => AddressSelectorScreen(
          currentAddress: _selectedAddress,
          onAddressSelected: (eccore.Address address) {
            Navigator.of(context).pop(address);
          },
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedAddress = selected;
        _addressController.text = selected.uneLigne;
      });
      setState(() => _adresseReclamee = false);
      await _calculateDeliveryFeeForAddress(selected);
    }
  }

  // NOTE: V2 adresses: plus de saisie libre dans le checkout.
  // L'utilisateur doit sélectionner une eccore.Address (avec lat/lng).

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // Pas de cloche ni de panier dans cette barre : à l'étape du règlement,
      // toute sortie latérale est une commande perdue.
      appBar: const GlassAppBar(title: 'Finaliser la commande'),
      body: Consumer2<AppService, CartService>(
        builder: (context, appService, cartService, child) {
          final isGroupOrder = widget.existingOrderId != null;
          final cartItems =
              isGroupOrder ? (widget.preloadedItems ?? []) : cartService.items;
          final subtotal = isGroupOrder
              ? (widget.preloadedTotal ?? 0.0)
              : cartService.subtotal;
          final deliveryFee = cartService.deliveryFee;
          final discount = isGroupOrder ? 0.0 : cartService.discount;
          // Le total vient du devis serveur dès qu'il existe. La ligne
          // précédente le recomposait ici (`sous-total + frais − remise`), ce
          // qui donnait un troisième chiffre, différent de celui du panier et
          // de celui de la commande.
          final total = isGroupOrder
              ? (subtotal + deliveryFee - discount)
              : cartService.total;

          if (cartItems.isEmpty) {
            return _buildEmptyCart(context);
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DesignConstants.edgeMargin,
                      DesignConstants.spacingM,
                      DesignConstants.edgeMargin,
                      DesignConstants.spacingL,
                    ),
                    children: [
                      _buildStepHeader(context, 'Adresse de livraison'),
                      _buildDeliverySection(context),
                      const SizedBox(height: DesignConstants.spacingL),
                      _buildStepHeader(context, 'Mode de paiement'),
                      _buildPaymentSection(context),
                      const SizedBox(height: DesignConstants.spacingL),
                      _buildStepHeader(context, 'Instructions pour le livreur'),
                      _buildNotesSection(context),
                      const SizedBox(height: DesignConstants.spacingL),
                      _buildStepHeader(context, 'Code promo'),
                      _buildPromoSection(context, cartService),
                      const SizedBox(height: DesignConstants.spacingL),
                      _buildStepHeader(context, 'Récapitulatif'),
                      _buildOrderSummary(
                        context,
                        cartItems,
                        subtotal,
                        deliveryFee,
                        discount,
                        total,
                        cartService.itemCount,
                        cartService.promoCode,
                      ),
                    ],
                  ),
                ),
                _buildCheckoutButton(context, appService, cartService, total),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingS),
      child: Text(
        title,
        style: AppTypography.titleLg(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return EmptyStateWidget(
      title: 'Votre panier est vide',
      message: 'Ajoutez des plats avant de commander.',
      illustration: AppEmojis.cart,
      actionText: 'Voir le menu',
      onAction: () => context.goBack(),
    );
  }

  Widget _buildOrderSummary(
    BuildContext context,
    List<CartItem> cartItems,
    double subtotal,
    double deliveryFee,
    double discount,
    double total,
    int itemCount,
    String? promoCode,
  ) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...cartItems.map((item) => _buildOrderItem(context, item)),
          const SummaryDivider(),
          SummaryRow(
            label: 'Sous-total',
            subtitle:
                '${cartItems.length} article${cartItems.length > 1 ? 's' : ''}',
            value: PriceFormatter.format(subtotal),
          ),
          SummaryRow(
            label: 'Livraison',
            value: PriceFormatter.format(deliveryFee),
          ),
          if (discount > 0)
            SummaryRow(
              label: 'Remise${promoCode != null ? ' ($promoCode)' : ''}',
              value: '-${PriceFormatter.format(discount)}',
              isDiscount: true,
            ),
          const SummaryDivider(),
          SummaryRow(
            label: 'Total',
            value: PriceFormatter.format(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Une ligne du récapitulatif : vignette, nom, quantité, total de ligne.
  ///
  /// La personnalisation choisie est reprise ici — c'est la dernière occasion
  /// de vérifier qu'on commande bien ce qu'on a composé, et l'ancienne version
  /// ne l'affichait nulle part.
  Widget _buildOrderItem(BuildContext context, CartItem item) {
    final theme = Theme.of(context);
    final personnalisation = item.customization;
    final resume = (personnalisation != null && personnalisation.isNotEmpty)
        ? personnalisation.entries
            .where((e) => e.key != 'note' || personnalisation.length == 1)
            .map((e) => '${e.key}: ${e.value}')
            .join(', ')
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingS + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DesignConstants.borderRadiusSmall,
            child: SizedBox(
              width: 44,
              height: 44,
              child: FoodImage(url: item.imageUrl, iconSize: 20),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingS + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.quantity} × ${item.name}',
                  style: AppTypography.bodyLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (resume.isNotEmpty)
                  Text(
                    resume,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DesignConstants.spacingS),
          Text(
            PriceFormatter.format(item.totalPrice),
            style: AppTypography.bodyLg(color: theme.colorScheme.onSurface)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Adresse de livraison, sous forme de carte cliquable.
  ///
  /// Le champ de texte désactivé qu'affichait la version précédente était un
  /// leurre : il ressemblait à une saisie, ne s'ouvrait jamais, et il fallait
  /// trouver le bouton « Changer » à côté. La carte entière ouvre désormais le
  /// sélecteur, ce que le chevron annonce.
  Widget _buildDeliverySection(BuildContext context) {
    final theme = Theme.of(context);
    final adresse = _selectedAddress;

    return Column(
      children: [
        SectionCard(
          onTap: _selectAddress,
          borderColor: (_adresseReclamee && adresse == null)
              ? theme.colorScheme.error
              : null,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: DesignConstants.borderRadiusMedium,
                ),
                child: Icon(
                  adresse == null
                      ? Icons.add_location_alt_outlined
                      : Icons.location_on_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      adresse == null
                          ? 'Choisir une adresse'
                          : (adresse.label.isNotEmpty
                              ? adresse.label
                              : adresse.line1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      adresse == null
                          ? 'Obligatoire pour estimer la livraison'
                          : _addressController.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        // Le validateur du formulaire porte toujours sur l'adresse : il est
        // resté sur un champ, désormais invisible, pour que `_placeOrder`
        // continue de refuser une commande sans destination.
        Offstage(
          child: TextFormField(
            controller: _addressController,
            enabled: false,
            validator: (_) => _selectedAddress == null
                ? 'Veuillez sélectionner une adresse'
                : null,
          ),
        ),
        if (_isCalculatingDeliveryFee) ...[
          const SizedBox(height: DesignConstants.spacingM),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: DesignConstants.spacingS + 4),
              Text(
                'Calcul des frais de livraison…',
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (_deliveryBreakdown != null && !_isCalculatingDeliveryFee) ...[
          const SizedBox(height: DesignConstants.spacingM),
          DeliveryFeeBreakdownCard(
            breakdown: _deliveryBreakdown!,
            showTitle: false,
          ),
        ],
      ],
    );
  }

  /// Modes de paiement, en lignes plutôt qu'en puces.
  ///
  /// ## Pourquoi les modes indisponibles restent affichés
  ///
  /// Mobile Money et les cartes ne sont pas encore raccordés. Les masquer
  /// laisserait croire qu'ils n'existeront jamais et ferait douter du sérieux
  /// du service ; les afficher à demi-opacité, comme avant, laissait croire à
  /// un bogue. Ils portent donc une mention explicite — « bientôt » — et ne
  /// répondent pas au toucher.
  ///
  /// Le portefeuille, lui, est bien retiré : il n'est pas différé, il est
  /// abandonné.
  Widget _buildPaymentSection(BuildContext context) {
    final theme = Theme.of(context);
    final modes = PaymentMethod.values
        .where((method) => method != PaymentMethod.wallet)
        .toList();

    return Column(
      children: [
        for (final mode in modes) ...[
          Builder(
            builder: (context) {
              final indisponible = mode == PaymentMethod.mobileMoney ||
                  mode == PaymentMethod.creditCard ||
                  mode == PaymentMethod.debitCard;
              final retenu = _selectedPayment == mode && !indisponible;

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: DesignConstants.spacingS + 2,
                ),
                child: SectionCard(
                  padding: const EdgeInsets.all(DesignConstants.spacingS + 4),
                  borderColor: retenu ? theme.colorScheme.primary : null,
                  onTap: indisponible
                      ? null
                      : () => setState(() => _selectedPayment = mode),
                  child: Row(
                    children: [
                      Icon(
                        retenu
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: indisponible
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35)
                            : retenu
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: DesignConstants.spacingM),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: DesignConstants.borderRadiusMedium,
                        ),
                        child: Icon(
                          mode.icone,
                          size: 20,
                          color: indisponible
                              ? theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.35)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: DesignConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mode.displayName,
                              style: AppTypography.titleLg(
                                color: indisponible
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              mode.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMd(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (indisponible) ...[
                        const SizedBox(width: DesignConstants.spacingS),
                        const StatusChip(label: 'Bientôt', dense: true),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Ex. : sonner à la porte, laisser à l’accueil…',
          fillColor: theme.colorScheme.surfaceContainerLow,
        ),
      ),
    );
  }

  /// Accès au code promotionnel, depuis le règlement.
  ///
  /// C'est ici, et pas seulement au panier, parce que l'adresse est désormais
  /// connue : le devis que le serveur renvoie tient alors compte des frais de
  /// livraison réels, dont certains codes dépendent. Le panier garde sa saisie
  /// rapide pour les codes qui ne portent que sur le sous-total.
  Widget _buildPromoSection(BuildContext context, CartService cartService) {
    final theme = Theme.of(context);
    final code = cartService.promoCode;
    final applique = code != null && code.isNotEmpty;

    return SectionCard(
      onTap: () => context.navigateToPromoCodes(
        _selectedAddress?.id,
        (_, __) async {
          // Le code est déjà posé sur le panier par l'écran de saisie ; il
          // reste à refaire chiffrer la commande pour que les frais et le
          // total affichés ici tiennent compte de la remise.
          await _calculateDeliveryFeeForAddress(_selectedAddress);
        },
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: DesignConstants.borderRadiusMedium,
            ),
            child: Icon(
              applique
                  ? Icons.local_activity_rounded
                  : Icons.local_activity_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  applique ? code : 'Ajouter un code promo',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  applique
                      ? 'Remise de ${PriceFormatter.format(cartService.discount)}'
                      : 'Si vous en avez un',
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    AppService appService,
    CartService cartService,
    double total,
  ) {
    return GlassBottomBar(
      child: StickySummaryBar(
        label: 'Total à payer',
        amount: PriceFormatter.format(total),
        action: ActionButton(
          label: 'Commander',
          emphasis: ActionEmphasis.gradient,
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: _isLoading,
          onPressed: _isLoading
              ? null
              : () => _placeOrder(context, appService, cartService, total),
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    BuildContext context,
    AppService appService,
    CartService cartService,
    double total,
  ) async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _adresseReclamee = _selectedAddress == null);
      return;
    }

    // Le géocodage de rattrapage qui se trouvait ici — deux passes, dont une
    // qui affichait « Géocodage de l'adresse en cours… » au moment de payer —
    // n'a plus d'objet : une adresse du carnet porte toujours son point, et
    // elle existe toujours côté serveur.
    setState(() {
      _isLoading = true;
    });

    try {
      final addressToUse = _selectedAddress;

      if (addressToUse == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choisissez une adresse de livraison.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Créer la commande d'abord (Django, Phase 6) — le paiement s'ouvre
      // ensuite contre une commande réelle, jamais l'inverse.
      //
      // La commande de groupe ne passe plus par ici : elle naît de la
      // confirmation du panier collaboratif (`group-carts/{id}/confirm/`), qui
      // est le seul chemin où le serveur sait répartir les lignes entre
      // convives.
      final finalOrderId = await appService.placeOrderFromCartService(
          addressToUse,
          _selectedPayment,
          cartService.items,
          cartService.subtotal,
          cartService.deliveryFee,
          cartService.discount,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // `context.mounted` et non `mounted` : le contexte utilisé ici est celui
      // que la méthode reçoit en paramètre, pas celui de l'état.
      if (finalOrderId.isNotEmpty && context.mounted) {
        cartService.clear();
        // Le paiement se règle par webhook signé, jamais par le retour de
        // cet écran (`apps/payments/services.py`) — la commande existe déjà
        // quelle que soit l'issue.
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (context) => PaymentScreen(orderId: finalOrderId)),
        );
      }

      if (finalOrderId.isNotEmpty && mounted) {
        // Naviguer vers l'écran de suivi de commande
        if (mounted && context.mounted) {
          await context.navigateToDeliveryTracking(finalOrderId);
        }

        // Afficher un message de succès
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commande #$finalOrderId passée avec succès'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        // Capturer les valeurs nécessaires avant le gap async
        final errorColor = Theme.of(context).colorScheme.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Le `detail` du serveur, pas le `toString()` de l'exception :
            // `problem+json` porte un motif écrit pour être lu — « Cet article
            // n'est plus disponible », « Minimum de commande non atteint » —
            // là où `ApiException(409, conflict, …)` ne dit rien à personne.
            // Même traitement que le devis, quelques lignes plus haut.
            content: Text(_motif(e)),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Ce qu'il faut montrer d'un échec de commande.
  ///
  /// Le réseau est distingué du refus métier : « Impossible de joindre le
  /// serveur » invite à réessayer, un motif métier invite à corriger quelque
  /// chose. Les confondre sous un même message générique fait réessayer en
  /// boucle une commande que le serveur refusera toujours.
  String _motif(Object erreur) {
    if (erreur is eccore.ApiException) {
      if (erreur.code == 'network_error') {
        return "Connexion perdue : votre commande n'a pas été envoyée. "
            'Réessayez une fois le réseau revenu.';
      }
      if (erreur.isThrottled) {
        return 'Trop de tentatives coup sur coup. Patientez un instant.';
      }
      return erreur.detail;
    }
    return 'Commande impossible pour le moment. Réessayez.';
  }
}
