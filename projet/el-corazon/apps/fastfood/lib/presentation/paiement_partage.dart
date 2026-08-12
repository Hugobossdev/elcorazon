import 'package:flutter/material.dart';

import 'package:elcora_fast/theme.dart';

/// Vocabulaire d'affichage du paiement partagé.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// `models/group_payment.dart` recopiait `eccore.SplitPayment` et
/// `eccore.SplitShare` sous d'autres noms, avec deux énumérations et un
/// `fromRemote` qui mettait cinq champs à `null` faute de contrepartie —
/// `userId`, `email`, `operator`, `transactionId`, `paymentResult`. Il ne
/// restait de propre à l'application que les libellés : ils sont ici.
///
/// Les trois tables de l'écran — libellé, icône, couleur — étaient trois
/// `switch` sur la même valeur. Elles n'en font plus qu'une.
enum EtatPart {
  enAttente('pending', 'En attente', Icons.pending, Colors.orange),
  reglee('paid', 'Payé', Icons.check_circle, AppColors.success),
  echouee('failed', 'Échoué', Icons.error, AppColors.error),
  annulee('cancelled', 'Annulé', Icons.cancel, Colors.grey);

  const EtatPart(this.versServeur, this.libelle, this.icone, this.couleur);

  /// La valeur que le serveur rend (`SplitShareStatus`).
  final String versServeur;

  final String libelle;
  final IconData icone;
  final Color couleur;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// L'énumération locale en comptait **cinq** : `processing` n'a jamais eu de
  /// contrepartie, et la traduction ne pouvait donc pas le produire. Il avait
  /// pourtant son libellé, son icône et sa couleur.
  static EtatPart depuisServeur(String valeur) {
    for (final etat in values) {
      if (etat.versServeur == valeur) return etat;
    }
    return enAttente;
  }
}

/// État d'ensemble d'un partage.
///
/// C'est le **serveur** qui solde un partage quand toutes les parts sont
/// réglées, jamais le client.
enum EtatPartage {
  enAttente('pending', 'En attente'),
  soldee('completed', 'Réglé'),
  annulee('cancelled', 'Annulé');

  const EtatPartage(this.versServeur, this.libelle);

  final String versServeur;
  final String libelle;

  /// L'énumération locale comptait un `inProgress` que la traduction ne
  /// produisait pas non plus.
  static EtatPartage depuisServeur(String valeur) {
    for (final etat in values) {
      if (etat.versServeur == valeur) return etat;
    }
    return enAttente;
  }
}
/// Un convive d'un paiement partagé, tel que le compose l'écran de partage.
///
/// C'est une **saisie**, pas un état : le nom, le téléphone et l'opérateur sont
/// ce que l'initiateur renseigne avant d'envoyer la répartition au serveur
/// (`POST /payments/{commande}/split/`). Ce que devient chaque part — réglée,
/// en attente, expirée — vient de `eccore.SplitShare`, et se lit avec
/// [EtatPart].
///
/// Il vivait dans `models/`, où il ne doublait pourtant aucune entité : un
/// brouillon n'a pas d'existence côté serveur tant qu'il n'est pas envoyé.
/// C'est la même raison qui a mis `BrouillonAdresse` hors des modèles.
class ConviveDuPartage {
  const ConviveDuPartage({
    required this.userId,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.operator,
    required this.amount,
    this.backendId,
  });

  final String userId;
  final String name;
  final String email;
  final String phoneNumber;

  /// Opérateur de monnaie électronique choisi par le convive.
  final String operator;

  /// Montant de la part, en unité majeure — ce que l'écran affiche.
  ///
  /// La répartition qui fait foi est celle du serveur : lui seul découpe le
  /// total sans perdre d'unité mineure. Une division faite ici laisserait un
  /// franc orphelin à chaque partage impair.
  final double amount;

  /// Identifiant de la part une fois créée côté serveur, `null` avant.
  final String? backendId;

  ConviveDuPartage copyWith({
    String? phoneNumber,
    String? operator,
    double? amount,
    String? backendId,
  }) {
    return ConviveDuPartage(
      userId: userId,
      name: name,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      operator: operator ?? this.operator,
      amount: amount ?? this.amount,
      backendId: backendId ?? this.backendId,
    );
  }
}
