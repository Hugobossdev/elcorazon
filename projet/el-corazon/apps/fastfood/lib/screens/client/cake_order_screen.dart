import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_fast/repositories/django_menu_repository.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/services/offline_sync_service.dart';
import 'package:elcora_fast/presentation/preselection_gateau.dart';
import 'package:elcora_fast/presentation/recapitulatif_gateau.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

enum CakeDeliveryMethod { delivery, pickup }

/// Écran dédié aux commandes de gâteaux : catalogue prêt-à-commander
/// et configurateur complet pour les créations sur-mesure.
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
  bool _isDisposed = false; // 🛡️ Protection contre setState après dispose
  bool _isInitializingCustomization = false; // 🔒 Verrou d'initialisation
  CakeDeliveryMethod _deliveryMethod = CakeDeliveryMethod.delivery;

  // 🗑️ SUPPRESSION: Plus besoin des contraintes en dur ici, on utilise celles du service
  // final Map<String, int> _categorySelectionLimits = const { ... };
  // static const Set<String> _singleChoiceCategories = { ... };

  // Data loaded from Supabase
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

  // 🗑️ SUPPRESSION: Plus besoin de cette liste en dur
  /* static const Set<String> _singleChoiceCategories = {
    'shape',
    'size',
    'flavor',
    'tiers',
    'icing',
    'dietary',
  }; */

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customizationId = _generateCustomizationId();

    // ✅ Séquencer le chargement : d'abord DB, puis initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCakesFromDatabase();
      // N'initialiser que si le chargement a réussi
      if (!_isDisposed && _customCakeItem != null) {
        await _initializeCustomization();
      }
    });
  }

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

      // Charger les catégories pour trouver celle des desserts
      final categories = await menuRepository.getMenuCategories();
      final dessertsCategory = categories
          .where(
            (cat) =>
                cat.name.toLowerCase().contains('dessert') ||
                cat.name.toLowerCase().contains('dessert'),
          )
          .firstOrNull;

      _dessertsCategoryId = dessertsCategory?.id;

      if (_dessertsCategoryId == null) {
        // Si aucune catégorie desserts n'est trouvée, utiliser tous les items disponibles
        Journal.trace(
          '⚠️ Catégorie desserts non trouvée, chargement de tous les items',
        );
      }

      // Charger les gâteaux depuis le catalogue
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

      Journal.trace('✅ Loaded ${_readyCakes.length} ready cakes from database');
    } catch (e) {
      Journal.trace('❌ Error loading cakes from database: $e');
      if (!_isDisposed && mounted && context.mounted) {
        setState(() {
          _error = 'Erreur lors du chargement des gâteaux: $e';
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
        Journal.trace('✅ Gâteau personnalisé trouvé au catalogue : ${customCake.id}');
        return;
      }

      // Créer un item par défaut si la création en DB a échoué ou si pas de catégorie
      _customCakeIsFromCatalog = false;
      _customCakeItem = _gateauEnApercu(
        id: 'cake-custom-${DateTime.now().millisecondsSinceEpoch}',
      );
      Journal.trace('⚠️ Custom cake item not found, using default in-memory item');
    } catch (e) {
      Journal.trace('❌ Error loading custom cake item: $e');
      // Fallback vers un item par défaut
      _customCakeIsFromCatalog = false;
      _customCakeItem = _gateauEnApercu(id: 'cake-custom-default');
    }
  }

  Future<void> _initializeCustomization({eccore.MenuItem? prefillFrom}) async {
    // 🔒 Empêcher les initialisations multiples en parallèle
    if (_isInitializingCustomization) {
      Journal.trace('⚠️ Initialisation déjà en cours, annulation...');
      return;
    }

    if (_customCakeItem == null) {
      Journal.trace(
        '⚠️ _customCakeItem est null, impossible d\'initialiser la personnalisation',
      );
      return;
    }

    if (_isDisposed || !mounted || !context.mounted) return;

    _isInitializingCustomization = true; // 🔒 Verrouiller

    try {
      final customizationService =
          Provider.of<CustomizationService>(context, listen: false);

      // S'assurer que le service est initialisé
      if (!customizationService.isInitialized) {
        Journal.trace('🔄 Initialisation du service de personnalisation...');
        await customizationService.initialize();
      }
      if (!mounted || !context.mounted) return;

      Journal.trace(
        '🎂 Démarrage de la personnalisation pour: ${_customCakeItem!.name} (${_customCakeItem!.id})',
      );

      await customizationService.startCustomization(
        _customizationId,
        _customCakeItem!.id,
        _customCakeItem!.name,
      );

      // Logique de pré-remplissage intelligente
      if (prefillFrom != null) {
        _applySmartPrefill(customizationService, prefillFrom);
      }

      Journal.trace('✅ Personnalisation initialisée avec succès');

      // Forcer un rebuild pour afficher les options
      if (!_isDisposed && mounted) {
        setState(() {});
      }
    } catch (e) {
      Journal.trace(
        '❌ Erreur lors de l\'initialisation de la personnalisation: $e',
      );
      if (!_isDisposed && mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des options: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isInitializingCustomization = false; // 🔓 Déverrouiller
    }
  }

  /// Le gâteau sur mesure **tel qu'on le montre** quand le catalogue ne le
  /// publie pas.
  ///
  /// Ce n'est pas un article commandable : `_customCakeIsFromCatalog` reste
  /// faux et l'écran affiche `_buildUnpublishedNotice`. Il n'existe que pour
  /// que les options aient un support à afficher.
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
      image:
          'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pré-sélectionné selon "${cake.name}" ($prefilledCount options)',
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // 🛡️ Marquer comme disposé

    // Nettoyer la personnalisation si le service est disponible
    try {
      if (mounted && context.mounted) {
        final customizationService =
            Provider.of<CustomizationService>(context, listen: false);
        customizationService.clearCustomization(_customizationId);
      }
    } catch (e) {
      Journal.trace('⚠️ Error cleaning customization on dispose: $e');
    }

    _messageController.dispose();
    _contactController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Commander un gâteau',
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.cake_outlined), text: 'Catalogue'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Personnaliser'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReadyMadeTab(theme),
          _buildCustomizationTab(theme),
        ],
      ),
    );
  }

  Widget _buildReadyMadeTab(ThemeData theme) {
    if (_isLoading) {
      return _buildSkeletonLoader(theme);
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oups !',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                onPressed: _loadCakesFromDatabase,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_readyCakes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cake_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucun gâteau disponible',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Revenez bientôt pour découvrir nos nouvelles créations !',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _readyCakes.length,
      itemBuilder: (context, index) {
        final cake = _readyCakes[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _buildCakeCard(theme, cake, index),
        );
      },
    );
  }

  Widget _buildCakeCard(ThemeData theme, eccore.MenuItem cake, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleReadyCakeOrder(cake),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cake.image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Hero(
                      tag: 'cake-image-${cake.id}',
                      child: Image.network(
                        cake.image!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primaryContainer,
                                theme.colorScheme.secondaryContainer,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            Icons.cake_rounded,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (cake.isPopular)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Populaire',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cake.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cake.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          PriceFormatter.format(cake.prixAffiche),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildActionButton(
                        theme,
                        icon: Icons.build_circle_outlined,
                        label: 'Personnaliser',
                        isPrimary: false,
                        onPressed: () async {
                          await _resetCustomization(
                            Provider.of<CustomizationService>(
                              context,
                              listen: false,
                            ),
                            prefillFrom: cake,
                          );
                          _tabController.animateTo(1);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        theme,
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Commander',
                        isPrimary: true,
                        onPressed: () => _handleReadyCakeOrder(cake),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 100)),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 24,
                        width: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            height: 40,
                            width: 100,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 40,
                            width: 120,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomizationTab(ThemeData theme) {
    if (_isLoading || _customCakeItem == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cake_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isLoading
                    ? 'Chargement des options...'
                    : 'Gâteau personnalisé non disponible',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 12),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Chargement des options de personnalisation...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

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

        // Organiser les catégories par ordre de priorité pour une meilleure UX
        final categoryOrder = [
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

        // Trier les catégories selon l'ordre de priorité
        final sortedCategories = optionsByCategory.entries.toList();
        sortedCategories.sort((a, b) {
          final indexA = categoryOrder.indexOf(a.key);
          final indexB = categoryOrder.indexOf(b.key);
          if (indexA == -1 && indexB == -1) return a.key.compareTo(b.key);
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecapitulatifGateau(
                gateau: _customCakeItem!,
                customizationId: _customizationId,
                priceModifier: priceModifier,
                finalPrice: finalPrice,
              ),
              const SizedBox(height: 16),
              ...sortedCategories.map((entry) {
                final category = entry.key;
                final options = entry.value;
                final selectedIds =
                    customization.selections[category] ?? <String>[];

                // ✅ Contrainte de l'article : celle du groupe serveur quand il
                // y en a un, la table locale sinon.
                final constraint = _constraintFor(service, category);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildCategorySection(
                    theme,
                    category: category,
                    options: options,
                    selectedIds: selectedIds,
                    constraint: constraint, // On passe l'objet complet
                    service: service,
                  ),
                );
              }),
              const SizedBox(height: 12),
              _buildMessageField(theme, service),
              const SizedBox(height: 12),
              _buildDeliverySelectors(theme),
              const SizedBox(height: 20),
              if (!isOrderable) ...[
                _buildUnpublishedNotice(theme),
                const SizedBox(height: 16),
              ],
              // Dégradé : c'est l'action qui engage la commande, et le design
              // system lui réserve cette emphase — au même titre que
              // « Commander » au panier et au règlement.
              ActionButton(
                label: 'Ajouter au panier',
                emphasis: ActionEmphasis.gradient,
                icon: Icons.check_circle_outline,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting || !isOrderable
                    ? null
                    : () => _confirmCustomCakeOrder(service),
              ),
            ],
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
  Widget _buildUnpublishedNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande sur mesure indisponible',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le gâteau personnalisé n\'est pas encore publié à la carte. '
                  'Les options ci-dessus sont un aperçu : contactez la '
                  'boutique pour composer votre gâteau.',
                  style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildCategorySection(
    ThemeData theme, {
    required String category,
    required List<CustomizationOption> options,
    required List<String> selectedIds,
    required CategoryConstraint constraint,
    required CustomizationService service,
  }) {
    final title = service.translateCategory(category);
    final maxSelections = constraint.maxSelections;

    // UI améliorée : Indicateur (Requis) ou (Max X)
    String subtitle = '';
    Color? subtitleColor;

    if (constraint.isRequired) {
      subtitle = 'Requis';
      subtitleColor = theme.colorScheme.error;
    } else if (!constraint.isSingleChoice && maxSelections < 99) {
      final remaining = maxSelections - selectedIds.length;
      subtitle = 'Max $maxSelections • Reste: $remaining';
      subtitleColor = remaining == 0
          ? theme.colorScheme.error
          : theme.colorScheme.secondary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (constraint.isRequired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Requis',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty && !constraint.isRequired) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Widget spécial pour les couleurs
          if (category == 'color')
            _buildColorSelector(
              options,
              selectedIds,
              constraint,
              service,
              theme,
            )
          // Widget spécial pour les textures
          else if (category == 'texture')
            _buildTextureSelector(
              options,
              selectedIds,
              constraint,
              service,
              theme,
            )
          // Widget standard pour les autres catégories
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((option) {
                final isSelected = selectedIds.contains(option.id);
                final priceSuffix = option.priceModifier == 0
                    ? ''
                    : ' (+${PriceFormatter.format(option.priceModifier)})';

                if (constraint.isSingleChoice) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (category == 'shape')
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                _getShapeIcon(option.id),
                                size: 18,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              '${option.name}$priceSuffix',
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primaryContainer,
                      checkmarkColor: theme.colorScheme.onPrimaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      elevation: isSelected ? 2 : 0,
                      onSelected: (selected) {
                        if (!selected) return;
                        _handleSingleSelection(
                          service,
                          category,
                          option.id,
                          selectedIds,
                        );
                      },
                    ),
                  );
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (category == 'decoration')
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              _getDecorationIcon(option.id),
                              size: 18,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            '${option.name}$priceSuffix',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.secondaryContainer,
                    checkmarkColor: theme.colorScheme.onSecondaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    elevation: isSelected ? 2 : 0,
                    onSelected: (selected) {
                      if (selected && selectedIds.length >= maxSelections) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Vous pouvez choisir au maximum $maxSelections option(s) pour $title.',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: theme.colorScheme.errorContainer,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }
                      _handleMultiSelection(
                        service,
                        category,
                        option.id,
                        selected,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageField(ThemeData theme, CustomizationService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.message_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Message sur le gâteau',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Optionnel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLength: 60,
            decoration: InputDecoration(
              hintText: 'Ex: Joyeux anniversaire Jade !',
              hintStyle: TextStyle(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              counterStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: (value) => service.updateSpecialInstructions(
              _customizationId,
              value.trim(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySelectors(ThemeData theme) {
    String dateLabel = 'Sélectionner une date';
    if (_customDeliveryDate != null) {
      dateLabel = _formatDate(_customDeliveryDate!);
    }

    String timeLabel = 'Sélectionner une heure';
    if (_customDeliveryTime != null && context.mounted) {
      timeLabel = _customDeliveryTime!.format(context);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Planification & retrait',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sélecteur de méthode amélioré
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _deliveryMethod = CakeDeliveryMethod.delivery;
                      });
                    },
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _deliveryMethod == CakeDeliveryMethod.delivery
                            ? const LinearGradient(
                                colors: AppColors.primaryGradient,
                              )
                            : null,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining_rounded,
                            color:
                                _deliveryMethod == CakeDeliveryMethod.delivery
                                    ? Colors.white
                                    : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Livraison',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  _deliveryMethod == CakeDeliveryMethod.delivery
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                              fontWeight:
                                  _deliveryMethod == CakeDeliveryMethod.delivery
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _deliveryMethod = CakeDeliveryMethod.pickup;
                      });
                    },
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _deliveryMethod == CakeDeliveryMethod.pickup
                            ? const LinearGradient(
                                colors: AppColors.primaryGradient,
                              )
                            : null,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_rounded,
                            color: _deliveryMethod == CakeDeliveryMethod.pickup
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Retrait',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  _deliveryMethod == CakeDeliveryMethod.pickup
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                              fontWeight:
                                  _deliveryMethod == CakeDeliveryMethod.pickup
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_deliveryMethod == CakeDeliveryMethod.delivery) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact (téléphone ou email)',
                hintText: 'Ex: +33 6 12 34 56 78',
                prefixIcon: Icon(
                  Icons.phone_rounded,
                  color: theme.colorScheme.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.event_rounded,
                    color: _customDeliveryDate != null
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  label: Text(
                    dateLabel,
                    style: TextStyle(
                      fontWeight: _customDeliveryDate != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onPressed: _pickCustomDeliveryDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _customDeliveryDate != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: _customDeliveryDate != null ? 2 : 1,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.schedule_rounded,
                    color: _customDeliveryTime != null
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  label: Text(
                    timeLabel,
                    style: TextStyle(
                      fontWeight: _customDeliveryTime != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onPressed: _customDeliveryDate == null
                      ? null
                      : _pickCustomDeliveryTime,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _customDeliveryTime != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: _customDeliveryTime != null ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

      final isOnline = offlineSyncService.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cake.name} ajouté au panier !',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isOnline)
                      Text(
                        'Sauvegardé hors ligne - synchronisation automatique',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir le panier',
            textColor: Colors.white,
            onPressed: () => context.navigateToCart(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError('Erreur lors de l\'ajout au panier: ${e.toString()}');
      }
      Journal.trace('❌ Error adding ready cake to cart: $e');
    }
  }

  Future<void> _confirmCustomCakeOrder(CustomizationService service) async {
    if (_customCakeItem == null) {
      _showError('Gâteau personnalisé non disponible. Veuillez réessayer.');
      return;
    }

    // Garde de sécurité : le bouton est déjà désactivé dans ce cas, mais
    // déposer un article hors catalogue produirait une ligne que le serveur
    // refuse — autant le dire ici plutôt qu'à la synchronisation.
    if (!_customCakeIsFromCatalog) {
      _showError(
        'Le gâteau personnalisé n\'est pas encore publié à la carte : '
        'la commande sur mesure est indisponible.',
      );
      return;
    }

    // Vérifier que la personnalisation existe
    final customization = service.getCurrentCustomization(_customizationId);
    if (customization == null) {
      _showError(
        'Erreur: Personnalisation introuvable. Veuillez réinitialiser.',
      );
      // Réinitialiser la personnalisation
      await _initializeCustomization();
      return;
    }

    // Validation des options de personnalisation requises pour les gâteaux
    final validation =
        service.validateCustomization(_customizationId, _customCakeItem!.name);
    if (validation['isValid'] != true) {
      final errors = (validation['errors'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();

      // 🗑️ SUPPRESSION: La validation est maintenant faite dynamiquement par le service via validateCustomization
      // final requiredCategories = ['shape', 'size', 'flavor', 'tiers', 'icing', 'dietary'];
      // final missingRequired = <String>[];

      // for (final category in requiredCategories) { ... }

      // if (missingRequired.isNotEmpty) { ... }

      // Pour les autres erreurs, afficher un avertissement
      if (errors.isNotEmpty) {
        _showError(
          errors.first,
        ); // On affiche la première erreur (qui peut être un champ requis manquant)
        setState(() => _isSubmitting = false);
        return;
      }
    }

    // Validation de la date et heure
    if (_customDeliveryDate == null || _customDeliveryTime == null) {
      _showError(
        'Veuillez sélectionner la date et l\'heure de livraison/retrait.',
      );
      setState(() => _isSubmitting = false);
      return;
    }

    // Validation de la date (minimum 24h à l'avance pour les gâteaux personnalisés)
    final selectedDateTime = DateTime(
      _customDeliveryDate!.year,
      _customDeliveryDate!.month,
      _customDeliveryDate!.day,
      _customDeliveryTime!.hour,
      _customDeliveryTime!.minute,
    );
    final now = DateTime.now();
    final difference = selectedDateTime.difference(now);

    if (difference.isNegative) {
      _showError('La date et l\'heure sélectionnées sont dans le passé.');
      setState(() => _isSubmitting = false);
      return;
    }

    if (difference.inHours < 24) {
      final hoursNeeded = 24 - difference.inHours;
      _showError(
        'Pour un gâteau personnalisé, veuillez commander au moins 24 heures à l\'avance. Il reste $hoursNeeded heure(s) avant la date sélectionnée.',
      );
      setState(() => _isSubmitting = false);
      return;
    }

    // Validation du contact si livraison
    if (_deliveryMethod == CakeDeliveryMethod.delivery &&
        (_contactController.text.trim().isEmpty)) {
      _showError(
        'Veuillez fournir un numéro de téléphone ou un email pour la livraison.',
      );
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
      _showError('Impossible de finaliser la personnalisation.');
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
      final translatedCategory = service.translateCategory(category);
      customizationsMap[translatedCategory] = labels.join(', ');
    });

    final deliveryDateIso = DateTime(
      _customDeliveryDate!.year,
      _customDeliveryDate!.month,
      _customDeliveryDate!.day,
      _customDeliveryTime!.hour,
      _customDeliveryTime!.minute,
    );

    final mode = _deliveryMethod == CakeDeliveryMethod.delivery
        ? 'Livraison'
        : 'Retrait en boutique';
    final heure = mounted && context.mounted
        ? _customDeliveryTime!.format(context)
        : '${_customDeliveryTime!.hour.toString().padLeft(2, '0')}:${_customDeliveryTime!.minute.toString().padLeft(2, '0')}';

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

      // Afficher un message selon le statut de connexion
      final isOnline = offlineSyncService.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gâteau personnalisé ajouté au panier !',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!isOnline)
                      Text(
                        'Sauvegardé hors ligne - synchronisation automatique',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir le panier',
            textColor: Colors.white,
            onPressed: () => context.navigateToCart(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Réinitialiser pour une prochaine personnalisation
      await _resetCustomization(service);
      setState(() => _isSubmitting = false);
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Erreur lors de l\'ajout au panier: ${e.toString()}');
      Journal.trace('❌ Error adding custom cake to cart: $e');
    }
  }

  Future<void> _resetCustomization(
    CustomizationService service, {
    eccore.MenuItem? prefillFrom,
  }) async {
    // Nettoyer la personnalisation précédente
    service.clearCustomization(_customizationId);

    // Générer un nouvel ID de personnalisation
    _customizationId = _generateCustomizationId();

    // Réinitialiser les champs
    _messageController.clear();
    _contactController.clear();
    _customDeliveryDate = null;
    _customDeliveryTime = null;
    _deliveryMethod = CakeDeliveryMethod.delivery;

    // Réinitialiser la personnalisation
    if (_customCakeItem != null) {
      await _initializeCustomization(prefillFrom: prefillFrom);
    }

    // Forcer un rebuild
    if (mounted) {
      setState(() {});
    }
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
        _customDeliveryTime = null; // reset time when date changes
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
    // Désélectionner les autres options de la même catégorie
    for (final selectedId in currentlySelected) {
      if (selectedId != optionId) {
        service.updateSelection(
          _customizationId,
          category,
          selectedId,
          false,
        );
      }
    }

    // Sélectionner la nouvelle option
    service.updateSelection(
      _customizationId,
      category,
      optionId,
      true,
    );

    // Feedback visuel
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
    service.updateSelection(
      _customizationId,
      category,
      optionId,
      isSelected,
    );

    // Feedback visuel pour les sélections multiples
    if (mounted && context.mounted && isSelected) {
      final customization = service.getCurrentCustomization(_customizationId);
      final selectedCount = (customization?.selections[category] ?? []).length;

      // ✅ Utilisation de la contrainte dynamique
      final constraint = _constraintFor(service, category);
      final maxSelections = constraint.maxSelections;

      if (selectedCount >= maxSelections && maxSelections < 99) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum atteint pour ${service.translateCategory(category)} ($maxSelections sélection(s))',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _generateCustomizationId() =>
      'cake_${DateTime.now().millisecondsSinceEpoch}';

  // Widget spécial pour sélectionner les couleurs
  Widget _buildColorSelector(
    List<CustomizationOption> options,
    List<String> selectedIds,
    CategoryConstraint constraint,
    CustomizationService service,
    ThemeData theme,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedIds.contains(option.id);
        final color = _getColorFromOption(option.id);

        return GestureDetector(
          onTap: () {
            if (constraint.isSingleChoice) {
              _handleSingleSelection(service, 'color', option.id, selectedIds);
            } else {
              _handleMultiSelection(service, 'color', option.id, !isSelected);
            }
          },
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: _getContrastColor(color),
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  // Widget spécial pour sélectionner les textures
  Widget _buildTextureSelector(
    List<CustomizationOption> options,
    List<String> selectedIds,
    CategoryConstraint constraint,
    CustomizationService service,
    ThemeData theme,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = selectedIds.contains(option.id);
        final textureStyle = _getTextureStyle(option.id);

        return GestureDetector(
          onTap: () {
            if (constraint.isSingleChoice) {
              _handleSingleSelection(
                service,
                'texture',
                option.id,
                selectedIds,
              );
            } else {
              _handleMultiSelection(service, 'texture', option.id, !isSelected);
            }
          },
          child: Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              gradient: textureStyle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      color: _getContrastColor(Colors.white),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Helper pour obtenir la couleur depuis l'option
  Color _getColorFromOption(String optionId) {
    switch (optionId) {
      case 'cake-color-white':
        return Colors.white;
      case 'cake-color-pink':
        return Colors.pink.shade200;
      case 'cake-color-blue':
        return Colors.blue.shade200;
      case 'cake-color-purple':
        return Colors.purple.shade200;
      case 'cake-color-gradient':
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  // Helper pour obtenir le style de texture
  LinearGradient _getTextureStyle(String optionId) {
    switch (optionId) {
      case 'cake-texture-smooth':
        return LinearGradient(
          colors: [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'cake-texture-rough':
        return LinearGradient(
          colors: [Colors.brown.shade300, Colors.brown.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'cake-texture-ombré':
        return LinearGradient(
          colors: [Colors.pink.shade200, Colors.purple.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'cake-texture-marble':
        return LinearGradient(
          colors: [Colors.white, Colors.grey.shade300, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade300],
        );
    }
  }

  // Helper pour obtenir une couleur contrastée
  Color _getContrastColor(Color color) {
    final brightness = color.computeLuminance();
    return brightness > 0.5 ? Colors.black : Colors.white;
  }

  // Helper pour obtenir l'icône de forme
  IconData _getShapeIcon(String optionId) {
    switch (optionId) {
      case 'cake-shape-round':
        return Icons.circle;
      case 'cake-shape-square':
        return Icons.square;
      case 'cake-shape-heart':
        return Icons.favorite;
      case 'cake-shape-rectangle':
        return Icons.rectangle;
      default:
        return Icons.cake;
    }
  }

  // Helper pour obtenir l'icône de décoration
  IconData _getDecorationIcon(String optionId) {
    if (optionId.contains('fruits')) return Icons.apple;
    if (optionId.contains('chocolate')) return Icons.cookie;
    if (optionId.contains('macarons')) return Icons.circle;
    if (optionId.contains('photo')) return Icons.photo;
    if (optionId.contains('message')) return Icons.message;
    if (optionId.contains('flowers')) return Icons.local_florist;
    if (optionId.contains('fondant')) return Icons.palette;
    if (optionId.contains('glitter')) return Icons.auto_awesome;
    if (optionId.contains('gold')) return Icons.star;
    if (optionId.contains('3d')) return Icons.layers;
    return Icons.celebration;
  }
}
