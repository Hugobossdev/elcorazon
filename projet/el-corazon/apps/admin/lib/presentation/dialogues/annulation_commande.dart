import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';

/// L'annulation d'une commande par l'exploitation.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// `OrderManagementService.cancelOrder` existait — permission `orders.cancel`,
/// motif obligatoire, route dédiée côté serveur — et **aucun écran ne
/// l'appelait**. La supervision proposait Confirmer, Préparer, Prêt et
/// Assigner ; rien pour la rupture découverte en cuisine, l'adresse
/// introuvable, le client injoignable. L'opérateur n'avait pas d'autre issue
/// que de laisser la commande en l'état.
///
/// Le motif n'est pas décoratif et n'a pas de valeur par défaut ici. Le serveur
/// le refuse à vide, et pour une bonne raison : on annule la commande d'un
/// tiers, qui sera remboursé et rappellera pour savoir pourquoi. Un motif écrit
/// dans le code — « Annulée depuis la supervision » — répond à cette question
/// par une tautologie.
Future<bool> annulerCommande({
  required BuildContext context,
  required eccore.Order order,
  required OrderManagementService orderService,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final danger = AdminColorTokens.semantic(scheme).danger;

  final motif = await DialogHelper.showSafeDialog<String>(
    context: context,
    builder: (context) => _AnnulationCommande(order: order),
  );

  if (motif == null) return false;

  // Le motif du refus vient du serveur : « permission « orders.cancel », ou
  // commande trop avancée » était une **devinette** de l'écran, là où le
  // serveur avait écrit laquelle des deux.
  String? motifDuRefus;
  try {
    await orderService.cancelOrder(order.id, motif);
  } catch (erreur) {
    motifDuRefus = messageErreur(erreur);
  }

  if (!context.mounted) return motifDuRefus == null;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        motifDuRefus ?? 'Commande ${order.reference} annulée.',
      ),
      backgroundColor: motifDuRefus == null ? scheme.inverseSurface : danger,
      duration: Duration(seconds: motifDuRefus == null ? 3 : 5),
    ),
  );

  return motifDuRefus == null;
}

/// Ce que l'annulation implique côté argent, dit à l'opérateur.
///
/// ## Ce que ce message affirmait
///
/// Il se lisait sur le **moyen** de paiement : « espèces » valait « rien n'a
/// été encaissé », tout le reste valait « réglée d'avance ». Les deux moitiés
/// étaient fausses, chacune dans un sens coûteux :
///
/// * une commande en ligne dont le règlement a échoué — prestataire qui
///   refuse, client qui abandonne, puis confirmation à la main — s'annonçait
///   « réglée d'avance », et l'exploitation partait rembourser un encaissement
///   qui n'avait jamais eu lieu ;
/// * une commande payable à la livraison finalement réglée par un autre canal
///   s'annonçait « rien à rembourser », et le client ne revoyait pas son
///   argent.
///
/// `amount_paid` est écrit par le seul module qui connaît l'état réel du
/// règlement. Le moyen de paiement reste ce qu'il est : une intention.
String messageDeRemboursement(eccore.Order order) {
  final encaisse = order.amountPaid;

  if (encaisse == null || encaisse.amountMinor <= 0) {
    return 'Rien n’a encore été encaissé sur cette commande '
        '(${order.moyenPaiement.libelle}) : il n’y a rien à rembourser.';
  }

  if (order.estIntegralementReglee) {
    return 'Cette commande a été réglée d’avance (${encaisse.format()}). '
        'L’annulation ne rembourse pas : le remboursement se fait depuis la '
        'fiche de la commande, montant par montant.';
  }

  return 'Cette commande a été réglée en partie : ${encaisse.format()} '
      'encaissés sur ${order.total.format()}. L’annulation ne rembourse pas — '
      'le remboursement se fait depuis la fiche de la commande, et il porte '
      'sur ce qui a été encaissé, pas sur le total.';
}

class _AnnulationCommande extends StatefulWidget {
  const _AnnulationCommande({required this.order});

  final eccore.Order order;

  @override
  State<_AnnulationCommande> createState() => _AnnulationCommandeState();
}

class _AnnulationCommandeState extends State<_AnnulationCommande> {
  final _motif = TextEditingController();

  /// Motifs courants, proposés en un geste.
  ///
  /// Ce ne sont pas des valeurs imposées : chacun remplit le champ, qui reste
  /// modifiable. Ils existent parce qu'une annulation se décide un samedi soir,
  /// au téléphone, et qu'un champ libre vide se remplit alors d'un « x ».
  static const _motifsCourants = [
    'Rupture de stock en cuisine',
    'Client injoignable',
    'Adresse introuvable',
    'Établissement fermé',
    'Erreur de saisie',
  ];

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = AdminColorTokens.semantic(scheme).danger;
    final largeur = (MediaQuery.of(context).size.width * 0.9).clamp(400.0, 560.0);
    final motifValide = _motif.text.trim().length >= 3;

    return Dialog(
      child: SizedBox(
        width: largeur,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: danger, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Annuler la commande ${widget.order.reference}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            messageDeRemboursement(widget.order),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Montant : ${PriceFormatter.format(widget.order.totalAffiche)}'
                    ' · ${widget.order.statut.libelle}',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _motif,
                    autofocus: true,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Motif de l’annulation',
                      helperText: 'Il sera lu par le client s’il rappelle, et par la '
                          'comptabilité s’il est remboursé.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final motif in _motifsCourants)
                        ActionChip(
                          label: Text(motif, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() {
                            _motif.text = motif;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Revenir'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    // Désactivé tant que le motif est vide : le serveur le
                    // refuserait, et un aller-retour pour l'apprendre laisse
                    // croire à une panne.
                    onPressed: motifValide
                        ? () => Navigator.of(context).pop(_motif.text.trim())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: danger,
                      foregroundColor: scheme.onError,
                    ),
                    child: const Text('Annuler la commande'),
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
