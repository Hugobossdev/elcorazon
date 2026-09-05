import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/restaurant_scope_service.dart';

/// Sur quel établissement travaille-t-on ?
///
/// `RestaurantScopeService` savait déjà répondre — et depuis longtemps :
/// [RestaurantScopeService.hasChoice] existait, documenté comme « la condition
/// d'affichage d'un sélecteur ». Ce sélecteur n'avait jamais été écrit, si bien
/// qu'un compte supervisant deux établissements travaillait silencieusement sur
/// le **premier par ordre alphabétique** : le catalogue, les horaires, les
/// livreurs et la carte de supervision écrivaient tous sur Abidjan pendant
/// qu'on croyait configurer Lomé, sans qu'aucun écran ne montre lequel.
///
/// Il ne s'affiche pas quand il n'y a rien à choisir : faire dérouler une liste
/// d'un seul élément est une étape sans décision, et la présence permanente du
/// menu ferait croire à un réglage là où il n'y en a pas.
class SelecteurEtablissement extends StatelessWidget {
  const SelecteurEtablissement({this.compact = false, super.key});

  /// Version resserrée pour la barre mobile, où la place manque.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer<RestaurantScopeService>(
      builder: (context, perimetre, _) {
        if (!perimetre.hasChoice) return const SizedBox.shrink();

        final courant = perimetre.current;
        if (courant == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Tooltip(
          message: 'Établissement sur lequel portent le catalogue, les '
              'horaires et les livreurs',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: courant.slug,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.expand_more, size: 18),
                items: [
                  for (final etablissement in perimetre.restaurants)
                    DropdownMenuItem<String>(
                      value: etablissement.slug,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            etablissement.status.isPublished
                                ? Icons.storefront
                                : Icons.construction,
                            size: 16,
                            color: etablissement.status.isPublished
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            compact ? etablissement.name : etablissement.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (slug) {
                  if (slug != null) perimetre.select(slug);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
