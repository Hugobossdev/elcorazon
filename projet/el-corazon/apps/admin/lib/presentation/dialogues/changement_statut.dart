import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';

/// La confirmation demandée avant de faire avancer une commande.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le dialogue et l'appel au service tenaient dans une même méthode de
/// `advanced_order_management_screen.dart`, longue de 195 lignes. Le statut
/// courant y était passé en paramètre alors que les trois appels y mettaient
/// tous `order.statut` : il est lu sur la commande.
Future<void> confirmerChangementStatut({
  required BuildContext context,
  required eccore.Order order,
  required StatutCommande nouveauStatut,
  required OrderManagementService orderService,
  String? message,
}) async {
  // Capturer la couleur avant l'attente : le contexte peut ne plus valoir.
  final fondDuBandeau = Theme.of(context).colorScheme.inverseSurface;

  final confirme = await DialogHelper.showSafeDialog<bool>(
    context: context,
    builder: (context) => _ConfirmationChangementStatut(
      order: order,
      nouveauStatut: nouveauStatut,
      message: message,
    ),
  );

  if (confirme != true) return;

  final applique = await orderService.updateOrderStatus(order.id, nouveauStatut);

  // Sur le Web, certains rebuilds se perdent si l'écran n'écoute pas la bonne
  // instance : le rechargement garantit que la commande change d'onglet.
  if (applique) {
    await orderService.refresh();
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applique
              ? 'Statut changé: ${nouveauStatut.libelle}'
              : 'Erreur lors du changement de statut',
        ),
        backgroundColor: fondDuBandeau,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ConfirmationChangementStatut extends StatelessWidget {
  const _ConfirmationChangementStatut({
    required this.order,
    required this.nouveauStatut,
    required this.message,
  });

  final eccore.Order order;
  final StatutCommande nouveauStatut;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final largeur =
        (MediaQuery.of(context).size.width * 0.9).clamp(400.0, 600.0);
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: SizedBox(
        width: largeur,
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.tertiary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirmer le changement',
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
                      onPressed: () => Navigator.of(context).pop(false),
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
                    Text(
                      message ??
                          'Êtes-vous sûr de vouloir changer le statut de '
                              'cette commande ?',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _RecapitulatifDuPassage(
                      order: order,
                      nouveauStatut: nouveauStatut,
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
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    child: const Text('Confirmer'),
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

/// D'où part la commande, où elle va.
class _RecapitulatifDuPassage extends StatelessWidget {
  const _RecapitulatifDuPassage({
    required this.order,
    required this.nouveauStatut,
  });

  final eccore.Order order;
  final StatutCommande nouveauStatut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final succes = AdminColorTokens.semantic(scheme).success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commande #${order.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Statut actuel: ${order.statut.libelle}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: succes),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nouveau statut: ${nouveauStatut.libelle}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: succes,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
