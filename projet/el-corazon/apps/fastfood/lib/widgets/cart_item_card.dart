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

  /// Rouvre le configurateur sur cette ligne. Nul quand la ligne n'est pas
  /// modifiable — une composition faite hors catalogue n'a pas de groupes
  /// d'options à rejouer, et le bouton mènerait à un écran vide.
  final VoidCallback? onEdit;

  const CartItemCard({
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    this.onEdit,
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
  static List<String> _describe(Map<String, dynamic> customization) {
    return [
      for (final entry in customization.entries)
        if (entry.key != 'note' || customization.length == 1)
          '${entry.key} : ${entry.value}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personnalisation = item.customization;
    final resume = (personnalisation != null && personnalisation.isNotEmpty)
        ? _describe(personnalisation)
        : const <String>[];

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
                  // Un groupe par ligne — « Taille : XL », « Suppléments :
                  // Fromage, Bacon ». Tout enfiler sur une seule ligne
                  // n'entrait pas dans les deux lignes visibles dès qu'un
                  // second groupe s'en mêlait, et le client ne relisait donc
                  // jamais que le premier de ses choix.
                  for (final ligne in resume)
                    Text(
                      ligne,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
                if (onEdit != null) ...[
                  const SizedBox(height: 2),
                  _Modifier(onTap: onEdit!, nom: item.name),
                ],
                // Le prix unitaire n'apparaît que lorsqu'il diffère du total :
                // sur une ligne à un exemplaire, il répéterait la même somme
                // deux fois. Dès qu'il y en a plusieurs, il est ce qui rend le
                // total vérifiable — « 6 500 × 2 » se relit, « 13 000 » se
                // subit.
                if (item.quantity > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${PriceFormatter.format(item.prixUnitaire)} l’unité',
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

/// Rouvre la personnalisation de la ligne.
///
/// Un lien plutôt qu'un bouton plein : la maquette pose ici une action
/// secondaire, et un second bouton d'emphase égale à côté du sélecteur de
/// quantité ferait de chaque ligne du panier une petite barre d'outils.
class _Modifier extends StatelessWidget {
  const _Modifier({required this.onTap, required this.nom});

  final VoidCallback onTap;
  final String nom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Modifier la personnalisation de $nom',
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignConstants.borderRadiusSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Modifier',
                style: AppTypography.labelLg(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
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
