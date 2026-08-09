import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/services/delivery_fee_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';

/// Saisie d'un code promotionnel.
///
/// Pourquoi cet écran a été refait
/// -------------------------------
///
/// Il interrogeait `PromoCodeService`, qui ne connaissait que le **stockage
/// local** de l'appareil. Cette liste n'était alimentée que par
/// `createPromoCode`, que rien n'appelait : elle était donc toujours vide, et
/// tout code saisi ressortait « Code promo non trouvé ». Aucun client ne
/// pouvait appliquer une remise.
///
/// C'est le serveur qui évalue un code — `POST /orders/preview/` relit le
/// panier, applique le barème de zone et le code, et rend le devis. La remise
/// n'est plus calculée ici : une remise calculée côté client est une promesse
/// que la facture peut démentir.
///
/// La barre de recherche et la liste des codes disponibles ont disparu avec le
/// service : il n'existe **aucun** point d'entrée client pour lister les
/// promotions — `/promotions/` est réservé au back-office. Les deux ne
/// pouvaient rien afficher.
class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({
    required this.onPromoCodeApplied,
    this.addressId,
    super.key,
  });

  /// Rend le code retenu par le serveur et la remise qu'il accorde.
  final void Function(String code, double remise) onPromoCodeApplied;

  /// L'adresse choisie, s'il y en a une : le devis en dépend, puisque les
  /// frais de livraison entrent dans le total.
  final String? addressId;

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final _codeController = TextEditingController();
  final DeliveryFeeService _devis = DeliveryFeeService();

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _appliquer() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _erreur = 'Entrez un code promo');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final quote = await _devis.quoteOrder(
        addressId: widget.addressId,
        promoCode: code,
      );

      if (!mounted) return;

      // Le serveur rend un code vide quand il l'a refusé. Le distinguer d'une
      // remise nulle importe : un code périmé doit se voir, pas se taire.
      if (!quote.hasPromotion) {
        setState(() {
          _enCours = false;
          _erreur = 'Code promo refusé ou expiré';
        });
        return;
      }

      widget.onPromoCodeApplied(
        quote.promotionCode,
        quote.discount.toMajorUnits(),
      );
      Navigator.of(context).pop();
    } on eccore.ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = e.detail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code promo'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _codeController,
              label: 'Code promo',
              hint: 'Entrez votre code promo',
              prefixIcon: Icons.local_offer,
              onChanged: (_) {
                if (_erreur != null) setState(() => _erreur = null);
              },
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erreur!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _enCours ? null : _appliquer,
              child: _enCours
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Appliquer'),
            ),
            const SizedBox(height: 24),
            Text(
              'La remise est calculée par nos serveurs au moment de la '
              'commande : le montant affiché ici est celui qui sera facturé.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
