import 'package:flutter/material.dart';

import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/utils/design_constants.dart';

/// L'annulation d'une commande par son client.
///
/// ## Pourquoi cette règle est écrite ici
///
/// Le serveur est l'autorité : `OrderService.cancel_by_customer` n'accepte que
/// `pending` et `confirmed`, et refuse le reste en 409 avec une phrase écrite
/// pour le client. Ce qui suit n'est **pas** une seconde autorité — c'est ce
/// que l'écran a besoin de savoir pour ne pas proposer un bouton voué au refus.
///
/// Le miroir peut donc diverger, et il faut qu'il puisse : si le serveur
/// resserrait sa règle demain, le bouton resterait affiché et son refus
/// s'afficherait tel quel. C'est l'inverse qui serait grave — un bouton absent
/// sur une commande annulable.
bool peutEtreAnnuleeParLeClient(OrderStatus statut) => switch (statut) {
  OrderStatus.pending || OrderStatus.confirmed => true,
  OrderStatus.preparing ||
  OrderStatus.ready ||
  OrderStatus.pickedUp ||
  OrderStatus.onTheWay ||
  OrderStatus.delivered ||
  OrderStatus.cancelled ||
  OrderStatus.refunded ||
  OrderStatus.failed => false,
};

/// Demande confirmation, et le motif — facultatif.
///
/// Rend le motif saisi si le client confirme, `null` s'il renonce. La chaîne
/// vide est une réponse valable : le client annule **sa** commande et n'a de
/// comptes à rendre à personne. Le motif sert à l'exploitation, qui rappellera
/// peut-être ; l'exiger ferait renoncer quelqu'un qui veut seulement corriger
/// une adresse.
Future<String?> confirmerLAnnulation(BuildContext context, {required String reference}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DialogueDAnnulation(reference: reference),
  );
}

class _DialogueDAnnulation extends StatefulWidget {
  const _DialogueDAnnulation({required this.reference});

  final String reference;

  @override
  State<_DialogueDAnnulation> createState() => _DialogueDAnnulationState();
}

class _DialogueDAnnulationState extends State<_DialogueDAnnulation> {
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.cancel_outlined),
      title: Text('Annuler la commande ${widget.reference} ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'L’annulation est définitive. Une fois la cuisine lancée, elle ne '
            'sera plus possible depuis l’application.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignConstants.spacingM),
          TextField(
            controller: _motif,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motif (facultatif)',
              hintText: 'Ex. : je me suis trompé d’adresse',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Garder ma commande'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: () => Navigator.of(context).pop(_motif.text.trim()),
          child: const Text('Annuler la commande'),
        ),
      ],
    );
  }
}
