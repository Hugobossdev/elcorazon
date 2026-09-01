/// Les pièces d'un dossier livreur, telles que les écrans de validation les
/// montrent.
///
/// Pourquoi ce n'est pas une entité
/// --------------------------------
///
/// Le serveur n'a pas de ressource « document ». Un dossier livreur
/// (`CourierProfile`) porte trois URL — `id_document`, `licence_document`,
/// `vehicle_document` — et **une seule** décision de vérification, valable pour
/// l'ensemble. `DriverDocumentService.documentsOf` compose ces lignes pour
/// l'affichage ; elles n'existent nulle part ailleurs.
///
/// Ce fichier vient de `models/driver_document.dart`, retiré au lot 3. Y
/// figuraient un `fromMap` sans appelant, et six champs que la composition ne
/// renseignait jamais — nom et type de fichier, taille, date d'expiration,
/// validateur, téléphone du livreur. Deux d'entre eux étaient affichés : la
/// taille du fichier, jamais montrée faute de valeur, et une date d'expiration
/// lue derrière un `!` dans une branche qu'aucun statut n'atteignait.
library;

import 'package:flutter/material.dart';

/// Décision de vérification, telle que le siège la lit.
///
/// Trois valeurs, parce que `CourierProfile.verificationStatus` n'en produit
/// que trois. L'énumération remplacée en comptait une quatrième, « expiré »,
/// qu'aucune réponse du serveur ne donne : la branche d'écran qui la testait
/// était morte, et l'assertion de non-nullité qu'elle contenait aurait planté
/// le jour où quelqu'un l'aurait rendue atteignable.
enum StatutVerification {
  enAttente('En attente', Icons.hourglass_top_rounded),
  approuve('Approuvé', Icons.verified_rounded),
  refuse('Refusé', Icons.cancel_rounded);

  const StatutVerification(this.libelle, this.icone);

  /// Depuis `CourierProfile.verificationStatus`.
  ///
  /// `suspended` se lit comme un refus : dans les deux cas le livreur ne roule
  /// pas, et c'est ce que le siège doit voir.
  factory StatutVerification.depuisServeur(String verification) {
    return switch (verification) {
      'approved' => StatutVerification.approuve,
      'rejected' || 'suspended' => StatutVerification.refuse,
      _ => StatutVerification.enAttente,
    };
  }

  final String libelle;

  /// L'icône de la décision.
  ///
  /// Une icône, pas une illustration : ce que le siège lit ici est l'état d'un
  /// dossier administratif. Les emojis remplacés — `'⏳'`, `'✅'`, `'❌'` —
  /// n'étaient d'ailleurs affichés nulle part.
  final IconData icone;
}

/// Nature d'une pièce. Trois, comme les trois URL du dossier.
enum PieceDossier {
  identite('Pièce d’identité'),
  permis('Permis de conduire'),
  carteGrise('Carte grise');

  const PieceDossier(this.libelle);

  final String libelle;
}

/// Une pièce du dossier, composée pour l'affichage.
class PieceLivreur {
  const PieceLivreur({
    required this.courierId,
    required this.piece,
    required this.statut,
    required this.deposeeLe,
    this.url,
    this.notes,
    this.decideeLe,
    this.motifDeRefus,
    this.nomLivreur,
    this.emailLivreur,
  });

  /// Identifiant du **dossier**, pas de la pièce : c'est lui qui porte la
  /// décision, et c'est sur lui que les écrans agissent.
  final String courierId;

  final PieceDossier piece;

  /// Celui du dossier. Il n'y a pas de décision par pièce, et faire semblant du
  /// contraire laisserait croire qu'on peut approuver un permis seul.
  final StatutVerification statut;

  /// `null` quand la pièce n'a pas été déposée.
  final String? url;

  final String? notes;
  final DateTime? decideeLe;
  final String? motifDeRefus;
  final DateTime deposeeLe;
  final String? nomLivreur;
  final String? emailLivreur;

  bool get estDeposee => url != null && url!.isNotEmpty;
  bool get demandeUneDecision => statut == StatutVerification.enAttente;
}
