import 'package:elcora_fast/models/cart_item.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/food_image.dart';
import 'package:elcora_fast/widgets/design/quantity_stepper.dart';
import 'package:flutter/material.dart';

/// Une ligne du panier.
///
/// ## Disposition
///
/// Photo carrée à gauche, puis, à droite, une colonne en trois temps : le nom
/// et la corbeille, la personnalisation, enfin le total de la ligne face au
/// sélecteur de quantité. C'est celle de la maquette, à une chose près — la
/// corbeille, que la maquette n'a pas.
///
/// ## Pourquoi la corbeille existe malgré tout
///
/// Dans la maquette, on suppose que le moins ramène à zéro et retire la ligne.
/// Ici il s'arrête à un, et c'est délibéré : le retrait passe par une
/// confirmation (`cart_screen.dart`), parce qu'un panier se compose parfois
/// longuement et qu'un appui de trop ne doit pas en effacer une ligne en
/// silence. Il faut donc une commande distincte pour retirer, et elle est
/// posée en haut à droite plutôt qu'à côté du moins : accolée, on la
/// toucherait en voulant décrémenter.
///
/// ## Le total de ligne, et pourquoi il ne s'élide jamais
///
/// Un montant tronqué — « 4 50… » — se lit comme un autre montant, pas comme
/// un montant incomplet. Sur un écran de 320 px à l'échelle de police 1,3, le
/// total et le sélecteur ne tiennent plus côte à côte ; le montant est alors
/// **réduit** ([FittedBox]) plutôt que coupé. C'est la seule concession que
/// cette carte fait à l'échelle de police, et elle ne coûte rien à la
/// lisibilité : le montant reste entier.
class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const CartItemCard({
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    super.key,
  });

  /// Côté de la photo. Fixe : c'est ce qui aligne les lignes entre elles, et
  /// la maquette montre bien une colonne de photos de même largeur.
  static const double _cotePhoto = 76;

  /// Résume la personnalisation d'une ligne.
  ///
  /// La clé `note` est ce que la ligne transmet au serveur en texte libre
  /// (`CartItem.remoteNotes`) : sur un gâteau sur mesure elle reprend, pour la
  /// pâtisserie, ce que les autres clés disent déjà au client — mode, créneau,
  /// message, contact. L'afficher deux fois repoussait l'essentiel au-delà des
  /// deux lignes visibles. Elle n'est donc montrée que lorsqu'elle est seule à
  /// porter l'information.
  static String _describe(Map<String, dynamic> customization) {
    final entries = customization.entries.where(
      (entry) => entry.key != 'note' || customization.length == 1,
    );
    return entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personnalisation = item.customization;
    final resume = (personnalisation != null && personnalisation.isNotEmpty)
        ? _describe(personnalisation)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: DesignConstants.borderRadiusLarge,
        boxShadow: DesignConstants.shadowLow,
      ),
      padding: const EdgeInsets.all(DesignConstants.spacingS + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DesignConstants.borderRadiusMedium,
            child: SizedBox(
              width: _cotePhoto,
              height: _cotePhoto,
              child: FoodImage(url: item.imageUrl, iconSize: 28),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _Corbeille(onTap: onRemove, nom: item.name),
                  ],
                ),
                if (resume.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    resume,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: DesignConstants.spacingS),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          PriceFormatter.format(item.totalPrice),
                          maxLines: 1,
                          style: AppTypography.priceDisplay(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignConstants.spacingS),
                    QuantityStepper(
                      quantity: item.quantity,
                      compact: true,
                      onDecrement: () => onQuantityChanged(item.quantity - 1),
                      onIncrement: () => onQuantityChanged(item.quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Retrait de la ligne. Discrète au repos — c'est une action destructrice, pas
/// une action courante — mais dans les couleurs de l'erreur pour que sa nature
/// soit claire au premier regard.
class _Corbeille extends StatelessWidget {
  const _Corbeille({required this.onTap, required this.nom});

  final VoidCallback onTap;
  final String nom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Retirer $nom du panier',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: theme.colorScheme.error.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
