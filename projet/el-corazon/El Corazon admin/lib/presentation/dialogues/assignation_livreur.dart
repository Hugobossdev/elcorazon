import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Le choix d'un livreur pour une commande, depuis la gestion avancée.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ces 520 lignes vivaient dans `advanced_order_management_screen.dart`, tenues
/// par un `StatefulBuilder` imbriqué à sept niveaux du `build` de l'écran. Un
/// dialogue est une vue à part entière : il a son propre état — le livreur
/// mis en évidence — et sa propre fin. Le sortir le rend nommable, donc
/// racontable.
///
/// Il existe un **second** dialogue d'assignation, dans
/// `active_deliveries_screen.dart`. Les deux n'ont pas été fondus, et ce n'est
/// pas un oubli : celui-ci marque la commande « récupérée » après l'avoir
/// assignée, l'autre non. Les unifier trancherait une question de métier qui
/// n'appartient pas au refactoring.
Future<void> afficherAssignationLivreur({
  required BuildContext context,
  required Order order,
  required OrderManagementService orderService,
  required DriverManagementService driverService,
}) async {
  final livreursDisponibles = driverService.getAvailableDrivers();

  if (livreursDisponibles.isEmpty) {
    unawaited(
      DialogHelper.showSafeDialog(
        context: context,
        builder: (context) => const _AucunLivreurDisponible(),
      ),
    );
    return;
  }

  await DialogHelper.showSafeDialog(
    context: context,
    builder: (context) => _ChoixDuLivreur(
      order: order,
      livreurs: livreursDisponibles,
      orderService: orderService,
    ),
  );
}

/// L'en-tête commun aux deux dialogues : une icône, un titre, une croix.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.icone, required this.couleur, required this.titre});

  final IconData icone;
  final Color couleur;
  final String titre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icone, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titre,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AucunLivreurDisponible extends StatelessWidget {
  const _AucunLivreurDisponible();

  @override
  Widget build(BuildContext context) {
    final largeur = (MediaQuery.of(context).size.width * 0.9).clamp(400.0, 500.0);

    return Dialog(
      child: SizedBox(
        width: largeur,
        height: 250,
        child: Column(
          children: [
            _EnTete(
              icone: Icons.warning,
              couleur: Theme.of(context).colorScheme.tertiary,
              titre: 'Aucun livreur disponible',
            ),
            const Divider(height: 1),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Il n'y a actuellement aucun livreur disponible pour cette livraison.\n\n"
                  'Vous pouvez attendre '
                  "qu'un livreur devienne disponible ou assigner un livreur "
                  'manuellement depuis la liste des livreurs.',
                  style: TextStyle(fontSize: 14),
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

class _ChoixDuLivreur extends StatefulWidget {
  const _ChoixDuLivreur({
    required this.order,
    required this.livreurs,
    required this.orderService,
  });

  final Order order;
  final List<eccore.CourierProfile> livreurs;
  final OrderManagementService orderService;

  @override
  State<_ChoixDuLivreur> createState() => _ChoixDuLivreurState();
}

class _ChoixDuLivreurState extends State<_ChoixDuLivreur> {
  eccore.CourierProfile? _choisi;

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;

    return Dialog(
      child: SizedBox(
        width: (ecran.width * 0.9).clamp(500.0, 800.0),
        height: (ecran.height * 0.7).clamp(500.0, 800.0),
        child: Column(
          children: [
            _EnTete(
              icone: Icons.local_shipping,
              couleur: Theme.of(context).colorScheme.primary,
              titre: 'Assigner un livreur',
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RappelCommande(order: widget.order),
                    const SizedBox(height: 16),
                    Text(
                      'Livreurs disponibles (${widget.livreurs.length}):',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: widget.livreurs.length,
                        itemBuilder: (context, index) {
                          final livreur = widget.livreurs[index];

                          return _CarteLivreur(
                            livreur: livreur,
                            estChoisi: _choisi?.id == livreur.id,
                            onTap: () => setState(() => _choisi = livreur),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _PiedDeDialogue(
              onAssigner: _choisi == null ? null : _assigner,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assigner() async {
    final livreur = _choisi!;
    final commandeId = widget.order.id;

    Navigator.of(context).pop();

    // Vérifier que le livreur a bien une identité avant d'assigner.
    if (livreur.id.isEmpty) {
      if (mounted) {
        _bandeau(
          context,
          icone: Icons.warning,
          teinte: (sem) => sem.warning,
          message: "Ce livreur n'a pas d'utilisateur correspondant dans la "
              "table users. Veuillez créer un utilisateur avec role='delivery' "
              'pour ce livreur.',
          duree: const Duration(seconds: 5),
        );
      }
      return;
    }

    final assigne = await widget.orderService.assignDriver(
      commandeId,
      livreur.id,
    );

    if (!assigne) {
      if (mounted) {
        _bandeau(
          context,
          icone: Icons.error,
          teinte: (sem) => sem.danger,
          message: "Erreur lors de l'assignation du livreur",
        );
      }
      return;
    }

    // Marquer la commande comme récupérée après assignation.
    await widget.orderService.markOrderPickedUp(commandeId);
    await widget.orderService.refresh();

    if (mounted) {
      _bandeau(
        context,
        icone: Icons.check_circle,
        teinte: (sem) => sem.success,
        message: 'Livreur ${livreur.fullName} assigné avec succès',
      );
    }
  }
}

/// Les trois issues de l'assignation s'annonçaient par le même bandeau écrit
/// trois fois ; seuls l'icône, sa teinte et le texte changent.
void _bandeau(
  BuildContext context, {
  required IconData icone,
  required Color Function(AdminSemanticColors sem) teinte,
  required String message,
  Duration duree = const Duration(seconds: 3),
}) {
  final scheme = Theme.of(context).colorScheme;
  final sem = AdminColorTokens.semantic(scheme);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scheme.inverseSurface,
      duration: duree,
      content: Row(
        children: [
          Icon(icone, color: teinte(sem)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onInverseSurface),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RappelCommande extends StatelessWidget {
  const _RappelCommande({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondaire = TextStyle(
      fontSize: 12,
      color: scheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commande #${order.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text('Total: ${PriceFormatter.format(order.total)}', style: secondaire),
          const SizedBox(height: 4),
          Text(
            'Adresse: ${order.deliveryAddress}',
            style: secondaire,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CarteLivreur extends StatelessWidget {
  const _CarteLivreur({
    required this.livreur,
    required this.estChoisi,
    required this.onTap,
  });

  final eccore.CourierProfile livreur;
  final bool estChoisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondaire = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: estChoisi
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      elevation: estChoisi ? 4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: livreur.statut.couleur,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              livreur.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: estChoisi
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                          ),
                          if (estChoisi)
                            Icon(
                              Icons.check_circle,
                              color: scheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: scheme.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            livreur.ratingAverage.toStringAsFixed(1),
                            style: secondaire,
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.delivery_dining,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${livreur.deliveriesCompleted} livraisons',
                            style: secondaire,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Véhicule: ${livreur.vehicleType}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiedDeDialogue extends StatelessWidget {
  const _PiedDeDialogue({required this.onAssigner});

  /// `null` tant qu'aucun livreur n'est choisi : le bouton reste inerte.
  final VoidCallback? onAssigner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton.icon(
              onPressed: onAssigner,
              icon: const Icon(Icons.local_shipping),
              label: const Text('Assigner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
