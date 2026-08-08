import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';

/// Le détail d'une commande, ouvert depuis la liste du back-office.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// 365 lignes de widgets imbriqués tenaient dans une seule méthode de
/// `advanced_order_management_screen.dart`. Le dialogue ne lit rien de l'état
/// de l'écran : il affiche une commande et se ferme. C'est donc une vue à
/// part, et elle se nomme.
void afficherDetailsCommande(BuildContext context, Order order) {
  DialogHelper.showSafeDialog(
    context: context,
    builder: (context) => _DetailsCommande(order: order),
  );
}

class _DetailsCommande extends StatelessWidget {
  const _DetailsCommande({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: SizedBox(
        width: (ecran.width * 0.9).clamp(500.0, 900.0),
        height: (ecran.height * 0.85).clamp(500.0, 900.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commande #${order.id.substring(0, 8).toUpperCase()}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Informations(order: order),
                    const SizedBox(height: 16),
                    if (order.items.isNotEmpty)
                      _ArticlesCommandes(items: order.items)
                    else
                      const _AucunArticle(),
                    const SizedBox(height: 16),
                    _AdresseLivraison(adresse: order.deliveryAddress),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${ancienneteCommande(order.orderTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une étiquette de largeur fixe, puis sa valeur.
class LigneDeDetail extends StatelessWidget {
  const LigneDeDetail({required this.label, required this.valeur, super.key});

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valeur,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _Informations extends StatelessWidget {
  const _Informations({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nombre = order.items.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Informations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LigneDeDetail(label: 'Statut', valeur: order.status.displayName),
          const SizedBox(height: 4),
          LigneDeDetail(
            label: 'Total',
            valeur: PriceFormatter.format(order.total),
          ),
          const SizedBox(height: 4),
          LigneDeDetail(
            label: 'Articles',
            valeur: '$nombre article${nombre > 1 ? 's' : ''}',
          ),
          const SizedBox(height: 4),
          LigneDeDetail(
            label: 'Méthode de paiement',
            valeur: order.paymentMethod.toString().split('.').last,
          ),
        ],
      ),
    );
  }
}

class _ArticlesCommandes extends StatelessWidget {
  const _ArticlesCommandes({required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Articles commandés:',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (final item in items) _LigneArticle(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _LigneArticle extends StatelessWidget {
  const _LigneArticle({required this.item});

  final OrderItem item;

  /// Le nom d'un article a deux sources et peut n'en avoir aucune.
  String get _nom {
    if (item.menuItemName.isNotEmpty) return item.menuItemName;
    if (item.name.isNotEmpty) return item.name;
    return 'Article';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final personnalisations = item.getFormattedCustomizations();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VignetteArticle(image: item.menuItemImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nom,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity}x ${PriceFormatter.format(item.unitPrice)} '
                  '= ${PriceFormatter.format(item.totalPrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (item.categoryId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Catégorie: ${item.categoryId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (personnalisations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final choix in personnalisations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $choix',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${item.notes}',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onTertiaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            PriceFormatter.format(item.totalPrice),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VignetteArticle extends StatelessWidget {
  const _VignetteArticle({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final substitut = Icon(
      Icons.fastfood,
      size: 20,
      color: scheme.onSurfaceVariant,
    );

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: image.isEmpty
          ? substitut
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => substitut,
              ),
            ),
    );
  }
}

class _AucunArticle extends StatelessWidget {
  const _AucunArticle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aucun article trouvé dans cette commande',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onTertiaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdresseLivraison extends StatelessWidget {
  const _AdresseLivraison({required this.adresse});

  final String adresse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Adresse de livraison',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            adresse,
            style: TextStyle(fontSize: 12, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
