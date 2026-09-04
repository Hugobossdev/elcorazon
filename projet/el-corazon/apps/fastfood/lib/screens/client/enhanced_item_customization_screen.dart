import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/presentation/tarification.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Ligne du panier qu'on rouvre pour la modifier — nul à l'ajout.
  ///
  /// Sa présence change trois choses et rien d'autre : les choix de la ligne
  /// sont rejoués à l'ouverture, le bouton enregistre au lieu d'ajouter, et
  /// c'est cette ligne qui est réécrite plutôt qu'une nouvelle empilée à côté.
  /// Le reste de l'écran — groupes, bornes, prix — est le même, et doit
  /// l'être : composer et recomposer sont le même geste, et deux écrans qui
  /// prétendraient le rendre finiraient par ne plus appliquer les mêmes règles.
  final CartItem? ligneDuPanier;

  const EnhancedItemCustomizationScreen({
    required this.item,
    this.onAddToCart,
    this.ligneDuPanier,
    super.key,
  });

  /// Vrai quand l'écran modifie une ligne existante.
  bool get enModification => ligneDuPanier != null;

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

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _menuItemId = widget.item.id;

    // Une modification reprend la ligne où elle en est — quantité et note
    // comprises. Repartir de 1 et d'un champ vide ferait perdre au client, en
    // ouvrant l'écran, ce qu'il n'avait pas l'intention de toucher.
    final ligne = widget.ligneDuPanier;
    if (ligne != null) {
      _quantity = ligne.quantity;
      final note = ligne.customizations['note'];
      if (note != null) _instructionsController.text = note.toString();
    }

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
      optionsInitiales: widget.ligneDuPanier?.selectedOptionIds ?? const [],
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
    return service.getOptionsByCategory(_menuItemId)[categorie] ?? const [];
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
    final parCategorie = service.getOptionsByCategory(_menuItemId);

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
    final contrainte = service.constraintFor(_menuItemId, categorie);

    return _Famille(
      cle: categorie,
      // Le nom du groupe, tel que l'exploitation l'a saisi au back-office —
      // « Cuisson du steak », « Taille ». Une table de titres vivait ici pour
      // traduire les clés techniques des options de démonstration (`size`,
      // `sauce`) ; elle est partie avec elles.
      titre: categorie,
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
            icon: Icons.ios_share_rounded,
            tooltip: 'Partager ce plat',
            filled: false,
            onPressed: _partager,
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
              ..._corpsDesOptions(theme, service),
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
            child: FoodImage(
              url: widget.item.image,
              heroTag:
                  'plat_${widget.item.id.isEmpty ? widget.item.slug : widget.item.id}',
              iconSize: 64,
            ),
          ),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        _noteEtRenom(theme),
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
        if (!widget.item.isAvailable) ...[
          const SizedBox(height: DesignConstants.spacingM),
          _avisIndisponible(theme),
        ],
      ],
    );
  }

  /// La note et la puce « Populaire », juste sous la photo.
  ///
  /// La maquette `product_detail` les pose côte à côte à cet endroit précis, et
  /// rend la note **cliquable** : c'est de là qu'on va lire les avis. La
  /// version précédente épinglait une pastille de note dans un coin de la
  /// photo, où elle ne se laissait pas toucher, et cachait l'accès aux avis
  /// derrière une icône de la barre supérieure.
  Widget _noteEtRenom(ThemeData theme) {
    final puces = <Widget>[
      if (widget.item.ratingAverage > 0)
        InkWell(
          onTap: () => context.navigateToProductReviews(widget.item),
          borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RatingBadge(
                  rating: widget.item.ratingAverage,
                  count: widget.item.ratingCount,
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: DesignConstants.iconSizeSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      if (widget.item.isPopular)
        const StatusChip(
          label: 'Populaire',
          icon: Icons.local_fire_department_rounded,
        ),
    ];

    if (puces.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingS),
      child: Wrap(
        spacing: DesignConstants.spacingS,
        runSpacing: DesignConstants.spacingS,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: puces,
      ),
    );
  }

  /// L'article n'est plus servi : le dire au-dessus des options, et non au
  /// moment de l'ajout.
  ///
  /// L'accueil et la carte écartent déjà les articles indisponibles de leurs
  /// listes, mais on arrive aussi ici depuis les favoris — où l'article a été
  /// mis en réserve quand il était encore servi. On composait alors un plat
  /// entier avant de se voir refuser au panier.
  Widget _avisIndisponible(ThemeData theme) {
    return SectionCard(
      color: theme.colorScheme.errorContainer,
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.no_meals_rounded,
            size: DesignConstants.iconSizeMedium,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plat indisponible',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(
                  'La cuisine ne sert plus ce plat pour l’instant. '
                  'Vous pouvez consulter ses options, mais pas le commander.',
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

  /// Partage le plat sous forme de texte, copié dans le presse-papiers.
  ///
  /// Pas de feuille de partage système : elle demanderait une dépendance de
  /// plus, et surtout un lien vers le plat — or l'application n'expose aucune
  /// adresse publique ni schéma de lien profond. Copier un texte exact vaut
  /// mieux qu'ouvrir un partage sur une URL inventée. Voir
  /// `docs/UI_REDESIGN_ISSUES.md`, ISSUE-005.
  Future<void> _partager() async {
    final prix = widget.item.price.format();
    final texte = [
      '${widget.item.name} — $prix',
      if (widget.item.description.isNotEmpty) widget.item.description,
      'El Corazón',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: texte));
    if (!mounted) return;
    context.showSuccessMessage('Plat copié — collez-le où vous voulez');
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

  /// Ce que la page montre à la place des groupes selon l'état de leur
  /// lecture.
  ///
  /// Les quatre situations se ressemblaient : la page affichait des groupes,
  /// ou rien. « Rien » couvrait aussi bien un article sans option qu'un appel
  /// en cours ou un serveur muet — et le bouton d'ajout restait actif dans les
  /// trois cas, si bien qu'une panne réseau faisait déposer au panier une ligne
  /// sans les choix que le catalogue exige, refusée en 409.
  List<Widget> _corpsDesOptions(ThemeData theme, CustomizationService service) {
    switch (service.etatDesOptions(_menuItemId)) {
      case EtatDesOptions.aDemander:
      case EtatDesOptions.enLecture:
        return [
          const SizedBox(height: DesignConstants.spacingL),
          _encart(
            theme,
            icone: Icons.hourglass_empty_rounded,
            titre: 'Chargement des options…',
            message: 'Nous lisons les choix disponibles pour ce plat.',
          ),
        ];

      case EtatDesOptions.enErreur:
        return [
          const SizedBox(height: DesignConstants.spacingL),
          _encart(
            theme,
            icone: Icons.cloud_off_rounded,
            titre: 'Options indisponibles',
            message: service.erreurDesOptions(_menuItemId) ??
                'Les options de ce plat n’ont pas pu être chargées.',
            fond: theme.colorScheme.errorContainer,
            encre: theme.colorScheme.onErrorContainer,
            action: 'Réessayer',
            onAction: () => service.rechargerLesOptions(_menuItemId),
          ),
        ];

      case EtatDesOptions.sansOption:
        // Une réponse, pas un manque : ce plat se commande tel quel.
        return [
          const SizedBox(height: DesignConstants.spacingL),
          _encart(
            theme,
            icone: Icons.restaurant_rounded,
            titre: 'Aucune option de personnalisation',
            message: 'Ce plat se commande tel quel. '
                'Vous pouvez laisser une instruction ci-dessous.',
          ),
        ];

      case EtatDesOptions.avecOptions:
        return [
          for (final famille in _familles(service)) ...[
            const SizedBox(height: DesignConstants.spacingL),
            _groupe(service, famille),
          ],
        ];
    }
  }

  Widget _encart(
    ThemeData theme, {
    required IconData icone,
    required String titre,
    required String message,
    Color? fond,
    Color? encre,
    String? action,
    VoidCallback? onAction,
  }) {
    final couleur = encre ?? theme.colorScheme.onSurfaceVariant;

    return SectionCard(
      color: fond ?? theme.colorScheme.surfaceContainerLow,
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: DesignConstants.iconSizeMedium, color: couleur),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: AppTypography.titleLg(
                    color: encre ?? theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(message, style: AppTypography.bodyMd(color: couleur)),
                if (action != null && onAction != null) ...[
                  const SizedBox(height: DesignConstants.spacingS),
                  ActionButton(
                    label: action,
                    emphasis: ActionEmphasis.outlined,
                    height: 40,
                    expand: false,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupe(CustomizationService service, _Famille famille) {
    final options = _options(service, famille.cle);
    final retenues = _retenues(service, famille.cle);
    final manque = retenues.length < famille.minimum;

    return OptionGroupCard(
      title: famille.titre,
      isRequired: famille.requis,
      constraintLabel: famille.badge(retenues.length),
      error: (manque && _reclames.contains(famille.cle))
          ? famille.reproche
          : null,
      children: [
        for (var i = 0; i < options.length; i++)
          OptionRow(
            label: options[i].name,
            // « Indisponible » prime sur la description : c'est ce qui
            // explique la ligne grisée, et le seul des deux qui change ce que
            // le client peut faire.
            subtitle: options[i].isAvailable
                ? options[i].description
                : 'Indisponible',
            selected: retenues.contains(options[i].id),
            multiple: !famille.unique,
            priceDelta: _libelleEcart(options[i], famille),
            showDivider: i < options.length - 1,
            // Épuisée : montrée, jamais cochable. La masquer ferait croire à
            // un menu qui change de forme d'une minute à l'autre, et
            // effacerait un groupe entier — obligatoire compris — dès que
            // toutes ses options le seraient.
            enabled: options[i].isAvailable,
            onChanged: options[i].isAvailable
                ? (coche) => _basculer(service, famille, options[i].id, coche)
                : null,
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
    // comprise : l'ajouter une seconde fois au prix de base annoncerait un
    // total supérieur à celui que le serveur facture ensuite.
    //
    // Il est demandé au service plutôt que lu sur
    // `ItemCustomization.totalPriceModifier` : ce champ n'était renseigné que
    // par `finishCustomization`, qui referme la session dans le même geste. Il
    // valait donc zéro pendant toute la composition, et cette barre affichait
    // le prix nu du plat quelles que soient les options retenues.
    final ecartOptions = service.calculatePriceModifier(_sessionId);
    final prixUnitaire = prixUnitairePersonnalise(
      prixDeBase: widget.item.prixAffiche,
      supplementOptions: ecartOptions,
    );
    final total = totalDeLigne(
      prixDeBase: widget.item.prixAffiche,
      supplementOptions: ecartOptions,
      quantite: _quantity,
    );

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
                  // Le détail du prix unitaire n'apparaît que lorsqu'il diffère
                  // du total — sinon il répéterait la même somme deux fois.
                  if (_quantity > 1)
                    Text(
                      '${PriceFormatter.format(prixUnitaire)} l’unité',
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
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
            label: !widget.item.isAvailable
                ? 'Plat indisponible'
                : _optionsIncertaines(service)
                    ? 'Options indisponibles'
                    : widget.enModification
                        ? 'Enregistrer les modifications'
                        : 'Ajouter au panier',
            emphasis: ActionEmphasis.gradient,
            icon: !widget.item.isAvailable
                ? Icons.no_meals_rounded
                : widget.enModification
                    ? Icons.check_rounded
                    : Icons.shopping_cart_rounded,
            // Le bouton reste **actif** même quand un choix manque : c'est en
            // appuyant qu'on apprend ce qui manque, et les groupes concernés
            // se signalent alors en rouge. Un bouton grisé ne dit jamais
            // pourquoi.
            //
            // L'indisponibilité, elle, le grise : aucune manipulation de
            // l'écran n'y remédie, et l'encart en tête de page a déjà dit
            // pourquoi.
            //
            // Il est également neutralisé tant que les options ne sont pas
            // connues : ajouter alors déposerait une ligne sans les choix que
            // le catalogue exige, refusée en 409 par `validate_selection`.
            onPressed: widget.item.isAvailable && !_optionsIncertaines(service)
                ? () => _addToCart(service)
                : null,
          ),
        ],
      ),
    );
  }

  /// Vrai tant qu'on ignore ce que ce plat propose — lecture en cours, ou
  /// échouée. Un article sans option n'est pas incertain : il est connu, et
  /// commandable tel quel.
  bool _optionsIncertaines(CustomizationService service) {
    final etat = service.etatDesOptions(_menuItemId);
    return etat == EtatDesOptions.aDemander ||
        etat == EtatDesOptions.enLecture ||
        etat == EtatDesOptions.enErreur;
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

      // Ce que la ligne du panier doit **montrer** : « Cuisson du steak : Bien
      // cuit », et non l'identifiant de l'option. L'écran recopiait jusqu'ici
      // ses `selections` telles quelles, c'est-à-dire des identifiants, et le
      // panier affichait « Cuisson du steak: [3fa85f64-5717-…] ».
      final libelles = service.libellesRetenus(_sessionId);

      // Le supplément annoncé à l'instant par la barre du bas, reporté sur la
      // ligne pour que le panier affiche le même montant que cette page. Le
      // serveur le remplacera par le sien à la synchronisation (ADR-007).
      final supplement = service.calculatePriceModifier(_sessionId);

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

      // Seuls des libellés destinés à l'affichage, et rien qui soit déjà porté
      // ailleurs sur la ligne.
      //
      // `quantity` y figurait, alors que `CartItem.quantity` la porte déjà :
      // comme `addItem` fusionne deux lignes sur l'égalité de leurs
      // personnalisations, un burger ajouté à 1 puis à 2 donnait **deux
      // lignes** au lieu d'une à trois exemplaires. `special_instructions`
      // y figurait même vide, et le panier affichait « special_instructions:
      // null ». Le texte libre passe par la clé `note`, la seule que
      // `CartItem.remoteNotes` transmet au serveur et que la carte du panier
      // sait présenter.
      final instructions = _instructionsController.text.trim();
      final customizationsMap = <String, dynamic>{
        ...libelles,
        if (instructions.isNotEmpty) 'note': instructions,
      };

      final ligne = widget.ligneDuPanier;
      final String annonce;

      if (ligne != null) {
        // La position est relevée **maintenant**, pas à l'ouverture : l'écran
        // se superpose au panier, et une synchronisation survenue entre-temps
        // a pu réordonner les lignes. Écrire sur l'index d'ouverture
        // réécrirait alors la ligne voisine.
        final index = cartService.indexOfCartItem(ligne.id);
        if (index < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cette ligne n’est plus dans votre panier.'),
              ),
            );
            Navigator.of(context).pop();
          }
          return;
        }

        cartService.updateItemCustomizations(
          index,
          customizations: customizationsMap,
          optionIds: optionIds,
          optionsSupplement: supplement,
          quantity: _quantity,
        );
        annonce = '${widget.item.name} mis à jour';
      } else if (widget.onAddToCart != null) {
        widget.onAddToCart!(widget.item, _quantity, customizationsMap);
        annonce =
            '$_quantity × ${widget.item.name} ajouté${_quantity > 1 ? 's' : ''} au panier';
      } else {
        cartService.addItem(
          widget.item,
          quantity: _quantity,
          customizations: customizationsMap,
          optionIds: optionIds,
          optionsSupplement: supplement,
        );
        annonce =
            '$_quantity × ${widget.item.name} ajouté${_quantity > 1 ? 's' : ''} au panier';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(annonce),
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

  /// Clé de catégorie chez `CustomizationService` : le nom du groupe publié au
  /// catalogue — « Cuisson du steak », « Taille ».
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

  /// Le badge, une fois [retenues] choix faits.
  ///
  /// Un groupe à plusieurs choix passe au décompte — « 2/3 » — dès la première
  /// sélection : « Jusqu'à 3 » dit ce qui est permis, pas ce qu'il reste, et
  /// c'est la seconde question qu'on se pose une fois qu'on a commencé. Un
  /// groupe à choix unique n'y gagnerait rien : « 1/1 » n'apprend rien que la
  /// puce cochée ne montre déjà.
  String badge(int retenues) {
    if (unique || maximum <= 1) return libelleContrainte;
    if (retenues == 0) return libelleContrainte;
    return '$retenues/$maximum';
  }

  /// Reproche affiché quand la borne basse n'est pas atteinte.
  String get reproche => unique
      ? 'Faites un choix pour continuer'
      : 'Choisissez au moins $minimum option${minimum > 1 ? 's' : ''}';
}
