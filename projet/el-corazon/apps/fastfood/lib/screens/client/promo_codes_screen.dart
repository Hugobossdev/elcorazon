import 'package:elcora_fast/services/cart_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Saisie d'un code promotionnel.
///
/// ## Pourquoi cet écran a été refait, la première fois
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
/// ## Ce que la maquette demande et que le serveur ne permet pas
///
/// La maquette `promo_codes` affiche, sous le champ de saisie, une liste de
/// coupons disponibles à toucher pour les appliquer. Elle n'est pas
/// implémentée, et ce n'est pas un oubli : **il n'existe aucune route publique
/// de promotion**. `/promotions/` appartient au back-office, et
/// `PromotionRepository` le documente noir sur blanc — « un client saisit un
/// code, il n'en liste pas ». Peupler cette liste supposerait d'inventer des
/// coupons, c'est-à-dire d'afficher des remises que la caisse refuserait.
///
/// La place qu'occupaient ces cartes est rendue à ce qui est vrai : l'état du
/// code en cours, et ce que la remise vaut réellement.
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

  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Soumet le code au serveur via le panier.
  ///
  /// Passer par `CartService.appliquerCodePromo` plutôt que d'appeler
  /// `DeliveryFeeService` directement n'est pas un détour : c'est la même
  /// requête, et le panier a besoin de connaître la remise retenue de toute
  /// façon. Les deux chemins avaient divergé — celui-ci normalisait le code en
  /// majuscules, l'autre non.
  Future<void> _appliquer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final cartService = context.read<CartService>();
    final erreur = await cartService.appliquerCodePromo(
      _codeController.text,
      addressId: widget.addressId,
    );

    if (!mounted) return;

    if (erreur != null) {
      setState(() {
        _enCours = false;
        _erreur = erreur;
      });
      return;
    }

    widget.onPromoCodeApplied(
      cartService.promoCode ?? _codeController.text.trim().toUpperCase(),
      cartService.discount,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Code promo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingL,
          DesignConstants.edgeMargin,
          DesignConstants.spacingL,
        ),
        children: [
          _enTete(theme),
          const SizedBox(height: DesignConstants.spacingXL),
          _champ(theme),
          const SizedBox(height: DesignConstants.spacingL),
          ActionButton(
            label: 'Appliquer le code',
            emphasis: ActionEmphasis.gradient,
            isLoading: _enCours,
            onPressed: _appliquer,
          ),
          const SizedBox(height: DesignConstants.spacingL),
          const _CodeEnCours(),
          const SizedBox(height: DesignConstants.spacingL),
          _mentionServeur(theme),
        ],
      ),
    );
  }

  Widget _enTete(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_activity_rounded,
            size: 34,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        Text(
          'Vous avez un code ?',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMd(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: DesignConstants.spacingS),
        Text(
          'Saisissez-le ci-dessous : la remise s’applique immédiatement à '
          'votre commande en cours.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _champ(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _enCours ? null : _appliquer(),
          onChanged: (_) {
            if (_erreur != null) setState(() => _erreur = null);
          },
          // La saisie est forcée en majuscules à la frappe, et non à
          // l'envoi : voir « bienvenue » se transformer en « BIENVENUE » au
          // moment de valider donne l'impression que le champ a été corrigé
          // par quelqu'un d'autre.
          inputFormatters: [UpperCaseTextFormatter()],
          style: AppTypography.headlineSm(color: theme.colorScheme.onSurface)
              .copyWith(letterSpacing: 3),
          decoration: InputDecoration(
            hintText: 'CODE',
            hintStyle:
                AppTypography.headlineSm(color: theme.colorScheme.outline)
                    .copyWith(letterSpacing: 3),
            contentPadding: const EdgeInsets.symmetric(
              vertical: DesignConstants.spacingM + 2,
            ),
            errorText: _erreur,
          ),
        ),
      ],
    );
  }

  Widget _mentionServeur(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: DesignConstants.spacingS),
        Expanded(
          child: Text(
            'La remise est calculée par nos serveurs au moment de la '
            'commande : le montant affiché est celui qui sera facturé.',
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rappel du code déjà appliqué, s'il y en a un, avec la remise obtenue.
///
/// Sans lui, revenir sur cet écran alors qu'un code est actif ne montrait
/// rien : on ressaisissait le même, ou un autre qui écrasait le premier sans
/// prévenir.
class _CodeEnCours extends StatelessWidget {
  const _CodeEnCours();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<CartService>(
      builder: (context, cartService, child) {
        final code = cartService.promoCode;
        if (code == null || code.isEmpty) return const SizedBox.shrink();

        return SectionCard(
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Remise de ${PriceFormatter.format(cartService.discount)}',
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: cartService.removePromoCode,
                child: const Text('Retirer'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Met en majuscules ce qui est tapé, sans déplacer le curseur.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
