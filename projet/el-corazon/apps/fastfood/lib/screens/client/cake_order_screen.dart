import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/repositories/django_menu_repository.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/presentation/preselection_gateau.dart';
import 'package:elcora_fast/presentation/recapitulatif_gateau.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

enum CakeDeliveryMethod { delivery, pickup }

/// Commande de gâteau : le catalogue prêt à commander, et l'atelier sur mesure.
///
/// ## Ce que la maquette `cake_order` demande
///
/// Une **suite d'étapes numérotées** qui défile d'un trait — « 1. Parfum de
/// base », « 2. Glaçage », « 3. Taille », « 4. Message », « 5. Date » — et un
/// bandeau ancré en bas qui porte le total estimé à côté de l'action. C'est
/// exactement ce que rend l'onglet « Sur mesure » ci-dessous.
///
/// Les numéros ne sont pas écrits dans le code : ils suivent l'ordre des
/// groupes que le **catalogue** publie pour l'article. Un établissement qui
/// n'offre pas de glaçage n'a pas d'étape 2 vide — il a une étape 2 qui est
/// autre chose.
///
/// ## Pourquoi deux onglets là où Stitch n'en dessine qu'un
///
/// La maquette ne couvre que la composition sur mesure. Le catalogue de
/// gâteaux déjà composés, lui, existe et se commande — le retirer pour coller
/// au dessin supprimerait une fonction. Les deux vivent donc sous le même
/// toit, séparés par une bascule, et seule la composition porte le bandeau
/// inférieur : le catalogue n'a pas de total à annoncer.
class CakeOrderScreen extends StatefulWidget {
  const CakeOrderScreen({super.key});

  @override
  State<CakeOrderScreen> createState() => _CakeOrderScreenState();
}

class _CakeOrderScreenState extends State<CakeOrderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _customizationId;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  DateTime? _customDeliveryDate;
  TimeOfDay? _customDeliveryTime;
  bool _isSubmitting = false;
  bool _isDisposed = false;
  bool _isInitializingCustomization = false;
  CakeDeliveryMethod _deliveryMethod = CakeDeliveryMethod.delivery;

  List<eccore.MenuItem> _readyCakes = [];
  eccore.MenuItem? _customCakeItem;

  /// Vrai quand [_customCakeItem] vient réellement du catalogue.
  ///
  /// Faux, l'article affiché est la maquette en mémoire : son identifiant
  /// n'existe pas côté serveur, aucune commande ne peut en naître. L'écran
  /// laisse alors composer — c'est une vitrine utile — mais refuse
  /// explicitement l'ajout au panier, là où l'ancienne version y déposait une
  /// ligne que la synchronisation rejetait ensuite en silence.
  bool _customCakeIsFromCatalog = false;

  String? _dessertsCategoryId;
  bool _isLoading = true;
  String? _error;

  /// Ordre de présentation des familles d'options, du plus structurant au plus
  /// décoratif. Une famille absente de cette liste passe à la fin, par ordre
  /// alphabétique — le catalogue peut donc en publier de nouvelles sans que
  /// cet écran soit retouché.
  static const _ordreDesFamilles = [
    'shape',
    'size',
    'flavor',
    'tiers',
    'color',
    'texture',
    'icing',
    'filling',
    'decoration',
    'dietary',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Le bandeau inférieur n'appartient qu'à l'onglet « Sur mesure » : sans
    // cette écoute, il resterait affiché au-dessus du catalogue, à annoncer le
    // total d'une composition qu'on ne regarde pas.
    _tabController.addListener(() {
      if (!_isDisposed && mounted) setState(() {});
    });
    _customizationId = _generateCustomizationId();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCakesFromDatabase();
      if (!_isDisposed && _customCakeItem != null) {
        await _initializeCustomization();
      }
    });
  }

  // ------------------------------------------------------------- chargement

  Future<void> _loadCakesFromDatabase() async {
    if (_isDisposed || !mounted || !context.mounted) return;

    if (!_isDisposed && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      if (!mounted || !context.mounted) return;
      final menuRepository = DjangoMenuRepository();

      final categories = await menuRepository.getMenuCategories();
      final dessertsCategory = categories
          .where((cat) => cat.name.toLowerCase().contains('dessert'))
          .firstOrNull;

      _dessertsCategoryId = dessertsCategory?.id;

      if (_dessertsCategoryId == null) {
        Journal.trace(
          '⚠️ Catégorie desserts non trouvée, chargement de tous les items',
        );
      }

      _readyCakes = (await menuRepository.getMenuItems(
        categoryId: _dessertsCategoryId,
      ))
          .where((item) => item.isAvailable)
          .toList();

      await _loadCustomCakeItem(menuRepository);

      if (!_isDisposed && mounted && context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      Journal.trace('✅ ${_readyCakes.length} gâteaux chargés du catalogue');
    } catch (e) {
      Journal.trace('❌ Chargement des gâteaux: $e');
      if (!_isDisposed && mounted && context.mounted) {
        setState(() {
          _error = 'Impossible de charger les gâteaux pour le moment.';
          _isLoading = false;
        });
      }
    }
  }

  /// Retrouve l'article « Gâteau personnalisé » du catalogue, sinon en
  /// fabrique un en mémoire.
  ///
  /// L'ancienne version le **créait dans le catalogue** quand il manquait :
  /// écrire un article depuis l'app client n'est plus possible, et ne devrait
  /// jamais l'avoir été — le catalogue s'écrit depuis le back-office
  /// (`catalog/manage/items/`, permission `catalog.write`). Le repli en
  /// mémoire, lui, existait déjà : c'est le comportement nominal désormais
  /// tant que l'établissement n'a pas publié l'article.
  Future<void> _loadCustomCakeItem(DjangoMenuRepository menuRepository) async {
    try {
      final customCake = (await menuRepository.getMenuItems())
          .where(
            (item) =>
                item.name.toLowerCase().contains('personnalisé') ||
                item.name.toLowerCase().contains('custom'),
          )
          .firstOrNull;

      if (customCake != null) {
        _customCakeItem = customCake;
        _customCakeIsFromCatalog = true;
        Journal.trace(
          '✅ Gâteau personnalisé trouvé au catalogue : ${customCake.id}',
        );
        return;
      }

      _customCakeIsFromCatalog = false;
      _customCakeItem = _gateauEnApercu(
        id: 'cake-custom-${DateTime.now().millisecondsSinceEpoch}',
      );
      Journal.trace('⚠️ Gâteau personnalisé absent du catalogue, aperçu local');
    } catch (e) {
      Journal.trace('❌ Chargement du gâteau personnalisé: $e');
      _customCakeIsFromCatalog = false;
      _customCakeItem = _gateauEnApercu(id: 'cake-custom-default');
    }
  }

  Future<void> _initializeCustomization({eccore.MenuItem? prefillFrom}) async {
    if (_isInitializingCustomization) {
      Journal.trace('⚠️ Initialisation déjà en cours, annulation...');
      return;
    }

    if (_customCakeItem == null) {
      Journal.trace('⚠️ Aucun gâteau à composer, initialisation abandonnée');
      return;
    }

    if (_isDisposed || !mounted || !context.mounted) return;

    _isInitializingCustomization = true;

    try {
      final customizationService =
          Provider.of<CustomizationService>(context, listen: false);

      if (!customizationService.isInitialized) {
        await customizationService.initialize();
      }
      if (!mounted || !context.mounted) return;

      await customizationService.startCustomization(
        _customizationId,
        _customCakeItem!.id,
        _customCakeItem!.name,
      );

      if (prefillFrom != null) {
        _applySmartPrefill(customizationService, prefillFrom);
      }

      if (!_isDisposed && mounted) {
        setState(() {});
      }
    } catch (e) {
      Journal.trace('❌ Initialisation de la personnalisation: $e');
      if (!_isDisposed && mounted && context.mounted) {
        context.showErrorMessage('Impossible de charger les options.');
      }
    } finally {
      _isInitializingCustomization = false;
    }
  }

  /// Le gâteau sur mesure **tel qu'on le montre** quand le catalogue ne le
  /// publie pas.
  ///
  /// Ce n'est pas un article commandable : `_customCakeIsFromCatalog` reste
  /// faux et l'écran affiche `_avisNonPublie`. Il n'existe que pour que les
  /// options aient un support à afficher.
  ///
  /// Son image est **nulle**, et non l'adresse d'une photo de banque : montrer
  /// un gâteau qui n'est pas celui de l'établissement promet ce que personne
  /// ne livrera, et fait dépendre l'écran d'un hôte extérieur. `FoodImage`
  /// rend à la place la plaque teintée du design system.
  eccore.MenuItem _gateauEnApercu({required String id}) {
    return eccore.MenuItem(
      id: id,
      restaurantSlug: AppConstants.restaurantSlug,
      categorySlug: _dessertsCategoryId ?? '',
      categoryName: 'Desserts',
      name: 'Gâteau personnalisé',
      slug: 'gateau-personnalise',
      description:
          'Composez votre gâteau idéal : forme, taille, saveur et décor.',
      image: null,
      price: const eccore.Money(amountMinor: 2000000, currency: 'XOF'),
      preparationMinutes: 90,
      allergens: const [],
      dietaryTags: const [],
      isAvailable: false,
      isPopular: true,
      vipExclusive: false,
      ratingAverage: 0,
      ratingCount: 0,
      sortOrder: 0,
    );
  }

  void _applySmartPrefill(CustomizationService service, eccore.MenuItem cake) {
    final suggerees = optionsSuggereesPar(
      '${cake.name} ${cake.description}',
      service.getOptionsForMenuItem(
        _customCakeItem!.id,
        fallbackName: _customCakeItem!.name,
      ),
    );

    var prefilledCount = 0;

    for (final option in suggerees) {
      // Une catégorie à choix unique ne se laisse pré-cocher que si elle est
      // encore vide — sinon la suggestion écraserait un choix déjà fait.
      if (_constraintFor(service, option.category).isSingleChoice) {
        final dejaChoisies = service
            .getCurrentCustomization(_customizationId)
            ?.selections[option.category];
        final libre = dejaChoisies == null ||
            dejaChoisies.isEmpty ||
            dejaChoisies.contains(option.id);
        if (!libre) continue;
      }

      service.updateSelection(
        _customizationId,
        option.category,
        option.id,
        true,
      );
      prefilledCount++;
    }

    if (prefilledCount > 0 && mounted && context.mounted) {
      context.showSuccessMessage(
        'Composition amorcée depuis « ${cake.name} » ($prefilledCount options)',
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    try {
      if (mounted && context.mounted) {
        Provider.of<CustomizationService>(context, listen: false)
            .clearCustomization(_customizationId);
      }
    } catch (e) {
      Journal.trace('⚠️ Nettoyage de la personnalisation: $e');
    }

    _messageController.dispose();
    _contactController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surMesure = _tabController.index == 1;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Commander un gâteau',
        actions: [
          GlassIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Comment ça marche',
            filled: false,
            onPressed: _expliquerLeDelai,
          ),
          Consumer<CartService>(
            builder: (context, cartService, child) => GlassIconButton(
              icon: Icons.shopping_cart_outlined,
              tooltip: 'Voir le panier',
              filled: false,
              badge: cartService.itemCount,
              onPressed: () => context.navigateToCart(),
            ),
          ),
        ],
        bottom: _Bascule(controller: _tabController),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ongletCatalogue(),
          _ongletSurMesure(theme),
        ],
      ),
      bottomNavigationBar: surMesure ? _bandeauSurMesure(theme) : null,
    );
  }

  void _expliquerLeDelai() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignConstants.radiusXLarge),
        ),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              0,
              DesignConstants.edgeMargin,
              DesignConstants.spacingL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commander un gâteau',
                  style: AppTypography.headlineSm(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingM),
                for (final ligne in const [
                  (
                    Icons.cake_outlined,
                    'Au catalogue',
                    'Les gâteaux déjà composés partent au panier avec un créneau de retrait ou de livraison.',
                  ),
                  (
                    Icons.tune_rounded,
                    'Sur mesure',
                    'Chaque étape reprend les options que la pâtisserie publie : forme, taille, parfum, décor.',
                  ),
                  (
                    Icons.schedule_rounded,
                    'Au moins 24 heures',
                    'Un gâteau sur mesure se prépare la veille : le créneau doit être à plus de 24 heures.',
                  ),
                ]) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ligne.$1,
                        size: DesignConstants.iconSizeMedium,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: DesignConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ligne.$2,
                              style: AppTypography.titleLg(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ligne.$3,
                              style: AppTypography.bodyMd(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignConstants.spacingM),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------- onglet catalogue

  Widget _ongletCatalogue() {
    if (_isLoading) {
      return const FoodCardSkeletonList();
    }

    if (_error != null) {
      return etats.ErrorWidget(
        message: _error!,
        onRetry: _loadCakesFromDatabase,
      );
    }

    if (_readyCakes.isEmpty) {
      return const etats.EmptyStateWidget(
        title: 'Aucun gâteau à la carte',
        message:
            'La pâtisserie n’a rien publié pour le moment. Composez le vôtre sur mesure.',
        icon: Icons.cake_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCakesFromDatabase,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingM,
          DesignConstants.edgeMargin,
          DesignConstants.spacingXL,
        ),
        itemCount: _readyCakes.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: DesignConstants.spacingM),
        itemBuilder: (context, index) => _carteDeGateau(_readyCakes[index]),
      ),
    );
  }

  /// Un gâteau du catalogue : la carte du design system, plus les deux gestes
  /// que cet écran ajoute — composer à partir de lui, ou le commander tel quel.
  Widget _carteDeGateau(eccore.MenuItem cake) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FoodCard(
          item: cake,
          onTap: () => _handleReadyCakeOrder(cake),
          trailingBadge: cake.isPopular
              ? const StatusChip(
                  label: 'Populaire',
                  icon: Icons.local_fire_department_rounded,
                )
              : null,
        ),
        const SizedBox(height: DesignConstants.spacingS),
        Row(
          children: [
            Expanded(
              child: ActionButton(
                label: 'Personnaliser',
                emphasis: ActionEmphasis.outlined,
                icon: Icons.tune_rounded,
                height: 44,
                onPressed: () async {
                  await _resetCustomization(
                    Provider.of<CustomizationService>(context, listen: false),
                    prefillFrom: cake,
                  );
                  _tabController.animateTo(1);
                },
              ),
            ),
            const SizedBox(width: DesignConstants.gutter),
            Expanded(
              child: ActionButton(
                label: 'Commander',
                icon: Icons.add_shopping_cart_rounded,
                height: 44,
                onPressed: () => _handleReadyCakeOrder(cake),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------- onglet sur mesure

  Widget _ongletSurMesure(ThemeData theme) {
    if (_isLoading) {
      return const etats.PageLoadingWidget(
        message: 'Chargement de l’atelier…',
      );
    }

    if (_customCakeItem == null) {
      return const etats.EmptyStateWidget(
        title: 'Atelier indisponible',
        message: 'Le gâteau sur mesure n’est pas accessible pour le moment.',
        icon: Icons.cake_outlined,
      );
    }

    return Consumer<CustomizationService>(
      builder: (context, service, child) {
        final optionsByCategory = service.getOptionsByCategory(
          _customCakeItem!.id,
          fallbackName: _customCakeItem!.name,
        );
        final customization = service.getCurrentCustomization(_customizationId);

        if (optionsByCategory.isEmpty || customization == null) {
          return const etats.PageLoadingWidget(
            message: 'Chargement des options…',
          );
        }

        final familles = optionsByCategory.entries.toList()
          ..sort((a, b) {
            final indexA = _ordreDesFamilles.indexOf(a.key);
            final indexB = _ordreDesFamilles.indexOf(b.key);
            if (indexA == -1 && indexB == -1) return a.key.compareTo(b.key);
            if (indexA == -1) return 1;
            if (indexB == -1) return -1;
            return indexA.compareTo(indexB);
          });

        final priceModifier = service.calculatePriceModifier(_customizationId);
        final finalPrice = _customCakeItem!.prixAffiche + priceModifier;

        // Commandable seulement si l'article **et** ses options viennent du
        // catalogue : sans les deux, la ligne déposée au panier serait refusée
        // par le serveur, et l'était en silence.
        final isOrderable = _customCakeIsFromCatalog &&
            service.hasRemoteOptions(
              _customCakeItem!.id,
              fallbackName: _customCakeItem!.name,
            );

        var etape = 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            DesignConstants.edgeMargin,
            DesignConstants.spacingM,
            DesignConstants.edgeMargin,
            DesignConstants.spacingL,
          ),
          children: [
            RecapitulatifGateau(
              gateau: _customCakeItem!,
              customizationId: _customizationId,
              priceModifier: priceModifier,
              finalPrice: finalPrice,
            ),
            if (!isOrderable) ...[
              const SizedBox(height: DesignConstants.spacingM),
              _avisNonPublie(theme),
            ],
            for (final famille in familles) ...[
              const SizedBox(height: DesignConstants.spacingM),
              _etape(
                numero: ++etape,
                categorie: famille.key,
                options: famille.value,
                selectedIds: customization.selections[famille.key] ?? const [],
                service: service,
              ),
            ],
            const SizedBox(height: DesignConstants.spacingM),
            _etapeMessage(theme, service, numero: ++etape),
            const SizedBox(height: DesignConstants.spacingM),
            _etapeCreneau(theme, numero: ++etape),
          ],
        );
      },
    );
  }

  /// Le bandeau ancré : total estimé à gauche, action à droite.
  ///
  /// C'est le « Estimated Total / Order Cake » de la maquette. Il vit hors du
  /// défilement pour que le montant reste lisible pendant qu'on compose —
  /// l'ancienne version posait le bouton en fin de page, après six familles
  /// d'options.
  Widget _bandeauSurMesure(ThemeData theme) {
    return Consumer<CustomizationService>(
      builder: (context, service, child) {
        if (_customCakeItem == null) return const SizedBox.shrink();

        final priceModifier = service.calculatePriceModifier(_customizationId);
        final finalPrice = _customCakeItem!.prixAffiche + priceModifier;
        final isOrderable = _customCakeIsFromCatalog &&
            service.hasRemoteOptions(
              _customCakeItem!.id,
              fallbackName: _customCakeItem!.name,
            );

        return GlassBottomBar(
          child: StickySummaryBar(
            label: 'Total estimé',
            amount: PriceFormatter.format(finalPrice),
            action: ActionButton(
              label: 'Commander',
              emphasis: ActionEmphasis.gradient,
              icon: Icons.cake_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting || !isOrderable
                  ? null
                  : () => _confirmCustomCakeOrder(service),
            ),
          ),
        );
      },
    );
  }

  /// Contrainte de la catégorie pour l'article en cours de composition.
  CategoryConstraint _constraintFor(
    CustomizationService service,
    String category,
  ) {
    return service.constraintFor(
      _customCakeItem!.id,
      category,
      fallbackName: _customCakeItem!.name,
    );
  }

  /// Dit pourquoi la composition ne peut pas être commandée : l'établissement
  /// n'a pas publié l'article « Gâteau personnalisé » au catalogue.
  ///
  /// Le dire ici plutôt que d'échouer au panier — l'ancienne version acceptait
  /// l'ajout, et la ligne disparaissait à la première synchronisation.
  Widget _avisNonPublie(ThemeData theme) {
    return SectionCard(
      color: theme.colorScheme.errorContainer,
      borderColor: theme.colorScheme.error.withValues(alpha: 0.3),
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: DesignConstants.iconSizeMedium,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande sur mesure indisponible',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(
                  'Le gâteau personnalisé n’est pas encore publié à la carte. '
                  'Les étapes ci-dessous sont un aperçu : contactez la '
                  'boutique pour composer votre gâteau.',
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- les étapes

  /// Une famille d'options, présentée comme une étape numérotée.
  ///
  /// Le rendu dépend de ce que la famille désigne : des pastilles pour les
  /// couleurs, des tuiles pour les textures, des lignes à cocher pour tout le
  /// reste. Ces trois formes disent la même chose au service — une sélection
  /// dans une catégorie — mais une couleur ne se choisit pas dans une liste.
  Widget _etape({
    required int numero,
    required String categorie,
    required List<CustomizationOption> options,
    required List<String> selectedIds,
    required CustomizationService service,
  }) {
    final contrainte = _constraintFor(service, categorie);
    final titre = '$numero. ${service.translateCategory(categorie)}';

    final Widget corps;
    if (categorie == 'color') {
      corps = _pastillesDeCouleur(options, selectedIds, contrainte, service);
    } else if (categorie == 'texture') {
      corps = _tuilesDeTexture(options, selectedIds, contrainte, service);
    } else {
      corps = Column(
        children: [
          for (var i = 0; i < options.length; i++)
            OptionRow(
              label: options[i].name,
              subtitle: options[i].description,
              selected: selectedIds.contains(options[i].id),
              multiple: !contrainte.isSingleChoice,
              priceDelta: options[i].priceModifier == 0
                  ? null
                  : '+${PriceFormatter.format(options[i].priceModifier)}',
              showDivider: i < options.length - 1,
              onChanged: (coche) => _basculer(
                service,
                categorie,
                options[i].id,
                coche,
                selectedIds,
                contrainte,
              ),
            ),
        ],
      );
    }

    return OptionGroupCard(
      title: titre,
      isRequired: contrainte.isRequired,
      constraintLabel: _libelleContrainte(contrainte, selectedIds.length),
      children: [corps],
    );
  }

  /// Ce que la famille attend, dit en clair sous son titre.
  String? _libelleContrainte(CategoryConstraint contrainte, int retenues) {
    if (contrainte.isSingleChoice) return 'Un seul choix';
    if (contrainte.maxSelections >= 99) return null;
    final reste = contrainte.maxSelections - retenues;
    return reste <= 0
        ? 'Maximum atteint (${contrainte.maxSelections})'
        : 'Jusqu’à ${contrainte.maxSelections} • $reste restant${reste > 1 ? 's' : ''}';
  }

  /// Retient ou retire une option, en tenant les bornes de sa famille.
  ///
  /// L'exclusivité et le plafond sont portés ici et non par le service :
  /// celui-ci enregistre des sélections par catégorie sans savoir laquelle en
  /// admet plusieurs.
  void _basculer(
    CustomizationService service,
    String categorie,
    String optionId,
    bool coche,
    List<String> retenues,
    CategoryConstraint contrainte,
  ) {
    if (contrainte.isSingleChoice) {
      if (!coche) return;
      _handleSingleSelection(service, categorie, optionId, retenues);
      return;
    }

    if (coche && retenues.length >= contrainte.maxSelections) {
      context.showErrorMessage(
        '${service.translateCategory(categorie)} : '
        '${contrainte.maxSelections} option(s) au maximum.',
      );
      return;
    }

    _handleMultiSelection(service, categorie, optionId, coche);
  }

  Widget _etapeMessage(
    ThemeData theme,
    CustomizationService service, {
    required int numero,
  }) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreDEtape(
            theme,
            '$numero. Message sur le gâteau',
            complement: 'Optionnel',
          ),
          const SizedBox(height: DesignConstants.spacingM),
          TextField(
            controller: _messageController,
            maxLength: 60,
            style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
            decoration: const InputDecoration(
              hintText: 'Ex. : Joyeux anniversaire Jade !',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            onChanged: (value) => service.updateSpecialInstructions(
              _customizationId,
              value.trim(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etapeCreneau(ThemeData theme, {required int numero}) {
    final dateLabel = _customDeliveryDate == null
        ? 'Choisir une date'
        : _formatDate(_customDeliveryDate!);
    final timeLabel = _customDeliveryTime == null
        ? 'Choisir une heure'
        : _customDeliveryTime!.format(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreDEtape(theme, '$numero. Retrait ou livraison'),
          const SizedBox(height: DesignConstants.spacingM),
          _choixDuMode(theme),
          if (_deliveryMethod == CakeDeliveryMethod.delivery) ...[
            const SizedBox(height: DesignConstants.spacingM),
            TextField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Contact pour la livraison',
                hintText: 'Ex. : +225 07 07 07 07 07',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
          ],
          const SizedBox(height: DesignConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: dateLabel,
                  emphasis: _customDeliveryDate == null
                      ? ActionEmphasis.outlined
                      : ActionEmphasis.primary,
                  icon: Icons.calendar_month_rounded,
                  height: 48,
                  onPressed: _pickCustomDeliveryDate,
                ),
              ),
              const SizedBox(width: DesignConstants.gutter),
              Expanded(
                child: ActionButton(
                  label: timeLabel,
                  emphasis: _customDeliveryTime == null
                      ? ActionEmphasis.outlined
                      : ActionEmphasis.primary,
                  icon: Icons.schedule_rounded,
                  height: 48,
                  onPressed:
                      _customDeliveryDate == null ? null : _pickCustomDeliveryTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            'Un gâteau sur mesure demande au moins 24 heures de préparation.',
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titreDEtape(ThemeData theme, String titre, {String? complement}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titre,
            style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
          ),
        ),
        if (complement != null) ...[
          const SizedBox(width: DesignConstants.spacingS),
          StatusChip(
            label: complement,
            background: theme.colorScheme.surfaceContainerHigh,
            foreground: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }

  /// Livraison ou retrait, en deux moitiés d'une même pilule.
  Widget _choixDuMode(ThemeData theme) {
    Widget moitie({
      required CakeDeliveryMethod mode,
      required IconData icone,
      required String libelle,
      required BorderRadius rayon,
    }) {
      final actif = _deliveryMethod == mode;
      return Expanded(
        child: Material(
          color: actif ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: rayon,
          child: InkWell(
            borderRadius: rayon,
            onTap: () => setState(() => _deliveryMethod = mode),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignConstants.spacingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icone,
                    size: DesignConstants.iconSizeSmall + 2,
                    color: actif
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: DesignConstants.spacingS),
                  Flexible(
                    child: Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLg(
                        color: actif
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
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

    const rayonGauche = BorderRadius.horizontal(
      left: Radius.circular(DesignConstants.radiusMedium),
    );
    const rayonDroit = BorderRadius.horizontal(
      right: Radius.circular(DesignConstants.radiusMedium),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: DesignConstants.borderRadiusMedium,
      ),
      child: Row(
        children: [
          moitie(
            mode: CakeDeliveryMethod.delivery,
            icone: Icons.delivery_dining_rounded,
            libelle: 'Livraison',
            rayon: rayonGauche,
          ),
          moitie(
            mode: CakeDeliveryMethod.pickup,
            icone: Icons.storefront_rounded,
            libelle: 'Retrait',
            rayon: rayonDroit,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- sélecteurs spécialisés

  Widget _pastillesDeCouleur(
    List<CustomizationOption> options,
    List<String> selectedIds,
    CategoryConstraint contrainte,
    CustomizationService service,
  ) {
    return Wrap(
      spacing: DesignConstants.gutter,
      runSpacing: DesignConstants.gutter,
      children: [
        for (final option in options)
          _Pastille(
            couleur: _couleurDOption(option.id),
            nom: option.name,
            selectionnee: selectedIds.contains(option.id),
            onTap: () => _basculer(
              service,
              'color',
              option.id,
              !selectedIds.contains(option.id),
              selectedIds,
              contrainte,
            ),
          ),
      ],
    );
  }

  Widget _tuilesDeTexture(
    List<CustomizationOption> options,
    List<String> selectedIds,
    CategoryConstraint contrainte,
    CustomizationService service,
  ) {
    return Wrap(
      spacing: DesignConstants.gutter,
      runSpacing: DesignConstants.gutter,
      children: [
        for (final option in options)
          _Tuile(
            degrade: _degradeDeTexture(option.id),
            nom: option.name,
            selectionnee: selectedIds.contains(option.id),
            onTap: () => _basculer(
              service,
              'texture',
              option.id,
              !selectedIds.contains(option.id),
              selectedIds,
              contrainte,
            ),
          ),
      ],
    );
  }

  /// La couleur qu'une pastille montre.
  ///
  /// Ce sont de vraies couleurs de glaçage, pas des jetons du design system :
  /// une pastille « rose » teintée au rouge de la marque mentirait sur ce que
  /// la pâtisserie va poser sur le gâteau.
  Color _couleurDOption(String optionId) {
    switch (optionId) {
      case 'cake-color-white':
        return const Color(0xFFFFFFFF);
      case 'cake-color-pink':
        return const Color(0xFFF48FB1);
      case 'cake-color-blue':
        return const Color(0xFF90CAF9);
      case 'cake-color-purple':
        return const Color(0xFFCE93D8);
      case 'cake-color-gradient':
        return const Color(0xFFBA68C8);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  LinearGradient _degradeDeTexture(String optionId) {
    const enHaut = Alignment.topLeft;
    const enBas = Alignment.bottomRight;
    switch (optionId) {
      case 'cake-texture-smooth':
        return const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
          begin: enHaut,
          end: enBas,
        );
      case 'cake-texture-rough':
        return const LinearGradient(
          colors: [Color(0xFFA1887F), Color(0xFF8D6E63)],
          begin: enHaut,
          end: enBas,
        );
      case 'cake-texture-ombré':
        return const LinearGradient(
          colors: [Color(0xFFF48FB1), Color(0xFFCE93D8)],
          begin: enHaut,
          end: enBas,
        );
      case 'cake-texture-marble':
        return const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
          begin: enHaut,
          end: enBas,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFFEEEEEE), Color(0xFFE0E0E0)],
          begin: enHaut,
          end: enBas,
        );
    }
  }

  // ------------------------------------------------------------- commandes

  Future<void> _handleReadyCakeOrder(eccore.MenuItem cake) async {
    final deliverySlot = await _pickDeliverySlot(context);
    if (deliverySlot == null || !mounted || !context.mounted) return;

    final cartService = Provider.of<CartService>(context, listen: false);
    final offlineSyncService =
        Provider.of<OfflineSyncService>(context, listen: false);

    try {
      cartService.addItem(
        cake,
        customizations: {
          'Livraison':
              '${deliverySlot['dateDisplay']} à ${deliverySlot['timeDisplay']}',
          'Date ISO': deliverySlot['dateIso'],
          'Heure': deliverySlot['timeDisplay'],
          'Type': 'Gâteau prêt',
        },
      );

      if (!mounted) return;
      _annoncerAjout(
        '${cake.name} ajouté au panier',
        enLigne: offlineSyncService.isOnline,
      );
    } catch (e) {
      if (mounted) {
        _showError('Impossible d’ajouter ce gâteau au panier.');
      }
      Journal.trace('❌ Ajout d’un gâteau du catalogue au panier: $e');
    }
  }

  Future<void> _confirmCustomCakeOrder(CustomizationService service) async {
    if (_customCakeItem == null) {
      _showError('Gâteau personnalisé indisponible. Veuillez réessayer.');
      return;
    }

    // Garde de sécurité : le bouton est déjà désactivé dans ce cas, mais
    // déposer un article hors catalogue produirait une ligne que le serveur
    // refuse — autant le dire ici plutôt qu'à la synchronisation.
    if (!_customCakeIsFromCatalog) {
      _showError(
        'Le gâteau personnalisé n’est pas encore publié à la carte : '
        'la commande sur mesure est indisponible.',
      );
      return;
    }

    final customization = service.getCurrentCustomization(_customizationId);
    if (customization == null) {
      _showError('Personnalisation introuvable. Réinitialisation en cours.');
      await _initializeCustomization();
      return;
    }

    // Validation des familles requises, telle que le service la porte — c'est
    // la même que `validate_selection` côté Django, connue avant l'appel.
    final validation =
        service.validateCustomization(_customizationId, _customCakeItem!.name);
    if (validation['isValid'] != true) {
      final errors = (validation['errors'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      if (errors.isNotEmpty) {
        _showError(errors.first);
        setState(() => _isSubmitting = false);
        return;
      }
    }

    if (_customDeliveryDate == null || _customDeliveryTime == null) {
      _showError('Choisissez la date et l’heure de retrait ou de livraison.');
      setState(() => _isSubmitting = false);
      return;
    }

    final selectedDateTime = DateTime(
      _customDeliveryDate!.year,
      _customDeliveryDate!.month,
      _customDeliveryDate!.day,
      _customDeliveryTime!.hour,
      _customDeliveryTime!.minute,
    );
    final difference = selectedDateTime.difference(DateTime.now());

    if (difference.isNegative) {
      _showError('Le créneau choisi est déjà passé.');
      setState(() => _isSubmitting = false);
      return;
    }

    if (difference.inHours < 24) {
      _showError(
        'Un gâteau sur mesure se commande au moins 24 heures à l’avance : '
        'choisissez un créneau plus tardif.',
      );
      setState(() => _isSubmitting = false);
      return;
    }

    if (_deliveryMethod == CakeDeliveryMethod.delivery &&
        _contactController.text.trim().isEmpty) {
      _showError('Indiquez un téléphone ou un e-mail pour la livraison.');
      return;
    }

    setState(() => _isSubmitting = true);

    final optionLookup = <String, CustomizationOption>{};
    final optionsByCategory = service.getOptionsByCategory(
      _customCakeItem!.id,
      fallbackName: _customCakeItem!.name,
    );
    for (final entry in optionsByCategory.entries) {
      for (final option in entry.value) {
        optionLookup[option.id] = option;
      }
    }

    // Relevé **avant** `finishCustomization`, qui referme la session : ce sont
    // ces identifiants que le panier transmet, et dont le serveur tire le prix.
    final selectedOptionIds = service.selectedOptionIds(_customizationId);

    // Refus **avant** de refermer la session, sinon l'écran perdrait la
    // composition qu'il vient de refuser d'envoyer et resterait vide.
    if (selectedOptionIds.isEmpty) {
      setState(() => _isSubmitting = false);
      _showError(
        'Les options de ce gâteau ne sont pas publiées au catalogue : '
        'la commande sur mesure est indisponible.',
      );
      return;
    }

    final finishedCustomization = service.finishCustomization(_customizationId);
    if (finishedCustomization == null) {
      setState(() => _isSubmitting = false);
      _showError('Impossible de finaliser la composition.');
      return;
    }

    // Libellés des options, pour l'affichage du panier. Ils ne partent pas
    // dans la note : le serveur stocke déjà les options retenues, et les y
    // répéter faisait déborder les 500 caractères de `CartLine.notes`.
    final customizationsMap = <String, dynamic>{
      'Type': 'Gâteau personnalisé',
    };

    finishedCustomization.selections.forEach((category, optionIds) {
      final labels = optionIds
          .map((id) => optionLookup[id]?.name ?? id)
          .toList(growable: false);
      customizationsMap[service.translateCategory(category)] = labels.join(', ');
    });

    final deliveryDateIso = selectedDateTime;

    final mode = _deliveryMethod == CakeDeliveryMethod.delivery
        ? 'Livraison'
        : 'Retrait en boutique';
    final heure = mounted && context.mounted
        ? _customDeliveryTime!.format(context)
        : '${_customDeliveryTime!.hour.toString().padLeft(2, '0')}:'
            '${_customDeliveryTime!.minute.toString().padLeft(2, '0')}';

    customizationsMap['Mode'] = mode;
    customizationsMap['Livraison'] =
        '${_formatDate(_customDeliveryDate!)} à $heure';
    if (finishedCustomization.specialInstructions?.isNotEmpty == true) {
      customizationsMap['Message'] = finishedCustomization.specialInstructions;
    }
    if (_contactController.text.trim().isNotEmpty) {
      customizationsMap['Contact'] = _contactController.text.trim();
    }

    // Ce que la pâtisserie doit lire et que les options ne disent pas : quand,
    // comment, pour qui, et le message à écrire sur le gâteau. Seule cette clé
    // rejoint `CartLine.notes` (voir `CartItem.remoteNotes`).
    customizationsMap['note'] = [
      'Gâteau sur mesure',
      '$mode le ${_formatDate(_customDeliveryDate!)} à $heure',
      'ISO ${deliveryDateIso.toIso8601String()}',
      if (finishedCustomization.specialInstructions?.isNotEmpty == true)
        'Message : ${finishedCustomization.specialInstructions}',
      if (_contactController.text.trim().isNotEmpty)
        'Contact : ${_contactController.text.trim()}',
    ].join(' • ');

    final cartService = Provider.of<CartService>(context, listen: false);
    final offlineSyncService =
        Provider.of<OfflineSyncService>(context, listen: false);

    try {
      // Le prix de la ligne reste celui du catalogue : les suppléments des
      // options sont ajoutés par le serveur, qui les relit lui-même
      // (invariant C1). L'ancienne version déposait ici un prix calculé dans
      // l'app — que la synchronisation jetait, si bien que le client voyait
      // un total dans le panier et en payait un autre.
      cartService.addItem(
        _customCakeItem!,
        customizations: customizationsMap,
        optionIds: selectedOptionIds,
      );

      if (!mounted) return;
      _annoncerAjout(
        'Gâteau personnalisé ajouté au panier',
        enLigne: offlineSyncService.isOnline,
      );

      await _resetCustomization(service);
      if (mounted) setState(() => _isSubmitting = false);
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      _showError('Impossible d’ajouter le gâteau au panier.');
      Journal.trace('❌ Ajout du gâteau sur mesure au panier: $e');
    }
  }

  /// Confirme l'ajout, et dit ce que le mode hors ligne change.
  ///
  /// Le message passe par `showSuccessMessage`, qui porte la couleur et la
  /// forme du design system, plutôt que par un `SnackBar` vert monté à la main
  /// — le vert de Material n'appartient pas à la palette El Corazón.
  void _annoncerAjout(String message, {required bool enLigne}) {
    context.showSuccessMessage(
      enLigne
          ? message
          : '$message — enregistré hors ligne, synchronisation automatique',
    );
  }

  Future<void> _resetCustomization(
    CustomizationService service, {
    eccore.MenuItem? prefillFrom,
  }) async {
    service.clearCustomization(_customizationId);
    _customizationId = _generateCustomizationId();

    _messageController.clear();
    _contactController.clear();
    _customDeliveryDate = null;
    _customDeliveryTime = null;
    _deliveryMethod = CakeDeliveryMethod.delivery;

    if (_customCakeItem != null) {
      await _initializeCustomization(prefillFrom: prefillFrom);
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickCustomDeliveryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (date != null && mounted && context.mounted) {
      setState(() {
        _customDeliveryDate = date;
        _customDeliveryTime = null; // l'heure retenue ne vaut plus
      });
    }
  }

  Future<void> _pickCustomDeliveryTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time != null && mounted && context.mounted) {
      setState(() => _customDeliveryTime = time);
    }
  }

  void _handleSingleSelection(
    CustomizationService service,
    String category,
    String optionId,
    List<String> currentlySelected,
  ) {
    for (final selectedId in currentlySelected) {
      if (selectedId != optionId) {
        service.updateSelection(_customizationId, category, selectedId, false);
      }
    }

    service.updateSelection(_customizationId, category, optionId, true);

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _handleMultiSelection(
    CustomizationService service,
    String category,
    String optionId,
    bool isSelected,
  ) {
    service.updateSelection(_customizationId, category, optionId, isSelected);
  }

  Future<Map<String, String>?> _pickDeliverySlot(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );

    if (date == null) return null;
    if (!mounted || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return null;

    final dateIso = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    return {
      'dateIso': dateIso.toIso8601String(),
      'dateDisplay': _formatDate(date),
      'timeDisplay': mounted && context.mounted ? time.format(context) : '',
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    context.showErrorMessage(message);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _generateCustomizationId() =>
      'cake_${DateTime.now().millisecondsSinceEpoch}';
}

// --------------------------------------------------------------- composants

/// La bascule « Catalogue / Sur mesure », posée sous la barre translucide.
///
/// Un `TabBar` plutôt qu'un `SegmentedButton` : le `TabBarView` qu'il pilote
/// veut un `TabController`, et le second n'en fournit pas. L'indicateur est
/// une pilule pleine — celui de Material, un trait de 2 px sous l'onglet, se
/// perd sur le fond chaud du design system.
class _Bascule extends StatelessWidget implements PreferredSizeWidget {
  const _Bascule({required this.controller});

  final TabController controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        0,
        DesignConstants.edgeMargin,
        DesignConstants.spacingS,
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: DesignConstants.borderRadiusMedium,
        ),
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.all(4),
          indicator: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
          ),
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: AppTypography.labelLg(),
          unselectedLabelStyle: AppTypography.labelLg(),
          tabs: const [
            Tab(text: 'Catalogue'),
            Tab(text: 'Sur mesure'),
          ],
        ),
      ),
    );
  }
}

/// Une couleur de glaçage, montrée telle quelle.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.couleur,
    required this.nom,
    required this.selectionnee,
    required this.onTap,
  });

  final Color couleur;
  final String nom;
  final bool selectionnee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sur une pastille blanche, une coche blanche disparaît : la coche prend
    // la teinte qui contraste avec le glaçage, pas celle de la marque.
    final surLaPastille =
        couleur.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Semantics(
      label: nom,
      selected: selectionnee,
      button: true,
      child: Tooltip(
        message: nom,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: DesignConstants.touchTargetSize + 16,
            height: DesignConstants.touchTargetSize + 16,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
              border: Border.all(
                color: selectionnee
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selectionnee ? 3 : 1,
              ),
              boxShadow: selectionnee ? DesignConstants.shadowPrimary : null,
            ),
            child: selectionnee
                ? Icon(
                    Icons.check_rounded,
                    color: surLaPastille,
                    size: DesignConstants.iconSizeMedium,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Une texture de glaçage, montrée en aplat dégradé.
class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.degrade,
    required this.nom,
    required this.selectionnee,
    required this.onTap,
  });

  final LinearGradient degrade;
  final String nom;
  final bool selectionnee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: nom,
      selected: selectionnee,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignConstants.borderRadiusMedium,
        child: Container(
          width: 108,
          padding: const EdgeInsets.all(DesignConstants.spacingS),
          decoration: BoxDecoration(
            gradient: degrade,
            borderRadius: DesignConstants.borderRadiusMedium,
            border: Border.all(
              color: selectionnee
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selectionnee ? 3 : 1,
            ),
            boxShadow: selectionnee ? DesignConstants.shadowPrimary : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: DesignConstants.iconSizeMedium,
                child: selectionnee
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: DesignConstants.iconSizeMedium,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(height: DesignConstants.spacingXS),
              // Le libellé se pose sur un dégradé dont on ne maîtrise pas la
              // clarté : il porte donc sa propre plaque, plutôt que de parier
              // sur le contraste.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignConstants.spacingS,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest
                      .withValues(alpha: 0.9),
                  borderRadius: DesignConstants.borderRadiusSmall,
                ),
                child: Text(
                  nom,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
