import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/services/customization_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/services/visual_feedback_service.dart';

class ItemCustomizationScreen extends StatefulWidget {
  final MenuItem item;

  const ItemCustomizationScreen({
    required this.item, super.key,
  });

  @override
  State<ItemCustomizationScreen> createState() =>
      _ItemCustomizationScreenState();
}

class _ItemCustomizationScreenState extends State<ItemCustomizationScreen> {
  late String _sessionId;
  late String _menuItemId;
  final TextEditingController _instructionsController = TextEditingController();

  static const Set<String> _singleChoiceCategories = {
    'size',
    'cooking',
    'shape',
    'tiers',
    'flavor',
    'icing',
    'dietary',
  };

  static const Map<String, int> _categorySelectionLimits = {
    'extra': 3,
    'ingredient': 5,
    'sauce': 2,
    'filling': 2,
    'decoration': 3,
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
    final service = Provider.of<CustomizationService>(context, listen: false);
    if (!service.isInitialized) {
      await service.initialize();
    }
    await service.startCustomization(
      _sessionId,
      _menuItemId,
      widget.item.name,
    );
  }

  @override
  void dispose() {
    Provider.of<CustomizationService>(context, listen: false)
        .clearCustomization(_sessionId);
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Personnaliser ${widget.item.name}'),
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.reviews_outlined),
            tooltip: 'Avis des clients',
            onPressed: () => context.navigateToProductReviews(widget.item),
          ),
        ],
      ),
      body: Column(
        children: [
          // Item header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardColor,
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                        AppTheme.accentColor.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<CustomizationService>(
                        builder: (context, service, child) {
                          final customization =
                              service.getCurrentCustomization(_sessionId);
                          final double finalPrice = widget.item.price +
                              (customization?.totalPriceModifier ?? 0);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                PriceFormatter.format(finalPrice),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (customization?.totalPriceModifier != null &&
                                  (customization!.totalPriceModifier) != 0)
                                Text(
                                  '+ ${PriceFormatter.format(customization.totalPriceModifier)} d’options',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Consumer<CustomizationService>(
              builder: (context, service, child) {
                final Map<String, List<CustomizationOption>> optionsByCategory =
                    service.getOptionsByCategory(
                  _menuItemId,
                  fallbackName: widget.item.name,
                );

                if (optionsByCategory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 64,
                          color: AppTheme.textColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune option de personnalisation',
                          style: TextStyle(
                            color: AppTheme.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ce plat ne peut pas être personnalisé',
                          style: TextStyle(
                            color: AppTheme.textColor.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(service),
                    const SizedBox(height: 16),
                    ...optionsByCategory.entries.map(
                      (entry) => _buildCustomizationSection(
                        entry.key,
                        entry.value,
                        service,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSpecialInstructionsSection(),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),

          // Bottom actions with real-time price preview
          Consumer<CustomizationService>(
            builder: (context, service, _) {
              final customization = service.getCurrentCustomization(_sessionId);
              final priceModifier = customization?.totalPriceModifier ?? 0.0;
              final basePrice = widget.item.price;
              final totalPrice = basePrice + priceModifier;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Prix total en temps réel
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prix total',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  PriceFormatter.format(totalPrice),
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (priceModifier != 0)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Base: ${PriceFormatter.format(basePrice)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+ ${PriceFormatter.format(priceModifier)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _addCustomizedItemToCart(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'Ajouter au panier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection(String category,
      List<CustomizationOption> options, CustomizationService service,) {
    final theme = Theme.of(context);
    final customization = service.getCurrentCustomization(_sessionId);
    final selectedIds = customization?.selections[category] ?? <String>[];
    final isSingleChoice = _singleChoiceCategories.contains(category);
    final maxSelections = _categorySelectionLimits[category];
    
    // Vérifier si la catégorie a des options requises
    final hasRequiredOptions = options.any((opt) => opt.isRequired || opt.isDefault);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _translateCategory(category),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              if (hasRequiredOptions)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Requis',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (maxSelections != null)
            Text(
              'Sélection max : $maxSelections',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 12),
          ...options.map((option) {
            final isSelected = selectedIds.contains(option.id);
            return _buildOptionTile(
              category: category,
              option: option,
              isSelected: isSelected,
              selectedIds: selectedIds,
              service: service,
              singleChoice: isSingleChoice,
              selectionLimit: maxSelections,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CustomizationService service) {
    final theme = Theme.of(context);
    final customization = service.getCurrentCustomization(_sessionId);
    final priceModifier = service.calculatePriceModifier(_sessionId);
    final finalPrice = widget.item.price + priceModifier;

    final selections = customization?.selections ?? {};
    final optionsByCategory = service.getOptionsByCategory(
      _menuItemId,
      fallbackName: widget.item.name,
    );
    final optionLookup = <String, CustomizationOption>{};
    for (final entry in optionsByCategory.entries) {
      for (final option in entry.value) {
        optionLookup[option.id] = option;
      }
    }

    // Vérifier s'il y a des options requises non sélectionnées
    final allOptions = optionsByCategory.values.expand((list) => list).toList();
    final requiredOptions = allOptions.where((opt) => opt.isRequired).toList();
    final selectedIds = selections.values.expand((list) => list).toSet();
    final missingRequiredOptions = requiredOptions
        .where((opt) => !selectedIds.contains(opt.id))
        .toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Résumé de la personnalisation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Indicateur d'options requises manquantes
                if (missingRequiredOptions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${missingRequiredOptions.length} requis',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (selections.isEmpty)
              Text(
                'Personnalisez votre plat pour créer une expérience unique.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...selections.entries.expand((entry) {
                    final category = _translateCategory(entry.key);
                    final options = entry.value
                        .map((id) => optionLookup[id])
                        .whereType<CustomizationOption>()
                        .toList();
                    if (options.isEmpty) return const Iterable<Widget>.empty();
                    return options.map((opt) {
                      final priceText = opt.priceModifier == 0
                          ? ''
                          : ' (+${PriceFormatter.format(opt.priceModifier)})';
                      final quantity = customization?.quantities[opt.id] ?? 1;
                      final quantityText = quantity > 1 ? ' x$quantity' : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$category : ${opt.name}$quantityText$priceText',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      );
                    });
                  }),
                  if (missingRequiredOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Options requises manquantes',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...missingRequiredOptions.map((opt) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.radio_button_unchecked,
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opt.name,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            const Divider(height: 24),
            // Détail du prix de manière plus claire
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildPriceRow(
                    context,
                    'Prix de base',
                    widget.item.price,
                    isSubtotal: true,
                  ),
                  if (priceModifier != 0) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      context,
                      'Options sélectionnées',
                      priceModifier,
                      isSubtotal: true,
                      isPositive: true,
                    ),
                  ],
                  const Divider(height: 16),
                  _buildPriceRow(
                    context,
                    'Total',
                    finalPrice,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    bool isSubtotal = false,
    bool isPositive = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        Text(
          isPositive
              ? '+ ${PriceFormatter.format(amount)}'
              : PriceFormatter.format(amount),
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: isPositive ? Colors.green.shade700 : null,
                  fontWeight: isSubtotal ? FontWeight.w500 : null,
                ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required String category,
    required CustomizationOption option,
    required bool isSelected,
    required List<String> selectedIds,
    required CustomizationService service,
    required bool singleChoice,
    int? selectionLimit,
  }) {
    final theme = Theme.of(context);
    final priceText = option.priceModifier == 0
        ? ''
        : ' (+${PriceFormatter.format(option.priceModifier)})';

    // Widget pour afficher le prix ou les allergènes
    Widget? trailing;
    if (priceText.isNotEmpty) {
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            priceText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (option.allergens != null && option.allergens!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Allergènes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else if (option.allergens != null && option.allergens!.isNotEmpty) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Allergènes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange.shade700,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    if (singleChoice) {
      final groupValue = selectedIds.isNotEmpty ? selectedIds.first : null;
      return Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: AppTheme.primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: RadioListTile<String>(
          value: option.id,
          groupValue: groupValue,
          onChanged: (_) {
            _handleSingleSelection(service, category, option.id, selectedIds);
          },
          title: Row(
            children: [
              Expanded(
                child: Text(
                  option.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (option.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Requis',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: option.description != null 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.description!),
                    if (option.allergens != null && option.allergens!.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showAllergensDialog(option),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Allergènes: ${option.allergens!.join(", ")}',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : (option.allergens != null && option.allergens!.isNotEmpty)
                  ? GestureDetector(
                      onTap: () => _showAllergensDialog(option),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Allergènes: ${option.allergens!.join(", ")}',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
          secondary: trailing,
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              if (value == true &&
                  selectionLimit != null &&
                  selectedIds.length >= selectionLimit &&
                  !selectedIds.contains(option.id)) {
                context.showWarning(
                  'Vous pouvez choisir au maximum $selectionLimit option(s) pour ${_translateCategory(category)}.',
                );
                return;
              }

              _handleMultiSelection(
                service,
                category,
                option.id,
                value ?? false,
              );
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (option.isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Requis',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: option.description != null 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.description!),
                      if (option.allergens != null && option.allergens!.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showAllergensDialog(option),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Allergènes: ${option.allergens!.join(", ")}',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 11,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : (option.allergens != null && option.allergens!.isNotEmpty)
                    ? GestureDetector(
                        onTap: () => _showAllergensDialog(option),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Allergènes: ${option.allergens!.join(", ")}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
            secondary: trailing,
          ),
          if (isSelected && option.maxQuantity > 1)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: _buildQuantitySelector(
                service,
                option,
                category,
                service
                        .getCurrentCustomization(_sessionId)
                        ?.quantities[option.id] ??
                    1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(CustomizationService service,
      CustomizationOption option, String category, int quantity,) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Quantité',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Row(
          children: [
            IconButton(
              onPressed: quantity > 1
                  ? () {
                      service.updateQuantity(
                          _sessionId, option.id, quantity - 1,);
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$quantity'),
            IconButton(
              onPressed: quantity < option.maxQuantity
                  ? () {
                      service.updateQuantity(
                          _sessionId, option.id, quantity + 1,);
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }

  void _handleSingleSelection(CustomizationService service, String category,
      String optionId, List<String> selectedIds,) {
    if (selectedIds.contains(optionId)) {
      service.updateSelection(_sessionId, category, optionId, false);
      selectedIds.remove(optionId);
    } else {
      service.updateSelection(_sessionId, category, optionId, true);
      selectedIds.clear();
      selectedIds.add(optionId);
    }
    setState(() {});
  }

  void _handleMultiSelection(CustomizationService service, String category,
      String optionId, bool value,) {
    if (value) {
      service.updateSelection(_sessionId, category, optionId, true);
      setState(() {});
    } else {
      service.updateSelection(_sessionId, category, optionId, false);
      setState(() {});
    }
  }

  Widget _buildSpecialInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Instructions spéciales',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ex: sans oignons, sauce à part...',
            border: const OutlineInputBorder(),
            suffixIcon: _instructionsController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _instructionsController.clear();
                      Provider.of<CustomizationService>(context, listen: false)
                          .updateSpecialInstructions(_sessionId, '');
                      setState(() {});
                    },
                  ),
          ),
          onChanged: (value) =>
              Provider.of<CustomizationService>(context, listen: false)
                  .updateSpecialInstructions(_sessionId, value.trim()),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_instructionsController.text.length}/180',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }

  void _addCustomizedItemToCart() {
    final service = Provider.of<CustomizationService>(context, listen: false);
    final validation =
        service.validateCustomization(_sessionId, widget.item.name);

    if (!validation['isValid']) {
      _showErrorDialog(validation['errors']);
      return;
    }

    final customization = service.finishCustomization(_sessionId);
    if (customization != null) {
      final double finalPrice = widget.item.price + customization.totalPriceModifier;

      // Convertir les personnalisations en format Map pour le panier
      final Map<String, dynamic> customizationsMap = {
        'selections': customization.selections,
        'quantities': customization.quantities,
        'special_instructions': customization.specialInstructions,
        'total_price_modifier': customization.totalPriceModifier,
        'summary': service.getCustomizationSummary(_sessionId),
      };

      final MenuItem customizedItem = MenuItem(
        id: widget.item.id, // Utiliser l'ID original du menu item
        name: widget.item.name,
        description:
            '${widget.item.description}\n${service.getCustomizationSummary(_sessionId)}',
        price: finalPrice,
        categoryId: widget.item.categoryId,
        category: widget.item.category,
        imageUrl: widget.item.imageUrl,
        isPopular: widget.item.isPopular,
        isVegetarian: widget.item.isVegetarian,
        availableQuantity: widget.item.availableQuantity,
      );

      Provider.of<CartService>(context, listen: false).addItem(
        customizedItem,
        customizations: customizationsMap,
      );

      Navigator.pop(context);
      
      // Afficher le feedback amélioré avec animation
      context.showAddToCartFeedback(
        widget.item.name,
        onViewCart: () => context.navigateToCart(),
      );
    }
  }

  void _showErrorDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'Personnalisation incomplète',
          style: TextStyle(color: AppTheme.textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.map((error) => Text('• $error')).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  String _translateCategory(String category) {
    switch (category) {
      case 'size':
        return 'Taille';
      case 'cooking':
        return 'Cuisson';
      case 'ingredient':
        return 'Ingrédients';
      case 'sauce':
        return 'Sauces';
      case 'extra':
        return 'Extras';
      case 'shape':
        return 'Forme';
      case 'flavor':
        return 'Saveur';
      case 'filling':
        return 'Garniture';
      case 'decoration':
        return 'Décoration';
      case 'tiers':
        return 'Étages';
      case 'icing':
        return 'Glaçage';
      case 'dietary':
        return 'Préférence alimentaire';
      default:
        return category;
    }
  }

  void _showAllergensDialog(CustomizationOption option) {
    if (option.allergens == null || option.allergens!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Allergènes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette option contient les allergènes suivants:',
              style: TextStyle(color: AppTheme.textColor),
            ),
            const SizedBox(height: 12),
            ...option.allergens!.map(
              (allergen) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        allergen,
                        style: const TextStyle(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
