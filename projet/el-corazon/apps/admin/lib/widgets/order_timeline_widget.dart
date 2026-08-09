import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/chronologie_commande.dart';
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:intl/intl.dart';

class OrderTimelineWidget extends StatelessWidget {
  final eccore.Order order;

  const OrderTimelineWidget({
    required this.order, super.key,
  });

  @override
  Widget build(BuildContext context) {
    final timelineEvents = _buildTimelineEvents();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history,
                    color: Theme.of(context).colorScheme.primary,),
                const SizedBox(width: 8),
                Text(
                  'Timeline de la commande',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...timelineEvents.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final isLast = index == timelineEvents.length - 1;

              return _buildTimelineItem(
                context,
                event: event,
                isLast: isLast,
                isActive: index == 0 ||
                    (index == 1 && order.statut == event['status']),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Les transitions réellement enregistrées, la plus récente d'abord.
  ///
  /// Ce widget fabriquait son historique : il ajoutait 5, 15, 20, 25 puis 30
  /// minutes à l'heure de commande, sur la foi du statut courant. La branche
  /// « vraies données » qu'il portait lisait `statusUpdates`, que rien ne
  /// remplissait — elle ne s'exécutait donc jamais.
  ///
  /// Il lit désormais `chronologieDe`, qui s'appuie sur le journal du serveur.
  /// Une étape dont on ignore l'heure n'apparaît pas : mieux vaut un historique
  /// court qu'un historique inventé.
  List<Map<String, dynamic>> _buildTimelineEvents() {
    final events = [
      for (final etape in chronologieDe(order))
        if (etape.franchie && etape.quand != null)
          {
            'status': etape.statut,
            'timestamp': etape.quand!,
            'note': etape.libelle,
          },
    ];

    final annulation = annulationDe(order);
    if (annulation != null && annulation.quand != null) {
      events.add({
        'status': StatutCommande.annulee,
        'timestamp': annulation.quand!,
        'note': annulation.motif.isEmpty
            ? StatutCommande.annulee.libelle
            : annulation.motif,
      });
    }

    events.sort(
      (a, b) => (b['timestamp'] as DateTime)
          .compareTo(a['timestamp'] as DateTime),
    );

    return events;
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required Map<String, dynamic> event,
    required bool isLast,
    required bool isActive,
  }) {
    final status = event['status'] as StatutCommande;
    final timestamp = event['timestamp'] as DateTime;
    final note = event['note'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne verticale et icône
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                  border: Border.all(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  size: 16,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Colors.grey[600],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note ?? status.libelle,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (isActive && status.estEnCours)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'En cours',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(StatutCommande status) {
    switch (status) {
      case StatutCommande.enAttente:
        return Icons.pending;
      case StatutCommande.confirmee:
        return Icons.check_circle_outline;
      case StatutCommande.enPreparation:
        return Icons.restaurant;
      case StatutCommande.prete:
        return Icons.check_circle_outline;
      case StatutCommande.recuperee:
        return Icons.shopping_bag;
      case StatutCommande.enRoute:
        return Icons.directions_bike;
      case StatutCommande.livree:
        return Icons.check_circle;
      case StatutCommande.annulee:
        return Icons.cancel;
    }
  }
}

