import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Ce que l'écran des campagnes dit de leur état, et comment il date un envoi.
///
/// Séparé de l'écran pour être éprouvé sans lui : une campagne programmée
/// s'affichait « Brouillon » — l'écran ne connaissait que deux états — et
/// l'heure d'envoi se compose de deux saisies qu'il est facile d'assembler de
/// travers (la date du jour avec l'heure de la veille, un fuseau oublié).

/// Le libellé de la puce d'état.
String libelleStatutCampagne(eccore.Campaign campagne) {
  if (campagne.isSent) return 'Envoyée';
  if (campagne.isScheduled) return 'Programmée';
  if (campagne.isDraft) return 'Brouillon';
  // Un état que le serveur ajouterait se montre tel quel plutôt que d'être
  // maquillé en l'un des connus.
  return campagne.status;
}

/// L'instant d'envoi composé du [jour] et de l'[heure] saisis, en heure du
/// poste — ou `null` s'il n'est pas à venir.
///
/// `null` plutôt qu'une exception : l'écran le dit à la personne qui saisit,
/// avant tout appel. Le serveur le refuserait de toute façon (409), mais une
/// heure déjà passée est une faute de saisie, pas un refus métier.
DateTime? instantDeProgrammation(
  DateTime jour,
  TimeOfDay heure, {
  DateTime? maintenant,
}) {
  final instant = DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  return instant.isAfter(maintenant ?? DateTime.now()) ? instant : null;
}

/// L'instant proposé par défaut : l'heure pleine qui suit d'au moins trente
/// minutes — le temps de relire, et pas une heure qui passe pendant la saisie.
///
/// Un instant et non une heure : à 23 h 40, la proposition tombe le lendemain,
/// et le calendrier doit s'ouvrir sur ce jour-là, sans quoi la saisie par
/// défaut serait déjà passée.
DateTime instantPropose({DateTime? maintenant}) {
  final dans30 = (maintenant ?? DateTime.now()).add(const Duration(minutes: 30));
  return DateTime(dans30.year, dans30.month, dans30.day, dans30.hour)
      .add(const Duration(hours: 1));
}

/// « le 21/09/2026 à 18:00 », en heure du poste.
String dateHeureDEnvoi(DateTime instant) {
  final local = instant.toLocal();
  String deux(int n) => n.toString().padLeft(2, '0');
  return 'le ${deux(local.day)}/${deux(local.month)}/${local.year} '
      'à ${deux(local.hour)}:${deux(local.minute)}';
}
