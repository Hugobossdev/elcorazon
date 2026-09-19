/// Où en est une pièce du dossier livreur par rapport à sa date d'expiration.
///
/// Le seuil d'alerte est d'un mois : c'est l'échéance du premier rappel que le
/// serveur envoie (`remind_document_expiry`), et l'écran doit alerter au même
/// moment que la notification — pas avant, pas après.
enum EtatExpiration {
  /// Aucune date saisie. Ni bon ni mauvais : on ne sait pas.
  inconnue,
  valide,
  bientot,
  expiree;

  static const seuilDAlerte = Duration(days: 30);

  /// Compare au **jour**, pas à l'instant : une pièce qui expire aujourd'hui
  /// est encore valable toute la journée, comme sur le document lui-même.
  static EtatExpiration de(DateTime? expireLe, {DateTime? maintenant}) {
    if (expireLe == null) return EtatExpiration.inconnue;
    final m = maintenant ?? DateTime.now();
    final aujourdhui = DateTime(m.year, m.month, m.day);
    final echeance = DateTime(expireLe.year, expireLe.month, expireLe.day);
    if (echeance.isBefore(aujourdhui)) return EtatExpiration.expiree;
    if (echeance.difference(aujourdhui) <= seuilDAlerte) return EtatExpiration.bientot;
    return EtatExpiration.valide;
  }
}

/// Ce qu'on écrit sous la pièce.
String libelleExpiration(DateTime? expireLe, {DateTime? maintenant}) {
  if (expireLe == null) return 'Date d’expiration non saisie';
  final m = maintenant ?? DateTime.now();
  final aujourdhui = DateTime(m.year, m.month, m.day);
  final echeance = DateTime(expireLe.year, expireLe.month, expireLe.day);
  final jours = echeance.difference(aujourdhui).inDays;
  final date = '${echeance.day.toString().padLeft(2, '0')}/'
      '${echeance.month.toString().padLeft(2, '0')}/${echeance.year}';
  if (jours < 0) return 'Expirée depuis le $date';
  if (jours == 0) return 'Expire aujourd’hui';
  if (jours == 1) return 'Expire demain';
  if (jours <= 30) return 'Expire dans $jours jours ($date)';
  return 'Valable jusqu’au $date';
}
