import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_service.dart';
import '../../services/promo_code_service.dart';
import '../../services/error_handler_service.dart';
import '../../services/performance_service.dart';
import '../../models/promo_code.dart';
import 'driver_profile_screen.dart';
import 'settings_screen.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Provider.of<PromoCodeService>(context, listen: false).initialize();
    } catch (e) {
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur initialisation codes promo', details: e);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes promo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCodeInputSection(),
          const Divider(),
          Expanded(
            child: _buildPromoCodesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appliquer un code promo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code promo',
                    hintText: 'Entrez votre code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_offer),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _applyPromoCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Appliquer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodesList() {
    return Consumer<PromoCodeService>(
      builder: (context, promoCodeService, child) {
        if (!promoCodeService.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (promoCodeService.usedPromoCodes.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: promoCodeService.usedPromoCodes.length,
          itemBuilder: (context, index) {
            final usage = promoCodeService.usedPromoCodes[index];
            return _buildPromoCodeCard(usage);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun code promo utilisé',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appliquez un code promo pour voir vos économies',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeCard(PromoCodeUsage usage) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getPromoTypeColor(
                            usage.promoCode?.type ?? PromoCodeType.percentage)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      usage.promoCode?.type.emoji ?? '🎁',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usage.promoCode?.code ?? 'Code inconnu',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usage.promoCode?.description ??
                            'Description non disponible',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(usage.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    usage.status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Économie réalisée',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${usage.discountAmount.toStringAsFixed(2)} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Utilisé le',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDate(usage.usedAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (usage.promoCode?.type == PromoCodeType.percentage) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (usage.promoCode?.usageCount ?? 0) /
                    (usage.promoCode?.usageLimit ?? 1),
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getPromoTypeColor(
                      usage.promoCode?.type ?? PromoCodeType.percentage),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${usage.promoCode?.usageCount ?? 0}/${usage.promoCode?.usageLimit ?? 1} utilisations',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un code promo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Provider.of<PerformanceService>(context, listen: false)
          .startTimer('apply_promo_code');

      final promoCodeService =
          Provider.of<PromoCodeService>(context, listen: false);

      // Utiliser l'ID de l'utilisateur connecté
      final appService = Provider.of<AppService>(context, listen: false);
      final userId = appService.currentUser?.id;
      
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Simuler un montant de commande pour le test si pas de commande active
      // Idéalement, on devrait passer la commande en cours ou le panier
      const testOrderAmount = 5000.0;

      final result = await promoCodeService.validateAndApplyPromoCode(
        code: _codeController.text.trim(),
        orderAmount: testOrderAmount,
        userId: userId,
      );

      Provider.of<PerformanceService>(context, listen: false)
          .stopTimer('apply_promo_code');

      if (result.isValid) {
        if (mounted) {
          _codeController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Code appliqué! Économie: ${result.discountAmount.toStringAsFixed(2)} FCFA',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Code promo invalide'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Provider.of<ErrorHandlerService>(context, listen: false)
          .logError('Erreur application code promo', details: e);
      Provider.of<ErrorHandlerService>(context, listen: false)
          .showErrorSnackBar(
              context, 'Erreur lors de l\'application du code promo');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getPromoTypeColor(PromoCodeType type) {
    switch (type) {
      case PromoCodeType.percentage:
        return Colors.blue;
      case PromoCodeType.fixedAmount:
        return Colors.green;
      case PromoCodeType.freeDelivery:
        return Colors.orange;
      case PromoCodeType.buyOneGetOne:
        return Colors.purple;
    }
  }

  Color _getStatusColor(PromoCodeStatus status) {
    switch (status) {
      case PromoCodeStatus.active:
        return Colors.green;
      case PromoCodeStatus.inactive:
        return Colors.grey;
      case PromoCodeStatus.expired:
        return Colors.red;
      case PromoCodeStatus.usedUp:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
