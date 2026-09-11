import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Les trois pièces d'un dossier livreur, et ce que l'application en dit.
///
/// ## Pourquoi ce fichier existe
///
/// Le serveur n'a pas de ressource « document ». Un dossier
/// (`CourierProfile`) porte **trois champs fichier** — `id_document`,
/// `licence_document`, `vehicle_document` — et **une seule** décision de
/// vérification, valable pour l'ensemble. Il n'y a donc pas d'entité à
/// modéliser : il y a trois emplacements, et un état de dossier qui les
/// surplombe.
///
/// Le back-office fait la même composition de son côté
/// (`apps/admin/lib/presentation/documents_livreur.dart`). Les deux listes
/// doivent nommer les mêmes trois choses, dans le même ordre, sous peine qu'un
/// livreur corrige la pièce que l'instructeur n'attendait pas.
///
/// ## Ce que ce fichier ne fait pas
///
/// Il ne dit **jamais** si une pièce est « validée » ou « refusée ». La
/// décision porte sur le dossier entier, pas sur chaque pièce : faire
/// semblant du contraire laisserait croire qu'on peut approuver un permis
/// seul, et il n'existe côté serveur aucun champ qui le permettrait. Ce qui
/// se dit d'une pièce, ici, est seulement : **est-elle déposée ?**
enum PieceDuDossier {
  /// La pièce d'identité, demandée d'abord : elle conditionne l'examen des
  /// deux autres.
  identite(
    champ: 'id_document',
    libelle: 'Pièce d\'identité',
    precision: 'Carte nationale, passeport ou titre de séjour, en cours de validité.',
    icone: Icons.badge_outlined,
  ),
  permis(
    champ: 'licence_document',
    libelle: 'Permis de conduire',
    precision: 'Le recto, lisible en entier. Un vélo ne dispense pas de pièce '
        'd\'identité, mais dispense du permis.',
    icone: Icons.credit_card_outlined,
  ),
  carteGrise(
    champ: 'vehicle_document',
    libelle: 'Carte grise du véhicule',
    precision: 'Au nom du conducteur, ou accompagnée d\'une autorisation du '
        'propriétaire.',
    icone: Icons.description_outlined,
  );

  const PieceDuDossier({
    required this.champ,
    required this.libelle,
    required this.precision,
    required this.icone,
  });

  /// Le nom du champ **au contrat**, celui qu'attend `DocumentsSerializer`.
  ///
  /// C'est un identifiant d'API, pas un libellé : l'envoyer traduit ferait
  /// refuser le dépôt.
  final String champ;

  final String libelle;

  /// Ce qu'on attend concrètement, en une phrase.
  ///
  /// Sans elle, la pièce la plus souvent rejetée est celle dont personne n'a
  /// dit ce qu'elle devait montrer — et le livreur redépose la même photo.
  final String precision;

  final IconData icone;

  /// L'URL signée de cette pièce sur [dossier], ou `null` si elle manque.
  String? urlSur(eccore.CourierProfile dossier) {
    final url = switch (this) {
      PieceDuDossier.identite => dossier.idDocument,
      PieceDuDossier.permis => dossier.licenceDocument,
      PieceDuDossier.carteGrise => dossier.vehicleDocument,
    };
    return (url == null || url.isEmpty) ? null : url;
  }

  bool estDeposeeSur(eccore.CourierProfile dossier) => urlSur(dossier) != null;
}

/// Ce que le dossier, pris dans son ensemble, réclame du livreur.
///
/// Trois situations, et une seule question par situation : faut-il déposer
/// quelque chose, et pourquoi ? La formule est ici plutôt que dans chaque
/// écran parce que trois écrans la posent — le mur du dossier refusé, le
/// bandeau d'attente, la fiche de profil — et qu'une formulation par écran
/// donne trois versions de l'état du dossier, dont deux fausses.
enum ExigenceDuDossier {
  /// Il manque au moins une pièce. Le cas d'un livreur qui vient de s'inscrire :
  /// son compte existe, son dossier est vide.
  incomplet,

  /// Toutes les pièces sont là et le dossier a été refusé. Il faut remplacer
  /// ce qui a motivé le refus — le dépôt rouvre l'instruction (L5).
  aCorriger,

  /// Rien n'est attendu : les pièces sont là et le dossier suit son cours.
  rienAFaire;

  static ExigenceDuDossier depuis(eccore.CourierProfile? dossier) {
    if (dossier == null) return ExigenceDuDossier.rienAFaire;
    if (!dossier.hasAllDocuments) return ExigenceDuDossier.incomplet;
    if (dossier.verificationStatus == 'rejected') return ExigenceDuDossier.aCorriger;
    return ExigenceDuDossier.rienAFaire;
  }

  /// Faut-il proposer l'écran de dépôt de façon visible ?
  bool get appelleUneAction => this != ExigenceDuDossier.rienAFaire;

  /// L'intitulé du bouton qui y mène.
  String get action => switch (this) {
    ExigenceDuDossier.incomplet => 'Déposer mes pièces',
    ExigenceDuDossier.aCorriger => 'Corriger mon dossier',
    ExigenceDuDossier.rienAFaire => 'Mes pièces justificatives',
  };
}

/// Les pièces qui manquent encore, dans l'ordre où on les demande.
List<PieceDuDossier> piecesManquantes(eccore.CourierProfile dossier) => [
  for (final piece in PieceDuDossier.values)
    if (!piece.estDeposeeSur(dossier)) piece,
];
