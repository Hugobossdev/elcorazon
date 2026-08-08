import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';
import 'package:admin/presentation/apparence_statut.dart';
import 'package:admin/presentation/cartes/commande_deployee.dart';
import 'package:admin/widgets/order_timeline_widget.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';

/// La fiche d'une commande, ouverte depuis la liste de
/// `order_management_screen.dart`.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// 324 lignes tenaient dans une méthode de l'écran. La fiche ne lit rien de
/// son état : elle affiche une commande et se ferme.
void afficherFicheCommande(BuildContext context, Order order) {
  DialogHelper.showSafeDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Commande #${order.id.substring(0, 8).toUpperCase()}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations générales
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              iconeDeStatut(order.status),
                              color: couleurDeStatutFixe(order.status),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Statut: ${order.status.displayName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        LigneDeDetail(
                          'Total',
                          PriceFormatter.format(order.total),
                          Icons.monetization_on,
                        ),
                        LigneDeDetail(
                          'Sous-total',
                          PriceFormatter.format(order.subtotal),
                          Icons.receipt,
                        ),
                        LigneDeDetail(
                          'Frais de livraison',
                          PriceFormatter.format(order.deliveryFee),
                          Icons.local_shipping,
                        ),
                        if (order.discount > 0)
                          LigneDeDetail(
                            'Réduction',
                            '-${PriceFormatter.format(order.discount)}',
                            Icons.discount,
                          ),
                        LigneDeDetail(
                          'Articles',
                          '${order.items.length}',
                          Icons.restaurant,
                        ),
                        LigneDeDetail(
                          'Paiement',
                          order.paymentMethod.displayName,
                          Icons.payment,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Timeline
                OrderTimelineWidget(order: order),
                const SizedBox(height: 16),
                // Articles
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Articles',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...order.items.map((item) {
                          final customizations =
                              item.getFormattedCustomizations();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6A00),
                                      Color(0xFFFF8A50),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${PriceFormatter.format(item.unitPrice)} × ${item.quantity} = ${PriceFormatter.format(item.totalPrice)}',
                                  ),
                                  if (customizations.isNotEmpty ||
                                      (item.notes != null &&
                                          item.notes!.isNotEmpty))
                                    const SizedBox(height: 4),
                                  if (customizations.isNotEmpty)
                                    Text(
                                      '${customizations.length} personnalisation(s)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                PriceFormatter.format(item.totalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFFFF6A00),
                                ),
                              ),
                              children: [
                                if (customizations.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8,),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.tune,
                                              size: 16,
                                              color: Colors.grey[700],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Personnalisations',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ...customizations.map((custom) =>
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4, left: 22,),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 4,
                                                    height: 4,
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 6, right: 8,),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          Color(0xFFFF6A00),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      custom,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Colors.grey[800],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),),
                                      ],
                                    ),
                                  ),
                                ],
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8,),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.note,
                                            size: 16,
                                            color: Colors.blue[700],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.notes!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[800],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Informations de livraison
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Livraison',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LigneDeDetail(
                          'Adresse',
                          order.deliveryAddress,
                          Icons.location_on,
                        ),
                        if (order.deliveryNotes != null)
                          LigneDeDetail(
                            'Notes',
                            order.deliveryNotes!,
                            Icons.note,
                          ),
                        if (order.deliveryPersonId != null)
                          const LigneDeDetail(
                            'Livreur',
                            'Assigné',
                            Icons.delivery_dining,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}

