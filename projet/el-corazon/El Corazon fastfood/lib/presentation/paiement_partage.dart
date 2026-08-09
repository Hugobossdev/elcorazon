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
