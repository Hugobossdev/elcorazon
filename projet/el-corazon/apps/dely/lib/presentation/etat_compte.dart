import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Où en est le compte du livreur, et ce qu'on lui en dit.
///
/// ## Pourquoi ce fichier existe
///
/// L'état d'un livreur ne tient pas dans un champ : il se lit sur **trois**
/// sources, et chacune peut bloquer indépendamment des deux autres.
///
/// * `User.isActive` — le compte est-il ouvert ? Un compte fermé ne se connecte
///   même pas (`authenticate` refuse les comptes inactifs), mais il peut être
///   fermé pendant qu'une session tourne ;
/// * `User.emailVerifiedAt` — l'adresse a-t-elle été prouvée ?
/// * `CourierProfile.verificationStatus` — le **dossier** a-t-il été instruit ?
///   `pending`, `approved`, `rejected`, `suspended` (`VerificationStatus` côté
///   serveur).
///
/// Chaque écran qui recomposerait cette lecture à sa façon en oublierait un
/// terme, et l'oubli ne se verrait qu'au cas particulier — un livreur suspendu
/// à qui l'application continue de promettre des courses, par exemple. Elle est
/// donc faite **ici, une fois**.
///
/// ## Ce que ce fichier ne fait pas
///
/// Il ne décide **jamais** de l'éligibilité aux courses. C'est
/// `CourierProfile.canAcceptOrders`, calculé par le serveur (invariant L1), et
/// le recomposer à partir de `isOnline` et du statut serait exactement la
/// duplication de règle métier que la migration a supprimée. Ce qui est ici est
/// de l'ordre du **message** : quoi afficher, et faut-il barrer la route.
enum EtatCompte {
  /// L'adresse n'est pas encore prouvée. Le seul état qui se corrige depuis
  /// l'application, en saisissant le code reçu.
  verificationRequise,

  /// Dossier déposé, en attente d'instruction par El Corazón. Le livreur entre
  /// dans l'application ; il n'y reçoit simplement aucune course.
  enAttente,

  /// Dossier validé — le cas nominal.
  actif,

  /// Dossier suspendu. Réversible, et par nous seuls.
  suspendu,

  /// Dossier refusé. Le dépôt de nouvelles pièces le rouvre (L5).
  refuse,

  /// Compte désactivé. Le plus fort des états : rien ne s'y répare depuis
  /// l'application.
  bloque;

  /// Lit l'état à partir de ce que le serveur a rendu.
  ///
  /// [profil] peut être nul : le dossier n'est chargé qu'après la première
  /// lecture des courses, et l'écran ne doit pas afficher « suspendu » par
  /// défaut le temps que cette lecture arrive. Tant qu'il manque, seul ce que
  /// le compte dit est opposé.
  static EtatCompte depuis(eccore.User compte, eccore.CourierProfile? profil) {
    if (!compte.isActive) return EtatCompte.bloque;
    if (compte.emailVerifiedAt == null) return EtatCompte.verificationRequise;

    return switch (profil?.verificationStatus) {
      'approved' => EtatCompte.actif,
      'suspended' => EtatCompte.suspendu,
      'rejected' => EtatCompte.refuse,
      'pending' => EtatCompte.enAttente,
      // Dossier pas encore lu, ou statut inconnu de cette version de l'app :
      // on n'invente rien et on ne barre rien. Le serveur reste seul juge de
      // ce que le livreur peut faire, et il refusera de lui-même.
      _ => EtatCompte.actif,
    };
  }

  /// L'écran principal doit-il être remplacé par un mur ?
  ///
  /// Un dossier **en attente** n'en est pas un : le livreur consulte son
  /// profil, ses gains passés, ses réglages. Ce qu'il ne reçoit pas, ce sont
  /// des courses — et c'est le serveur qui le lui refuse, pas nous.
  bool get barreLApplication => switch (this) {
    EtatCompte.verificationRequise || EtatCompte.suspendu || EtatCompte.refuse ||
    EtatCompte.bloque => true,
    EtatCompte.enAttente || EtatCompte.actif => false,
  };

  /// Un bandeau doit-il rappeler l'état en haut de l'écran d'accueil ?
  bool get meriteUnBandeau => this == EtatCompte.enAttente;

  String get titre => switch (this) {
    EtatCompte.verificationRequise => 'Vérifiez votre adresse',
    EtatCompte.enAttente => 'Votre compte est en cours de validation',
    EtatCompte.actif => 'Compte validé',
    EtatCompte.suspendu => 'Votre compte est temporairement suspendu',
    EtatCompte.refuse => 'Votre dossier a été refusé',
    EtatCompte.bloque => 'Votre compte est actuellement bloqué',
  };

  String get explication => switch (this) {
    EtatCompte.verificationRequise =>
      'Saisissez le code que nous avons envoyé à votre adresse pour activer '
          'votre compte.',
    EtatCompte.enAttente =>
      'El Corazón vérifie vos pièces — permis, pièce d\'identité, véhicule. '
          'Vous recevrez vos premières courses dès que votre dossier sera '
          'validé.',
    EtatCompte.actif => 'Vous pouvez recevoir des courses.',
    EtatCompte.suspendu =>
      'Vous ne recevez pas de course pendant la suspension. Contactez '
          'El Corazón pour connaître la marche à suivre.',
    EtatCompte.refuse =>
      'Déposez de nouvelles pièces pour que votre dossier soit réexaminé, ou '
          'contactez El Corazón.',
    EtatCompte.bloque =>
      'Contactez l\'administration d\'El Corazón : rien ne peut être débloqué '
          'depuis l\'application.',
  };

  IconData get icone => switch (this) {
    EtatCompte.verificationRequise => Icons.mark_email_unread_outlined,
    EtatCompte.enAttente => Icons.hourglass_top_outlined,
    EtatCompte.actif => Icons.verified_outlined,
    EtatCompte.suspendu => Icons.pause_circle_outline,
    EtatCompte.refuse => Icons.cancel_outlined,
    EtatCompte.bloque => Icons.lock_outline,
  };
}
