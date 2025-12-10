import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/promo_code_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/models/promo_code.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';

class PromoCodesScreen extends StatefulWidget {
  final double orderAmount;
  final Function(PromoCode, double) onPromoCodeApplied;

  const PromoCodesScreen({
    required this.orderAmount, required this.onPromoCodeApplied, super.key,
  });

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final _codeController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Codes Promo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Consumer<PromoCodeService>(
        builder: (context, promoCodeService, child) {
          final promoCodes = _searchQuery.isEmpty
              ? promoCodeService.getActivePromoCodes()
              : promoCodeService.searchPromoCodes(_searchQuery);

          return Column(
            children: [
              // Champ de saisie de code promo
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _codeController,
                        label: 'Code promo',
                        hint: 'Entrez votre code promo',
                        prefixIcon: Icons.local_offer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _applyPromoCode,
                      child: const Text('Appliquer'),
                    ),
                  ],
                ),
              ),

              // Barre de recherche
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher des codes promo...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Code promo actuel
              if (promoCodeService.hasActivePromoCode)
                _buildCurrentPromoCode(promoCodeService.currentPromoCode!),

              // Liste des codes promo disponibles
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: promoCodes.length,
                  itemBuilder: (context, index) {
                    final promoCode = promoCodes[index];
                    return _buildPromoCodeCard(promoCode);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPromoCode(PromoCode promoCode) {
    final discountAmount = promoCode.calculateDiscount(widget.orderAmount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promoCode.code,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
                Text(
                  promoCode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (discountAmount > 0)
                  Text(
                    'Économisez ${discountAmount.toInt()} FCFA',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Provider.of<PromoCodeService>(context, listen: false)
                  .removeCurrentPromoCode();
            },
            icon: const Icon(Icons.close),
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeCard(PromoCode promoCode) {
    final discountAmount = promoCode.calculateDiscount(widget.orderAmount);
    final isValid =
        discountAmount > 0 || promoCode.type == PromoCodeType.freeDelivery;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green : Colors.grey[300]!,
          width: isValid ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: promoCode.type.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              promoCode.type.symbol,
              style: TextStyle(
                color: promoCode.type.color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                promoCode.code,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (promoCode.isForNewUsersOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Nouveau',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(promoCode.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: promoCode.type.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    promoCode.type.displayName,
                    style: TextStyle(
                      color: promoCode.type.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (promoCode.minimumOrderAmount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Min: ${promoCode.minimumOrderAmount!.toInt()} FCFA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ],
            ),
            if (isValid && discountAmount > 0)
              Text(
                'Économisez ${discountAmount.toInt()} FCFA',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
              ),
          ],
        ),
        trailing: isValid
            ? ElevatedButton(
                onPressed: () => _applySpecificPromoCode(promoCode),
                child: const Text('Appliquer'),
              )
            : Text(
                'Non applicable',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('Veuillez entrer un code promo');
      return;
    }

    await _applySpecificPromoCodeByCode(code);
  }

  Future<void> _applySpecificPromoCode(PromoCode promoCode) async {
    await _applySpecificPromoCodeByCode(promoCode.code);
  }

  Future<void> _applySpecificPromoCodeByCode(String code) async {
    try {
      // Récupérer les services depuis Provider
      final promoCodeService = Provider.of<PromoCodeService>(context, listen: false);
      final appService = Provider.of<AppService>(context, listen: false);
      
      // S'assurer que PromoCodeService est initialisé
      if (!promoCodeService.isInitialized) {
        await promoCodeService.initialize();
      }
      
      final currentUser = appService.currentUser;
      
      if (currentUser == null) {
        _showError('Vous devez être connecté pour utiliser un code promo');
        return;
      }
      
      // Déterminer si l'utilisateur est nouveau (première commande)
      final isNewUser = appService.orders.isEmpty;
      
      final result = await promoCodeService.validateAndApplyPromoCode(
        code: code,
        orderAmount: widget.orderAmount,
        userId: currentUser.id,
        isNewUser: isNewUser,
      );

      if (result.isValid && result.promoCode != null) {
        widget.onPromoCodeApplied(result.promoCode!, result.discountAmount);
        _showSuccess('Code promo appliqué avec succès !');
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showError(result.errorMessage ?? 'Code promo non valide');
      }
    } catch (e) {
      _showError('Erreur lors de l\'application du code promo');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Extension pour obtenir la couleur du type de code promo
extension PromoCodeTypeExtension on PromoCodeType {
  Color get color {
    switch (this) {
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
}
