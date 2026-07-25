import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/promotion_service.dart';
import '../../utils/dialog_helper.dart';
import '../../utils/price_formatter.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PromotionService>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Promotions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Toutes', icon: Icon(Icons.list)),
            Tab(text: 'Actives', icon: Icon(Icons.check_circle)),
            Tab(text: 'Expirées', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PromotionService>().refresh(),
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showPromotionForm(context),
            tooltip: 'Créer une promotion',
          ),
        ],
      ),
      body: Consumer<PromotionService>(
        builder: (context, promoService, _) {
          if (promoService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (promoService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: scheme.error.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: ${promoService.error}',
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => promoService.refresh(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPromotionsList(promoService.promotions),
              _buildPromotionsList(promoService.activePromotions),
              _buildPromotionsList(promoService.expiredPromotions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromotionsList(List<Promotion> promotions) {
    if (promotions.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune promotion',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: promotions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final promotion = promotions[index];
        return _buildPromotionCard(context, promotion);
      },
    );
  }

  Widget _buildPromotionCard(BuildContext context, Promotion promotion) {
    final scheme = Theme.of(context).colorScheme;
    final isExpired = promotion.isExpired;
    final isAvailable = promotion.isAvailable;

    return Card(
      elevation: 2,
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: () => _showPromotionDetails(context, promotion),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promotion.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            promotion.description,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? scheme.secondaryContainer
                            : isExpired
                                ? scheme.errorContainer
                                : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAvailable
                            ? 'Active'
                            : isExpired
                                ? 'Expirée'
                                : 'Inactive',
                        style: TextStyle(
                          color: isAvailable
                              ? scheme.onSecondaryContainer
                              : isExpired
                                  ? scheme.onErrorContainer
                                  : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.local_offer,
                      promotion.promoCode,
                      scheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.percent,
                      _getDiscountText(promotion),
                      scheme.primary,
                    ),
                    if (promotion.usageLimit != null) ...[
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.people,
                        '${promotion.usedCount}/${promotion.usageLimit}',
                        scheme.secondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(promotion.startDate)} - ${_formatDate(promotion.endDate)}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDiscountText(Promotion promotion) {
    switch (promotion.discountType) {
      case 'percentage':
        return '${promotion.discountValue}%';
      case 'fixed':
        return formatPrice(promotion.discountValue);
      case 'free_delivery':
        return 'Livraison gratuite';
      default:
        return 'Réduction';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showPromotionForm(BuildContext context, {Promotion? promotion}) {
    DialogHelper.showSafeDialog(
      context: context,
      builder: (context) => _PromotionFormDialog(promotion: promotion),
    );
  }

  void _showPromotionDetails(BuildContext context, Promotion promotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(promotion.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Description', promotion.description),
              _buildDetailRow('Code promo', promotion.promoCode),
              _buildDetailRow('Type', promotion.discountType),
              _buildDetailRow('Valeur', _getDiscountText(promotion)),
              _buildDetailRow(
                'Montant minimum',
                formatPrice(promotion.minOrderAmount),
              ),
              if (promotion.maxDiscount != null)
                _buildDetailRow(
                  'Réduction max',
                  formatPrice(promotion.maxDiscount!),
                ),
              if (promotion.usageLimit != null)
                _buildDetailRow(
                  'Limite d\'utilisation',
                  '${promotion.usageLimit}',
                ),
              _buildDetailRow('Utilisations', '${promotion.usedCount}'),
              _buildDetailRow('Début', _formatDate(promotion.startDate)),
              _buildDetailRow('Fin', _formatDate(promotion.endDate)),
              _buildDetailRow(
                'Statut',
                promotion.isAvailable ? 'Active' : 'Inactive',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (promotion.isActive)
            TextButton(
              onPressed: () {
                context.read<PromotionService>().togglePromotionStatus(
                      promotion.id,
                      false,
                    );
                Navigator.pop(context);
              },
              child: const Text('Désactiver'),
            )
          else
            TextButton(
              onPressed: () {
                context.read<PromotionService>().togglePromotionStatus(
                      promotion.id,
                      true,
                    );
                Navigator.pop(context);
              },
              child: const Text('Activer'),
            ),
          TextButton(
            onPressed: () {
              _showPromotionForm(context, promotion: promotion);
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PromotionFormDialog extends StatefulWidget {
  final Promotion? promotion;
  const _PromotionFormDialog({this.promotion});

  @override
  State<_PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class _PromotionFormDialogState extends State<_PromotionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _usageLimitController = TextEditingController();

  String _type = 'percentage';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.promotion;
    if (p != null) {
      _nameController.text = p.name;
      _descController.text = p.description;
      _codeController.text = p.promoCode;
      _valueController.text = p.discountValue.toString();
      _minOrderController.text = p.minOrderAmount.toString();
      _maxDiscountController.text = p.maxDiscount?.toString() ?? '';
      _usageLimitController.text = p.usageLimit?.toString() ?? '';
      _type = p.discountType;
      _startDate = p.startDate;
      _endDate = p.endDate;
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(500.0, 700.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(600.0, 900.0);

    return Dialog(
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.promotion == null
                          ? 'Créer une promotion'
                          : 'Modifier la promotion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Description requise'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _type,
                              items: const [
                                DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text('Pourcentage'),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('Montant fixe'),
                                ),
                                DropdownMenuItem(
                                  value: 'free_delivery',
                                  child: Text('Livraison gratuite'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _type = v!),
                              decoration: const InputDecoration(
                                labelText: 'Type de réduction *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _valueController,
                              decoration: const InputDecoration(
                                labelText: 'Valeur *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || double.tryParse(v) == null
                                      ? 'Valeur invalide'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code promo *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Code requis' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minOrderController,
                              decoration: const InputDecoration(
                                labelText: 'Montant minimum',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxDiscountController,
                              decoration: const InputDecoration(
                                labelText: 'Réduction max',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usageLimitController,
                        decoration: const InputDecoration(
                          labelText: 'Limite d\'utilisation (optionnel)',
                          border: OutlineInputBorder(),
                          helperText: 'Laisser vide pour illimité',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de début'),
                              subtitle: Text(_formatDate(_startDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setState(() => _startDate = date);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              title: const Text('Date de fin'),
                              subtitle: Text(_formatDate(_endDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 730),
                                  ),
                                );
                                if (date != null) {
                                  setState(() => _endDate = date);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Activer la promotion'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(
                      widget.promotion == null ? 'Créer' : 'Modifier',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final promoService = context.read<PromotionService>();
    // Capturer les valeurs nécessaires avant le gap async
    final inverseSurfaceColor = Theme.of(context).colorScheme.inverseSurface;
    final value = double.tryParse(_valueController.text) ?? 0.0;
    final minOrder = double.tryParse(_minOrderController.text) ?? 0.0;
    final maxDiscount = _maxDiscountController.text.isNotEmpty
        ? double.tryParse(_maxDiscountController.text)
        : null;
    final usageLimit = _usageLimitController.text.isNotEmpty
        ? int.tryParse(_usageLimitController.text)
        : null;

    if (widget.promotion == null) {
      // Créer une nouvelle promotion
      final promotion = await promoService.createPromotion(
        name: _nameController.text,
        description: _descController.text,
        promoCode: _codeController.text.toUpperCase(),
        discountType: _type,
        discountValue: value,
        minOrderAmount: minOrder,
        maxDiscount: maxDiscount,
        usageLimit: usageLimit,
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
      );

      if (promotion != null && mounted && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Promotion créée avec succès'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      } else if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${promoService.error ?? "Erreur inconnue"}'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    } else {
      // Mettre à jour la promotion existante
      final success = await promoService.updatePromotion(widget.promotion!.id, {
        'name': _nameController.text,
        'description': _descController.text,
        'promo_code': _codeController.text.toUpperCase(),
        'discount_type': _type,
        'discount_value': value,
        'min_order_amount': minOrder,
        'max_discount': maxDiscount,
        'usage_limit': usageLimit,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'is_active': _isActive,
      });

      if (success && mounted && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Promotion mise à jour avec succès'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      } else if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${promoService.error ?? "Erreur inconnue"}'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    }
  }
}
