import 'package:flutter/foundation.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/utils/price_formatter.dart';

class CustomizationOption {
  final String id;
  final String name;
  final String category; // 'ingredient', 'sauce', 'size', 'cooking', 'extra'
  final double priceModifier;
  final bool isDefault;
  final bool isRequired; // Si l'option est requise pour ce menu item
  final int maxQuantity;
  final String? description;
  final String? imageUrl;
  final List<String>? allergens;

  /// Vrai quand l'option vient du catalogue serveur — son [id] est alors un
  /// identifiant que `POST /carts/{slug}/lines/` accepte.
  ///
  /// Toutes les options en portent désormais un : elles ne naissent plus que
  /// de [CustomizationOption.fromRemote]. Le drapeau reste la **dernière
  /// garde** avant l'envoi ([selectedOptionIds]) — le constructeur public
  /// permet toujours de fabriquer une option sans catalogue, et une telle
  /// option ne doit jamais atteindre le serveur, qui la refuserait en
  /// emportant la ligne entière.
  final bool isRemote;

  /// Nombre minimal de choix imposé par le groupe côté serveur
  /// (`OptionGroup.min_select`) — le même que `validate_selection` revalide.
  final int minSelections;

  CustomizationOption({
    required this.id,
    required this.name,
    required this.category,
    this.priceModifier = 0.0,
    this.isDefault = false,
    this.isRequired = false,
    this.maxQuantity = 1,
    this.description,
    this.imageUrl,
    this.allergens,
    this.isRemote = false,
    this.minSelections = 0,
  });

  /// Depuis le contrat Django (`OptionSerializer` dans son groupe).
  ///
  /// La `category` locale n'a pas d'équivalent : le backend groupe les options
  /// par `OptionGroup` (« Cuisson », « Taille »...) plutôt que par une
  /// étiquette libre. Le nom du groupe en tient lieu — c'est aussi ce que
  /// l'écran affiche en titre de section.
  factory CustomizationOption.fromRemote(eccore.Option option, eccore.OptionGroup group) {
    return CustomizationOption(
      id: option.id,
      name: option.name,
      category: group.name,
      priceModifier: option.priceDelta.toMajorUnits(),
      isDefault: option.isDefault,
      isRequired: group.isRequired,
      maxQuantity: group.maxSelect,
      minSelections: group.minSelect,
      isRemote: true,
    );
  }

  CustomizationOption copyWith({
    String? id,
    String? name,
    String? category,
    double? priceModifier,
    bool? isDefault,
    bool? isRequired,
    int? maxQuantity,
    String? description,
    String? imageUrl,
    List<String>? allergens,
    bool? isRemote,
    int? minSelections,
  }) {
    return CustomizationOption(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      priceModifier: priceModifier ?? this.priceModifier,
      isDefault: isDefault ?? this.isDefault,
      isRequired: isRequired ?? this.isRequired,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      allergens: allergens ??
          (this.allergens != null ? List<String>.from(this.allergens!) : null),
      isRemote: isRemote ?? this.isRemote,
      minSelections: minSelections ?? this.minSelections,
    );
  }
}

class ItemCustomization {
  final String itemId;
  final String menuItemId;
  final String menuItemName;
  final Map<String, List<String>> selections; // category -> selected option ids
  final Map<String, int> quantities; // option id -> quantity
  final String? specialInstructions;
  final double totalPriceModifier;

  ItemCustomization({
    required this.itemId,
    required this.menuItemId,
    required this.menuItemName,
    required this.selections,
    required this.quantities,
    this.specialInstructions,
    this.totalPriceModifier = 0.0,
  });

  ItemCustomization copyWith({
    String? itemId,
    String? menuItemId,
    String? menuItemName,
    Map<String, List<String>>? selections,
    Map<String, int>? quantities,
    String? specialInstructions,
    double? totalPriceModifier,
  }) {
    return ItemCustomization(
      itemId: itemId ?? this.itemId,
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      selections: selections ?? Map.from(this.selections),
      quantities: quantities ?? Map.from(this.quantities),
      specialInstructions: specialInstructions ?? this.specialInstructions,
      totalPriceModifier: totalPriceModifier ?? this.totalPriceModifier,
    );
  }
}

class CategoryConstraint {
  final String category;
  final int minSelections;
  final int maxSelections;
  final bool isRequired;
  final bool isSingleChoice;

  const CategoryConstraint({
    required this.category,
    this.minSelections = 0,
    this.maxSelections = 99,
    this.isRequired = false,
    this.isSingleChoice = false,
  });
}

/// Où en est la lecture des options d'un article.
///
/// Les quatre situations rendaient auparavant la même chose — une liste vide —
/// et l'écran ne pouvait donc pas les distinguer.
enum EtatDesOptions {
  /// Jamais demandé : la fiche n'a pas encore été ouverte.
  aDemander,

  /// Appel en cours.
  enLecture,

  /// Le serveur a répondu : cet article n'a rien à personnaliser.
  sansOption,

  /// Le serveur a répondu avec des groupes d'options.
  avecOptions,

  /// L'appel a échoué. Voir [CustomizationService.erreurDesOptions].
  enErreur,
}

class CustomizationService extends ChangeNotifier {
  static final CustomizationService _instance =
      CustomizationService._internal();
  factory CustomizationService() => _instance;
  CustomizationService._internal();


  final Map<String, List<CustomizationOption>> _itemOptions = {};
  final Map<String, ItemCustomization> _currentCustomizations = {};

  /// Où en est la lecture des options de chaque article.
  ///
  /// Sans cet état, trois situations se ressemblaient trait pour trait — une
  /// liste vide : « pas encore demandé », « demandé, l'article n'a aucune
  /// option » et « demandé, le serveur n'a pas répondu ». L'écran ne pouvait
  /// donc ni attendre, ni annoncer une absence, ni signaler une panne ; il
  /// affichait une page sans options dans les trois cas.
  final Map<String, EtatDesOptions> _etats = {};

  /// Le message d'erreur de la dernière lecture, par article.
  final Map<String, String> _erreurs = {};

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Rien à précharger : les options d'un article viennent de son **détail**
  /// (`MenuItemDetailSerializer`), lu à l'ouverture de sa fiche.
  ///
  /// Cette méthode ne construisait plus qu'une table de démonstration ; elle ne
  /// garde son corps vide que parce que les écrans l'attendent avant de
  /// composer.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  /// Où en est la lecture des options de [menuItemId].
  EtatDesOptions etatDesOptions(String menuItemId) =>
      _etats[menuItemId] ?? EtatDesOptions.aDemander;

  /// Pourquoi la lecture a échoué, quand elle a échoué.
  String? erreurDesOptions(String menuItemId) => _erreurs[menuItemId];


  /// Les options de [menuItemId], telles que le catalogue les publie.
  ///
  /// Liste vide quand l'article n'en a pas — et c'est une réponse, pas un
  /// manque. La version précédente prenait ce vide pour une invitation : elle
  /// se rabattait sur une table de démonstration écrite dans ce fichier,
  /// appariée à l'article **par son nom**, avec des variantes
  /// (`contains` dans les deux sens). Un article du catalogue nommé « Burger
  /// Classique » — ou seulement « Burger » — héritait donc de suppléments
  /// inventés, libellés en euros (`priceModifier: 2.0`) et affichés en francs
  /// CFA. Aucun de ces identifiants n'existant côté serveur, la ligne partait
  /// ensuite sans options.
  List<CustomizationOption> _getOptionsForMenuItem(String menuItemId) {
    return _itemOptions[menuItemId] ?? const <CustomizationOption>[];
  }

  /// Lit au catalogue les groupes d'options de [menuItemId].
  ///
  /// Trois issues, et elles restent distinctes :
  ///
  /// * le serveur répond avec des groupes → [EtatDesOptions.avecOptions] ;
  /// * le serveur répond sans groupe → [EtatDesOptions.sansOption]. L'article
  ///   n'a rien à personnaliser, ce qui est une réponse valide : la version
  ///   précédente n'enregistrait rien dans ce cas — `if (options.isNotEmpty)` —
  ///   si bien que chaque ouverture de la fiche relançait l'appel, et que
  ///   l'écran ne pouvait pas distinguer ce silence d'un chargement en cours ;
  /// * l'appel échoue → [EtatDesOptions.enErreur], et le motif est conservé.
  ///   Il était auparavant tracé puis oublié, et la fiche se composait comme si
  ///   l'article n'avait aucune option — donc s'ajoutait au panier sans les
  ///   choix que le serveur exige, pour être refusée en 409.
  Future<void> _loadOptionsForMenuItem(String menuItemId) async {
    final etat = _etats[menuItemId];
    if (etat == EtatDesOptions.avecOptions ||
        etat == EtatDesOptions.sansOption) {
      return; // Déjà lu, et la réponse est connue.
    }

    _etats[menuItemId] = EtatDesOptions.enLecture;
    _erreurs.remove(menuItemId);
    notifyListeners();

    try {
      final item = await eccore.CatalogRepository(apiClient: apiClient)
          .getMenuItem(menuItemId);

      final options = [
        for (final group in item.optionGroups)
          for (final option in group.options)
            if (option.isAvailable) CustomizationOption.fromRemote(option, group),
      ];

      _itemOptions[menuItemId] = options;
      _etats[menuItemId] = options.isEmpty
          ? EtatDesOptions.sansOption
          : EtatDesOptions.avecOptions;
      eccore.Journal.trace(
          '✅ ${options.length} option(s) de personnalisation pour $menuItemId',);
    } catch (e) {
      // Pas de repli : une erreur réseau n'est pas un article sans option, et
      // la confondre avec elle laissait composer une ligne que le serveur
      // refuse. L'écran a de quoi le dire et proposer de réessayer.
      _etats[menuItemId] = EtatDesOptions.enErreur;
      _erreurs[menuItemId] =
          'Les options de ce plat n’ont pas pu être chargées.';
      eccore.Journal.trace('⚠️ Options de $menuItemId illisibles : $e');
    }

    notifyListeners();
  }

  /// Relit les options d'un article après un échec.
  Future<void> rechargerLesOptions(String menuItemId) async {
    _etats.remove(menuItemId);
    _itemOptions.remove(menuItemId);
    await _loadOptionsForMenuItem(menuItemId);
  }

  List<CustomizationOption> getOptionsForMenuItem(String menuItemId) {
    return _getOptionsForMenuItem(menuItemId);
  }

  /// Installe les options d'un article sans passer par le réseau.
  ///
  /// Le service est un singleton dont les options viennent du détail d'un
  /// article : sans ce point d'entrée, les règles de choix et de chiffrage ne
  /// seraient vérifiables qu'en lançant l'application.
  @visibleForTesting
  void seedOptionsForTest(
    String menuItemId,
    List<CustomizationOption> options,
  ) {
    _itemOptions[menuItemId] = options;
    _etats[menuItemId] = options.isEmpty
        ? EtatDesOptions.sansOption
        : EtatDesOptions.avecOptions;
  }

  /// Remet le service à neuf entre deux tests — le singleton garde sinon les
  /// options et les états de l'essai précédent.
  @visibleForTesting
  void resetForTest() {
    _itemOptions.clear();
    _etats.clear();
    _erreurs.clear();
    _currentCustomizations.clear();
  }

  // Get options by category for an item
  Map<String, List<CustomizationOption>> getOptionsByCategory(
    String menuItemId,
  ) {
    final allOptions = getOptionsForMenuItem(menuItemId);
    final Map<String, List<CustomizationOption>> categorized = {};

    for (final option in allOptions) {
      categorized[option.category] = (categorized[option.category] ?? [])
        ..add(option);
    }

    return categorized;
  }

  // Start customizing an item session
  Future<void> startCustomization(
    String sessionId,
    String menuItemId,
    String menuItemName,
  ) async {
    // S'assurer que le service est initialisé
    if (!_isInitialized) {
      await initialize();
    }

    // Essayer de charger depuis la base de données
    if (_isInitialized) {
      await _loadOptionsForMenuItem(menuItemId);
    }

    final options =
        _getOptionsForMenuItem(menuItemId);

    eccore.Journal.trace(
        '🎂 Start customization pour $menuItemName ($menuItemId): ${options.length} options disponibles',);

    final Map<String, List<String>> defaultSelections = {};
    final Map<String, int> defaultQuantities = {};

    // Sélections par défaut. La liste des catégories à choix unique était
    // écrite ici en dur (`shape`, `size`...) : un groupe du catalogue nommé
    // « Forme » n'y figurait pas, et deux options par défaut du même groupe se
    // cumulaient — une sélection que le serveur refuse ensuite. La contrainte
    // décide désormais, qu'elle vienne du groupe ou de la table locale.
    for (final option in options) {
      if (option.isDefault) {
        final category = option.category;
        final constraint = constraintFor(menuItemId, category);

        if (constraint.isSingleChoice) {
          defaultSelections[category] = [option.id];
        } else {
          final selected = defaultSelections[category] ?? [];
          // Un groupe borné à N choix ne peut pas en présélectionner N+1.
          if (selected.length < constraint.maxSelections) {
            defaultSelections[category] = selected..add(option.id);
          } else {
            continue;
          }
        }

        defaultQuantities[option.id] = 1;
      }
    }

    eccore.Journal.trace('🎂 Sélections par défaut: $defaultSelections');

    _currentCustomizations[sessionId] = ItemCustomization(
      itemId: sessionId,
      menuItemId: menuItemId,
      menuItemName: menuItemName,
      selections: defaultSelections,
      quantities: defaultQuantities,
    );
    // Une option retenue d'office peut porter un supplément : le total doit
    // le montrer dès l'ouverture, pas seulement après la première touche.
    _rechiffrer(sessionId);

    notifyListeners();
  }

  // Get current customization for a session
  ItemCustomization? getCurrentCustomization(String sessionId) {
    return _currentCustomizations[sessionId];
  }

  // Update selection for an option
  void updateSelection(
      String sessionId, String category, String optionId, bool isSelected,) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    final Map<String, List<String>> newSelections = {
      for (final entry in customization.selections.entries)
        entry.key: List<String>.from(entry.value),
    };

    if (isSelected) {
      // `..add` sans garde retenait deux fois la même option — comptée deux
      // fois dans le total, et envoyée en double au serveur.
      final retenues = newSelections[category] ?? <String>[];
      if (!retenues.contains(optionId)) {
        newSelections[category] = retenues..add(optionId);
      }
    } else {
      newSelections[category]?.remove(optionId);
      if (newSelections[category]?.isEmpty == true) {
        newSelections.remove(category);
      }
    }

    _currentCustomizations[sessionId] =
        customization.copyWith(selections: newSelections);
    _rechiffrer(sessionId);
    notifyListeners();
  }

  // Update quantity for an option
  void updateQuantity(String sessionId, String optionId, int quantity) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    final Map<String, int> newQuantities = Map.from(customization.quantities);

    if (quantity <= 0) {
      newQuantities.remove(optionId);
    } else {
      newQuantities[optionId] = quantity;
    }

    _currentCustomizations[sessionId] =
        customization.copyWith(quantities: newQuantities);
    _rechiffrer(sessionId);
    notifyListeners();
  }

  /// Reporte sur la session le supplément de ses options.
  ///
  /// [ItemCustomization.totalPriceModifier] n'était renseigné que par
  /// [finishCustomization], qui referme la session dans le même geste : le
  /// champ valait donc **zéro pendant toute la composition**. La barre d'ajout
  /// le lisait pour annoncer son total, et affichait le prix nu du plat quelle
  /// que soit la taille, la cuisson ou les suppléments retenus — jusqu'au
  /// panier, où le montant changeait sans explication.
  void _rechiffrer(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    _currentCustomizations[sessionId] = customization.copyWith(
      totalPriceModifier: calculatePriceModifier(sessionId),
    );
  }

  // Update special instructions
  void updateSpecialInstructions(String sessionId, String instructions) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return;

    _currentCustomizations[sessionId] = customization.copyWith(
      specialInstructions: instructions.isEmpty ? null : instructions,
    );
    notifyListeners();
  }

  // Calculate total price modifier for an item
  double calculatePriceModifier(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return 0.0;

    double total = 0.0;

    for (final entry in customization.selections.entries) {
      for (final optionId in entry.value) {
        final quantity = customization.quantities[optionId] ?? 1;
        final option =
            _findOptionById(customization.menuItemId, optionId);
        if (option != null) {
          total += option.priceModifier * quantity;
        }
      }
    }

    return total;
  }

  /// L'option [optionId] **parmi celles de [menuItemId]**.
  ///
  /// La recherche balayait auparavant `_itemOptions.values` — les options de
  /// tous les articles ouverts depuis le lancement, ce service étant un
  /// singleton — et rendait la première correspondance trouvée. Deux articles
  /// qui partagent un identifiant d'option sans partager son prix se
  /// contaminaient donc l'un l'autre, au tarif du premier consulté.
  CustomizationOption? _findOptionById(String menuItemId, String optionId) {
    for (final option in _itemOptions[menuItemId] ?? const <CustomizationOption>[]) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  // Clear customization for an item
  void clearCustomization(String sessionId) {
    _currentCustomizations.remove(sessionId);
    notifyListeners();
  }

  // Clear all customizations
  void clearAllCustomizations() {
    _currentCustomizations.clear();
    notifyListeners();
  }

  /// Contrainte applicable à une catégorie **de cet article**.
  ///
  /// La règle vient du groupe qui porte les options :
  /// `OptionGroup.min_select`/`max_select` sont saisis par l'exploitation, et
  /// c'est ce couple que le serveur revalide (`validate_selection`).
  ///
  /// Une table locale doublait cette règle pour les options de démonstration,
  /// indexée par des étiquettes inventées (`shape`, `size`) quand le serveur
  /// groupe par nom de groupe (« Forme », « Taille ») : elle ne s'appliquait
  /// donc jamais à un vrai article, et rien ne l'y aurait rendue juste. Elle a
  /// disparu avec les options qu'elle décrivait. Reste la contrainte neutre —
  /// aucun minimum, aucun plafond — pour une catégorie dont aucune option n'est
  /// connue, cas qui ne survit qu'au temps du chargement.
  CategoryConstraint constraintFor(String menuItemId, String category) {
    CustomizationOption? remote;
    for (final option in getOptionsForMenuItem(menuItemId)) {
      if (option.category == category && option.isRemote) {
        remote = option;
        break;
      }
    }

    if (remote == null) {
      return CategoryConstraint(category: category);
    }

    return CategoryConstraint(
      category: category,
      minSelections: remote.minSelections,
      maxSelections: remote.maxQuantity,
      isRequired: remote.isRequired,
      // Un groupe qui n'accepte qu'un choix *est* un choix unique : le rendre
      // explicite laisse l'écran proposer des puces exclusives plutôt qu'une
      // case à cocher qu'il refuserait ensuite.
      isSingleChoice: remote.maxQuantity <= 1,
    );
  }

  /// Ce que la ligne du panier doit **montrer** : par groupe, les libellés
  /// retenus.
  ///
  /// L'écran de personnalisation recopiait jusqu'ici ses `selections` telles
  /// quelles — c'est-à-dire des **identifiants**. Le panier affichait donc
  /// « Cuisson du steak: [3fa85f64-5717-4562-b3fc-2c963f66afa6] » à un client
  /// qui avait choisi « Bien cuit ». Les identifiants continuent de partir de
  /// leur côté, par [selectedOptionIds] : ce sont deux usages distincts d'une
  /// même sélection, et les confondre donnait un panier illisible.
  Map<String, String> libellesRetenus(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return const {};

    final libelles = <String, String>{};
    for (final entry in customization.selections.entries) {
      final noms = <String>[];
      for (final optionId in entry.value) {
        final option = _findOptionById(customization.menuItemId, optionId);
        if (option != null) noms.add(option.name);
      }
      if (noms.isNotEmpty) libelles[entry.key] = noms.join(', ');
    }
    return libelles;
  }

  /// Identifiants des options retenues, tels que le panier doit les envoyer.
  ///
  /// Seules les options du catalogue en sortent : un identifiant fabriqué
  /// hors catalogue n'existe pas côté serveur, et l'envoyer ferait refuser
  /// toute la ligne.
  List<String> selectedOptionIds(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return const [];

    final ids = <String>[];
    for (final selected in customization.selections.values) {
      for (final optionId in selected) {
        final option =
            _findOptionById(customization.menuItemId, optionId);
        if (option != null && option.isRemote) {
          ids.add(option.id);
        }
      }
    }
    return ids..sort();
  }

  /// Vrai quand cet article a de vraies options de catalogue — donc quand une
  /// personnalisation peut être commandée telle qu'elle est composée.
  bool hasRemoteOptions(String menuItemId) {
    return getOptionsForMenuItem(menuItemId).any((option) => option.isRemote);
  }

  /// Vrai quand le catalogue impose un choix sur cet article — une cuisson,
  /// une taille, un accompagnement.
  ///
  /// Le détail de l'article est chargé si besoin : la liste du menu ne porte
  /// pas ses groupes d'options, si bien qu'un « + » posé sur une carte ne peut
  /// pas savoir, sans cet appel, qu'il compose une ligne que
  /// `POST /carts/{slug}/lines/` refusera en 409.
  Future<bool> exigeUnChoix(String menuItemId) async {
    if (!_isInitialized) {
      await initialize();
    }
    if (_isInitialized) {
      await _loadOptionsForMenuItem(menuItemId);
    }
    return _getOptionsForMenuItem(menuItemId)
        .any((option) => option.isRemote && option.minSelections > 0);
  }

  // Validate customization for an item
  /// La session porte déjà son article : le nom passé en second argument ne
  /// servait qu'à retrouver les options de démonstration par appariement de
  /// nom, et n'a plus d'objet.
  Map<String, dynamic> validateCustomization(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) {
      return {
        'isValid': false,
        'errors': ['Personnalisation introuvable'],
      };
    }

    final List<String> errors = [];
    final List<CustomizationOption> availableOptions =
        getOptionsForMenuItem(customization.menuItemId);

    // Group options by category
    final Map<String, List<CustomizationOption>> optionsByCategory = {};
    for (final option in availableOptions) {
      optionsByCategory[option.category] =
          (optionsByCategory[option.category] ?? [])..add(option);
    }

    // ✅ Validation centralisée : la contrainte vient du groupe serveur quand
    // il y en a un, de _categoryConstraints sinon. C'est la même règle que
    // `validate_selection` côté Django — la vérifier ici évite au client de
    // découvrir au moment d'ajouter au panier ce qu'il aurait pu savoir en
    // composant.
    for (final category in optionsByCategory.keys) {
      final constraint =
          constraintFor(customization.menuItemId, category);
      final selectedOptions = customization.selections[category] ?? [];
      final selectedCount = selectedOptions.length;

      // Vérifier si requis
      if (constraint.isRequired && selectedCount == 0) {
        // Double vérification : est-ce que cette catégorie a vraiment des options disponibles ?
        if (optionsByCategory[category]!.isNotEmpty) {
           errors.add(
              'Veuillez sélectionner une option pour « $category »',);
        }
      }

      // Vérifier max selections. Un choix unique plafonne à 1 quelle que soit
      // la valeur portée par la contrainte : la table locale laisse
      // `maxSelections` à sa valeur par défaut (99) sur ces catégories, et
      // deux choix y passaient donc inaperçus.
      final effectiveMax =
          constraint.isSingleChoice ? 1 : constraint.maxSelections;
      if (selectedCount > effectiveMax) {
        errors.add(
            'Maximum $effectiveMax choix pour « $category »',);
      }

      // Vérifier min selections (si > 0)
      if (selectedCount < constraint.minSelections) {
         errors.add(
            'Veuillez sélectionner au moins ${constraint.minSelections} option(s) pour « $category »',);
      }
    }

    // Validate quantities
    for (final entry in customization.quantities.entries) {
      final option = _findOptionById(customization.menuItemId, entry.key);
      if (option != null && entry.value > option.maxQuantity) {
        errors.add(
            'Quantité maximale dépassée pour ${option.name} (max: ${option.maxQuantity})',);
      }
    }

    return {'isValid': errors.isEmpty, 'errors': errors};
  }

  // Finish customization and return the final customization
  ItemCustomization? finishCustomization(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return null;

    // Calculate final price modifier
    final double totalPriceModifier = calculatePriceModifier(sessionId);

    // Create final customization with calculated price modifier
    final finalCustomization = customization.copyWith(
      totalPriceModifier: totalPriceModifier,
    );

    // Remove from current customizations
    _currentCustomizations.remove(sessionId);
    notifyListeners();

    return finalCustomization;
  }

  // Get customization summary as string
  String getCustomizationSummary(String sessionId) {
    final customization = _currentCustomizations[sessionId];
    if (customization == null) return '';

    final List<String> summaryParts = [];

    // Add selected options
    for (final entry in customization.selections.entries) {
      final String category = entry.key;
      final List<String> optionNames = [];

      for (final optionId in entry.value) {
        final option =
            _findOptionById(customization.menuItemId, optionId);
        if (option != null) {
          final int quantity = customization.quantities[optionId] ?? 1;
          String optionText = option.name;
          if (quantity > 1) {
            optionText += ' (x$quantity)';
          }
          if (option.priceModifier != 0) {
            optionText +=
                ' (${option.priceModifier > 0 ? '+' : ''}${PriceFormatter.format(option.priceModifier)})';
          }
          optionNames.add(optionText);
        }
      }

      if (optionNames.isNotEmpty) {
        summaryParts.add('$category: ${optionNames.join(', ')}');
      }
    }

    // Add special instructions
    if (customization.specialInstructions?.isNotEmpty == true) {
      summaryParts.add('Instructions: ${customization.specialInstructions}');
    }

    return summaryParts.join('\n');
  }

}
