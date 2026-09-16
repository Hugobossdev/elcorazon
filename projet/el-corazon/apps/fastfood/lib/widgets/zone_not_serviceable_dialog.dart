import 'package:flutter/material.dart';

/// Dialogue affiché quand aucune cuisine ne livre l'adresse choisie.
///
/// Il annonçait auparavant une distance et un maximum — tous deux calculés sur
/// le téléphone, à vol d'oiseau, depuis une position de restaurant en dur. Le
/// serveur ne refuse pas sur une distance : il refuse parce qu'aucune zone ne
/// couvre le point, ou parce que le point sort du rayon de la cuisine. Dire
/// « 12,4 km, maximum 25 km » à un client qu'on vient de refuser était une
/// explication fausse d'un refus juste.
///
/// ## Les deux gestes proposés, et pourquoi pas « Réessayer »
///
/// La réponse ne changera pas en réessayant : c'est une réponse, pas une panne.
/// Le client peut **changer d'adresse** — livrer au bureau plutôt qu'à la
/// maison — ou **changer de ville**, s'il commande pour quelqu'un d'autre.
///
/// Le bouton principal fermait jusqu'ici le dialogue… sans le fermer : il
/// appelait l'action pendant que le dialogue restait ouvert par-dessus l'écran
/// qu'elle ouvrait. Chaque action ferme désormais d'abord.
class ZoneNotServiceableDialog extends StatelessWidget {
  const ZoneNotServiceableDialog({
    super.key,
    this.raison,
    this.onChooseAnotherAddress,
    this.onChangeCity,
    this.onViewServiceableZones,
  });

  /// La phrase du serveur, plus précise que la nôtre quand il en donne une —
  /// « Adresse à 18,2 km, au-delà des 15 km desservis depuis cette cuisine ».
  final String? raison;

  final VoidCallback? onChooseAnotherAddress;
  final VoidCallback? onChangeCity;
  final VoidCallback? onViewServiceableZones;

  static const titre = 'Nous ne livrons pas encore dans cette zone.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motif = (raison == null || raison!.trim().isEmpty) ? null : raison!.trim();

    void fermerPuis(VoidCallback? action) {
      Navigator.of(context).pop();
      action?.call();
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.wrong_location_outlined, color: theme.colorScheme.error, size: 32),
      title: const Text(titre, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            motif ??
                'Aucune cuisine El Corazón ne livre encore cette adresse. '
                    'Vous ne pouvez pas commander pour elle pour le moment.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Choisissez une autre adresse de livraison, ou une autre ville où '
            'El Corazón est présent.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        if (onViewServiceableZones != null)
          TextButton.icon(
            onPressed: () => fermerPuis(onViewServiceableZones),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Voir les zones'),
          ),
        if (onChangeCity != null)
          TextButton.icon(
            onPressed: () => fermerPuis(onChangeCity),
            icon: const Icon(Icons.location_city_outlined),
            label: const Text('Changer de ville'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        if (onChooseAnotherAddress != null)
          FilledButton.icon(
            onPressed: () => fermerPuis(onChooseAnotherAddress),
            icon: const Icon(Icons.location_searching),
            label: const Text('Changer d’adresse'),
          ),
      ],
    );
  }

  static Future<void> show(
    BuildContext context, {
    String? raison,
    VoidCallback? onChooseAnotherAddress,
    VoidCallback? onChangeCity,
    VoidCallback? onViewServiceableZones,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ZoneNotServiceableDialog(
        raison: raison,
        onChooseAnotherAddress: onChooseAnotherAddress,
        onChangeCity: onChangeCity,
        onViewServiceableZones: onViewServiceableZones,
      ),
    );
  }
}
