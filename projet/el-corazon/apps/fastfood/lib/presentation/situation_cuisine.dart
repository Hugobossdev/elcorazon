import 'package:flutter/material.dart';

import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Ce qu'un écran dit d'une [SituationCuisine] : un titre, une phrase, une
/// icône, et s'il vaut la peine de proposer « Réessayer ».
///
/// ## Pourquoi un seul lieu
///
/// L'écran de la carte ne connaissait qu'un message d'échec — « La carte n'a
/// pas pu être chargée. Vérifiez votre connexion » — et le sélecteur de cuisine
/// un seul vide — « aucune cuisine ». Les deux se trompaient dans un cas sur
/// deux : un serveur en panne envoyait vérifier le Wi-Fi, et un annuaire
/// illisible annonçait qu'El Corazón ne livrait pas le quartier. Chaque
/// situation a désormais sa phrase, écrite une fois.
///
/// ## Le vocabulaire
///
/// El Corazón est une plateforme de **cuisines de livraison** : on ne « va »
/// pas au restaurant, une cuisine prépare et un livreur apporte. Les phrases
/// parlent donc de cuisine, de livraison et de zone desservie — jamais de
/// restaurant « en service ».
///
/// [motifServeur] est la phrase du serveur quand il en a donné une
/// (`unavailable_reason`, `reason`) : elle est plus précise que celle-ci —
/// « La cuisine El Corazón Lomé est fermée pour le moment » — et prime.
class PresentationSituation {
  const PresentationSituation({
    required this.titre,
    required this.message,
    required this.icone,
    this.reessayable = false,
  });

  factory PresentationSituation.de(
    SituationCuisine situation, {
    String? nomCuisine,
    String? motifServeur,
  }) {
    final motif = (motifServeur == null || motifServeur.trim().isEmpty) ? null : motifServeur;

    return switch (situation) {
      SituationCuisine.chargement => const PresentationSituation(
        titre: 'Recherche de votre cuisine…',
        message: 'Nous cherchons la cuisine El Corazón qui livre votre adresse.',
        icone: Icons.soup_kitchen_outlined,
      ),
      SituationCuisine.commandable => PresentationSituation(
        titre: nomCuisine ?? 'Cuisine ouverte',
        message: 'Ouverte — vos commandes sont préparées et livrées.',
        icone: Icons.soup_kitchen_outlined,
      ),
      SituationCuisine.fermee => PresentationSituation(
        titre: 'Cuisine fermée',
        message:
            motif ??
            'La cuisine est fermée pour le moment. Parcourez la carte : '
                'vous pourrez commander dès sa réouverture.',
        icone: Icons.nightlight_outlined,
      ),
      SituationCuisine.enPause => PresentationSituation(
        titre: 'Commandes en pause',
        message:
            motif ??
            'La cuisine est en plein coup de feu et ne prend plus de commandes '
                'pour quelques minutes.',
        icone: Icons.hourglass_top_rounded,
        reessayable: true,
      ),
      SituationCuisine.suspendue || SituationCuisine.indisponible => PresentationSituation(
        titre: 'Cuisine indisponible',
        message: motif ?? 'Cette cuisine ne livre pas pour le moment.',
        icone: Icons.block_outlined,
      ),
      SituationCuisine.aucuneCuisine => PresentationSituation(
        titre: 'Pas encore de cuisine près de chez vous',
        message: motif ?? 'Aucune cuisine El Corazón ne livre votre zone pour le moment.',
        icone: Icons.location_off_outlined,
      ),
      SituationCuisine.adresseNonDesservie => PresentationSituation(
        titre: 'Adresse hors zone de livraison',
        message:
            motif ??
            'Cette adresse est en dehors de la zone desservie. '
                'Choisissez une autre adresse de livraison.',
        icone: Icons.wrong_location_outlined,
      ),
      SituationCuisine.erreurReseau => const PresentationSituation(
        titre: 'Connexion impossible',
        message:
            'Impossible de joindre El Corazón. Vérifiez votre connexion internet, '
            'puis réessayez.',
        icone: Icons.wifi_off_rounded,
        reessayable: true,
      ),
      SituationCuisine.erreurServeur => const PresentationSituation(
        titre: 'Service momentanément indisponible',
        message: 'Notre service rencontre un problème. Réessayez dans un instant.',
        icone: Icons.cloud_off_rounded,
        reessayable: true,
      ),
      SituationCuisine.reponseInvalide => const PresentationSituation(
        titre: 'Réponse inattendue',
        message:
            "L'application n'a pas compris la réponse du service. "
            'Réessayez, ou mettez l’application à jour.',
        icone: Icons.sync_problem_rounded,
        reessayable: true,
      ),
      SituationCuisine.erreurAuthentification => const PresentationSituation(
        titre: 'Session expirée',
        message: 'Reconnectez-vous pour continuer.',
        icone: Icons.lock_clock_outlined,
      ),
      SituationCuisine.erreurAutorisation => const PresentationSituation(
        titre: 'Accès refusé',
        message: 'Votre compte ne permet pas cette action.',
        icone: Icons.lock_outline_rounded,
      ),
      SituationCuisine.erreurApi => PresentationSituation(
        titre: 'Demande refusée',
        message: motif ?? 'Le service a refusé la demande. Réessayez plus tard.',
        icone: Icons.error_outline_rounded,
        reessayable: true,
      ),
      SituationCuisine.localisationInvalide => const PresentationSituation(
        titre: 'Position inutilisable',
        message:
            "Votre position n'a pas pu être utilisée. "
            'Choisissez votre adresse de livraison.',
        icone: Icons.location_disabled_outlined,
      ),
    };
  }

  final String titre;
  final String message;
  final IconData icone;

  /// Proposer « Réessayer » a-t-il un sens ? Faux pour une réponse du serveur
  /// qui ne changera pas en réessayant — aucune cuisine, adresse hors zone,
  /// cuisine fermée jusqu'à l'ouverture.
  final bool reessayable;
}
