import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Fiche d'un plat et sa personnalisation.
///
/// ## Une page qui défile, et non quatre onglets
///
/// La version précédente rangeait taille, ingrédients, sauces et suppléments
/// derrière quatre onglets. Les trois maquettes qui couvrent cet écran —
/// `product_detail`, `item_customization`, `enhanced_customization` — montrent
/// toutes une **page unique** qui défile, et elles ont raison sur le fond :
///
/// * un onglet cache ce qu'il contient, or la taille est **obligatoire** — on
///   pouvait donc buter sur un bouton grisé sans voir ce qui manquait ;
/// * on ne relit pas ses choix avant de valider, puisqu'ils sont répartis sur
///   quatre écrans dont un seul est visible ;
/// * les onglets vides — « Aucune sauce disponible » — occupaient une place
///   entière pour dire qu'ils n'avaient rien à dire. Ici, un groupe sans
///   option n'apparaît simplement pas.
///
/// ## Les groupes viennent du catalogue
///
/// Les familles affichées ne sont plus une liste écrite ici : ce sont les
/// `OptionGroup` de l'article, avec leur nom, leurs bornes et leurs options.
/// Une clé locale (`size`, `sauce`…) ne correspondait à aucun nom de groupe
/// serveur, si bien qu'un article du catalogue n'affichait aucune option — et
/// que la ligne partait au panier sans identifiant d'option, pour être
/// refusée en 409 par `validate_selection` dès qu'un groupe exigeait un choix.
///
/// L'article part **tel quel** ; le serveur chiffre les options depuis leurs
/// identifiants (ADR-007), qui sont ceux que cet écran transmet.
class EnhancedItemCustomizationScreen extends StatefulWidget {
  final eccore.MenuItem item;
  final Function(
    eccore.MenuItem item,
    int quantity,
    Map<String, dynamic> customizations,
  )? onAddToCart;

  const EnhancedItemCustomizationScreen({
    required this.item,
    this.onAddToCart,
    super.key,
  });

  @override
  State<EnhancedItemCustomizationScreen> createState() =>
      _EnhancedItemCustomizationScreenState();
}

class _EnhancedItemCustomizationScreenState
    extends State<EnhancedItemCustomizationScreen> {
  late String _sessionId;
  late String _menuItemId;
  final TextEditingController _instructionsController = TextEditingController();
  int _quantity = 1;

  /// Groupes dont on a tenté de valider l'article sans les satisfaire. Sert à
  /// n'afficher le reproche **qu'après** une tentative : signaler « Requis »
  /// en rouge dès l'ouverture accuse le client de ne pas avoir fait ce qu'on
  /// ne lui a pas encore demandé.
  final Set<String> _reclames = <String>{};

  /// Titres des familles locales, que la démonstration désigne par une clé
  /// technique. Les groupes du catalogue, eux, portent déjà leur nom
  /// d'affichage — « Cuisson du steak », « Taille » — puisque c'est celui que
  /// l'exploitation a saisi.
  static const _titresLocaux = <String, String>{
    'size': 'Choisir la taille',
    'ingredient': 'Ingrédients',
    'sauce': 'Sauces',
    'supplement': 'Suppléments',
  };

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _menuItemId = widget.item.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCustomization();
    });
  }

  Future<void> _initializeCustomization() async {
    if (!mounted || !context.mounted) return;
    final service = Provider.of<CustomizationService>(context, listen: false);
    if (!service.isInitialized) {
      await service.initialize();
    }
    if (!mounted || !context.mounted) return;
    await service.startCustomization(
      _sessionId,
      _menuItemId,
      widget.item.name,
    );

    // Aucune présélection ici : `startCustomization` retient déjà les options
    // marquées par défaut au catalogue. Retenir d'office la première d'un
    // groupe obligatoire — ce que faisait la taille — choisit la cuisson à la
    // place du client, et lui fait payer un supplément qu'il n'a pas demandé.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Provider.of<CustomizationService>(context, listen: false)
        .clearCustomization(_sessionId);
    _instructionsController.dispose();
    super.dispose();
  }

  List<CustomizationOption> _options(
    CustomizationService service,
    String categorie,
  ) {
    final parCategorie = service.getOptionsByCategory(
      _menuItemId,
      fallbackName: widget.item.name,
    );
    return parCategorie[categorie] ?? const [];
  }

  /// Les groupes de cet article, tels que le catalogue les publie.
  ///
  /// Ils étaient auparavant écrits en dur — `size`, `ingredient`, `sauce`,
  /// `supplement` — quand le serveur groupe par nom d'`OptionGroup`
  /// (« Cuisson du steak », « Formule »…). Aucune clé ne correspondait : la
  /// page n'affichait **aucun** groupe pour un article du catalogue, la ligne
  /// partait donc sans options, et `POST /carts/{slug}/lines/` la refusait en
  /// 409 dès qu'un groupe exigeait un choix.
  List<_Famille> _familles(CustomizationService service) {
    final parCategorie = service.getOptionsByCategory(
      _menuItemId,
      fallbackName: widget.item.name,
    );

    return [
      for (final entry in parCategorie.entries)
        if (entry.value.isNotEmpty) _famille(service, entry.key, entry.value),
    ];
  }

  _Famille _famille(
    CustomizationService service,
    String categorie,
    List<CustomizationOption> options,
  ) {
    final contrainte = service.constraintFor(
      _menuItemId,
      categorie,
      fallbackName: widget.item.name,
    );

    return _Famille(
      cle: categorie,
      titre: _titresLocaux[categorie] ?? categorie,
      minimum: contrainte.minSelections,
      maximum: contrainte.maxSelections,
      unique: contrainte.isSingleChoice,
      tarifante: options.any((option) => option.priceModifier != 0),
    );
  }

  /// Les groupes dont la borne basse n'est pas atteinte — ceux que le serveur
  /// refuserait. La liste est la même que celle de `validate_selection`
  /// côté Django, à ceci près qu'elle est connue avant l'appel.
  List<_Famille> _insatisfaites(CustomizationService service) {
    return [
      for (final famille in _familles(service))
        if (_retenues(service, famille.cle).length < famille.minimum) famille,
    ];
  }

  List<String> _retenues(CustomizationService service, String categorie) {
    final personnalisation = service.getCurrentCustomization(_sessionId);
    return personnalisation?.selections[categorie] ?? const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Personnaliser',
        actions: [
          GlassIconButton(
            icon: Icons.rate_review_outlined,
            tooltip: 'Avis des clients',
            filled: false,
            onPressed: () => context.navigateToProductReviews(widget.item),
          ),
          Consumer<FavoritesService>(
            builder: (context, favoritesService, child) {
              final favori = favoritesService.isFavorite(widget.item);
              return GlassIconButton(
                icon: favori
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                filled: false,
                onPressed: () => favoritesService.toggleFavorite(widget.item),
              );
            },
          ),
        ],
      ),
      body: Consumer<CustomizationService>(
        builder: (context, service, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingL,
            ),
            children: [
              _enTete(theme),
              const SizedBox(height: DesignConstants.spacingL),
              _reperes(theme),
              for (final famille in _familles(service)) ...[
                const SizedBox(height: DesignConstants.spacingL),
                _groupe(service, famille),
              ],
              const SizedBox(height: DesignConstants.spacingL),
              _instructions(theme),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<CustomizationService>(
        builder: (context, service, child) => _barreDAjout(service),
      ),
    );
  }

  // ------------------------------------------------------------------ entête

  Widget _enTete(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: DesignConstants.borderRadiusLarge,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoodImage(
                  url: widget.item.image,
                  heroTag: 'plat_${widget.item.id.isEmpty ? widget.item.slug : widget.item.id}',
                  iconSize: 64,
                ),
                if (widget.item.ratingAverage > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: RatingBadge(
                      rating: widget.item.ratingAverage,
                      count: widget.item.ratingCount,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.item.name,
                style: AppTypography.headlineMd(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: DesignConstants.spacingM),
            Text(
              widget.item.price.format(),
              style: AppTypography.priceDisplay(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (widget.item.description.isNotEmpty) ...[
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            widget.item.description,
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Repères du plat, en puces : durée, calories, régimes, allergènes.
  ///
  /// Tout vient du catalogue et rien n'est affiché à vide — une puce
  /// « 0 calorie » sur un plat dont le serveur ne connaît pas l'apport
  /// énergétique serait une information fausse, pas une information manquante.
  Widget _reperes(ThemeData theme) {
    final puces = <Widget>[
      if (widget.item.preparationMinutes > 0)
        StatusChip(
          label: '${widget.item.preparationMinutes} min',
          icon: Icons.schedule_rounded,
        ),
      if ((widget.item.calories ?? 0) > 0)
        StatusChip(
          label: '${widget.item.calories} cal',
          icon: Icons.local_fire_department_rounded,
        ),
      if (widget.item.estVegan)
        StatusChip(
          label: 'Vegan',
          icon: Icons.eco_rounded,
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        )
      else if (widget.item.estVegetarien)
        StatusChip(
          label: 'Végétarien',
          icon: Icons.eco_outlined,
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        ),
      for (final allergene in widget.item.allergens)
        StatusChip(
          label: allergene,
          icon: Icons.warning_amber_rounded,
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        ),
    ];

    if (puces.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DesignConstants.spacingS,
      runSpacing: DesignConstants.spacingS,
      children: puces,
    );
  }

  // ------------------------------------------------------------------ options

  Widget _groupe(CustomizationService service, _Famille famille) {
    final options = _options(service, famille.cle);
    final retenues = _retenues(service, famille.cle);
    final manque = retenues.length < famille.minimum;

    return OptionGroupCard(
      title: famille.titre,
      isRequired: famille.requis,
      constraintLabel: famille.libelleContrainte,
      error: (manque && _reclames.contains(famille.cle))
          ? famille.reproche
          : null,
      children: [
        for (var i = 0; i < options.length; i++)
          OptionRow(
            label: options[i].name,
            subtitle: options[i].description,
            selected: retenues.contains(options[i].id),
            multiple: !famille.unique,
            priceDelta: _libelleEcart(options[i], famille),
            showDivider: i < options.length - 1,
            onChanged: (coche) =>
                _basculer(service, famille, options[i].id, coche),
          ),
      ],
    );
  }

  /// Retient ou retire une option, en tenant les bornes de son groupe.
  ///
  /// L'exclusivité et le plafond sont portés ici et non par le service :
  /// celui-ci enregistre des sélections par catégorie sans savoir laquelle en
  /// admet plusieurs. Dépasser le plafond n'était refusé nulle part — le
  /// serveur le refusait pour tout le monde, une fois le panier constitué.
  void _basculer(
    CustomizationService service,
    _Famille famille,
    String optionId,
    bool coche,
  ) {
    final retenues = _retenues(service, famille.cle);

    if (famille.unique) {
      for (final autre in retenues.toList()) {
        service.updateSelection(_sessionId, famille.cle, autre, false);
      }
      // Un groupe obligatoire à choix unique ne se déselectionne pas : taper
      // sur l'option déjà retenue la garde plutôt que de rouvrir un manque.
      if (coche || famille.minimum > 0) {
        service.updateSelection(_sessionId, famille.cle, optionId, true);
      }
    } else if (coche) {
      if (retenues.length >= famille.maximum) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '« ${famille.titre} » accepte au plus ${famille.maximum} '
              'choix.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      service.updateSelection(_sessionId, famille.cle, optionId, true);
    } else {
      service.updateSelection(_sessionId, famille.cle, optionId, false);
    }

    setState(() {
      if (_retenues(service, famille.cle).length >= famille.minimum) {
        _reclames.remove(famille.cle);
      }
    });
  }

  /// Écart de prix d'une option.
  ///
  /// Un groupe à choix unique **qui change le prix** montre le prix final
  /// (« 5 500 CFA ») : on compare des tailles entre elles. Partout ailleurs
  /// c'est l'écart (« +500 CFA »), parce qu'il s'ajoute à ce qui est déjà
  /// choisi — et sur « Cuisson du steak », où toutes les options valent zéro,
  /// afficher le prix du plat en face de chaque cuisson laisserait croire
  /// qu'on le paie trois fois. Un supplément gratuit est annoncé comme tel :
  /// une case vide laisse craindre un prix qu'on découvrira au total.
  String _libelleEcart(CustomizationOption option, _Famille famille) {
    if (famille.unique && famille.tarifante) {
      return PriceFormatter.format(
        widget.item.prixAffiche + option.priceModifier,
      );
    }
    if (option.priceModifier == 0) return 'Offert';
    if (option.priceModifier > 0) {
      return '+${PriceFormatter.format(option.priceModifier)}';
    }
    return PriceFormatter.format(option.priceModifier);
  }

  Widget _instructions(ThemeData theme) {
    return SectionCard(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Instructions spéciales',
            style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Ex. : sans oignons, bien cuit…',
              fillColor: theme.colorScheme.surface,
            ),
            onChanged: (value) {
              Provider.of<CustomizationService>(context, listen: false)
                  .updateSpecialInstructions(_sessionId, value);
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- total

  Widget _barreDAjout(CustomizationService service) {
    final theme = Theme.of(context);
    // L'écart des options couvre **toutes** les sélections, la taille
    // comprise : l'ajouter une seconde fois au prix de base — ce que faisait
    // `_prixDeBase` — annonçait un total supérieur à celui que le serveur
    // facture ensuite.
    final personnalisation = service.getCurrentCustomization(_sessionId);
    final ecartOptions = personnalisation?.totalPriceModifier ?? 0.0;
    final total = (widget.item.prixAffiche + ecartOptions) * _quantity;

    return GlassBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              QuantityStepper(
                quantity: _quantity,
                onDecrement: () => setState(() => _quantity--),
                onIncrement: () => setState(() => _quantity++),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    PriceFormatter.format(total),
                    style: AppTypography.priceDisplay(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          ActionButton(
            label: 'Ajouter au panier',
            emphasis: ActionEmphasis.gradient,
            icon: Icons.shopping_cart_rounded,
            // Le bouton reste **actif** même quand un choix manque : c'est en
            // appuyant qu'on apprend ce qui manque, et les groupes concernés
            // se signalent alors en rouge. Un bouton grisé ne dit jamais
            // pourquoi.
            onPressed: () => _addToCart(service),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(CustomizationService service) async {
    try {
      // Refus **avant** de refermer la session : celle-ci porte la
      // composition, et la fermer sur un refus laisserait l'écran vide.
      final manquantes = _insatisfaites(service);
      if (manquantes.isNotEmpty) {
        setState(() {
          _reclames.addAll(manquantes.map((famille) => famille.cle));
        });
        return;
      }

      // Relevé avant `finishCustomization`, qui referme la session : ce sont
      // ces identifiants que le panier transmet, et dont le serveur tire le
      // prix (ADR-007). Sans eux, la ligne partait sans options et
      // `POST /carts/{slug}/lines/` la refusait en 409 dès qu'un groupe
      // exigeait un choix — « Cuisson du steak » sur presque tous les burgers.
      final optionIds = service.selectedOptionIds(_sessionId);

      final customization = service.finishCustomization(_sessionId);
      if (customization == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la personnalisation')),
        );
        return;
      }

      final cartService = Provider.of<CartService>(context, listen: false);

      // L'article part **tel quel**. Le prix personnalisé était calculé ici
      // puis recopié sur une copie de l'article ; le serveur ne l'a jamais lu
      // — il chiffre les options depuis leurs identifiants (ADR-007), et
      // c'est son total qui fait foi au panier comme à la commande.

      final customizationsMap = <String, dynamic>{
        'quantity': _quantity,
        'special_instructions': _instructionsController.text.trim().isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      };

      for (final entry in customization.selections.entries) {
        customizationsMap[entry.key] = entry.value;
      }

      if (widget.onAddToCart != null) {
        widget.onAddToCart!(widget.item, _quantity, customizationsMap);
      } else {
        cartService.addItem(
          widget.item,
          quantity: _quantity,
          customizations: customizationsMap,
          optionIds: optionIds,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_quantity × ${widget.item.name} ajouté${_quantity > 1 ? 's' : ''} au panier',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}

/// Une famille d'options et la contrainte qui lui est attachée.
///
/// Les bornes viennent du groupe publié au catalogue (`OptionGroup.min_select`
/// / `max_select`) — les mêmes que `validate_selection` revalide côté Django.
/// Les tenir ici évite de composer un panier que le serveur refusera.
class _Famille {
  const _Famille({
    required this.cle,
    required this.titre,
    this.minimum = 0,
    this.maximum = 1,
    this.unique = false,
    this.tarifante = false,
  });

  /// Clé de catégorie chez `CustomizationService` : le nom du groupe pour une
  /// option du catalogue (« Cuisson du steak »), une étiquette locale pour la
  /// démonstration (`size`, `ingredient`, `sauce`, `supplement`).
  final String cle;

  final String titre;

  /// Nombre de choix exigés, zéro si le groupe est facultatif.
  final int minimum;

  /// Nombre de choix acceptés.
  final int maximum;

  /// Un seul choix possible : boutons radio plutôt que cases à cocher.
  final bool unique;

  /// Au moins une option de ce groupe change le prix.
  final bool tarifante;

  /// Un choix est attendu avant de pouvoir ajouter au panier.
  bool get requis => minimum > 0;

  /// Badge du groupe — ce qu'il attend, en toutes lettres.
  String get libelleContrainte {
    if (requis && unique) return 'Requis';
    if (requis) return 'Au moins $minimum';
    if (maximum > 1) return 'Jusqu’à $maximum';
    return 'Facultatif';
  }

  /// Reproche affiché quand la borne basse n'est pas atteinte.
  String get reproche => unique
      ? 'Faites un choix pour continuer'
      : 'Choisissez au moins $minimum option${minimum > 1 ? 's' : ''}';
}
