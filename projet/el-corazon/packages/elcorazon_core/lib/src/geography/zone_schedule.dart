/// Statuts, horaires et exceptions d'une zone — miroirs de
/// `backend/apps/geography/states.py` et `models.py`.
///
/// **Aucune règle ne vit ici.** La zone est-elle ouverte, quelle transition
/// est permise : le serveur le dit (`DeliveryZone.transitions`, le refus
/// `zone_closed`). Ces classes ne font que lire ce qu'il envoie.
library;

/// Statut d'une zone. Vocabulaire vérifié contre `ZoneStatus` par
/// `tools/contrat_vocabulaire.py`.
abstract final class StatutZone {
  static const brouillon = 'draft';
  static const enRevue = 'pending_review';
  static const publiee = 'published';
  static const suspendue = 'suspended';
  static const archivee = 'archived';

  static String libelle(String statut) => switch (statut) {
        brouillon => 'Brouillon',
        enRevue => 'En revue',
        publiee => 'Publiée',
        suspendue => 'Suspendue',
        archivee => 'Archivée',
        _ => statut,
      };
}

/// Nature d'une exception d'horaires — vérifiée contre `ZoneExceptionKind`.
abstract final class NatureExceptionZone {
  static const fermeture = 'closed';
  static const ouverture = 'open';
}

/// Plage hebdomadaire — `weekday` 0 = lundi, comme `date.weekday()` Python.
class HoraireDeZone {
  const HoraireDeZone({
    required this.jour,
    required this.ouvre,
    required this.ferme,
  });

  factory HoraireDeZone.fromJson(Map<String, dynamic> json) => HoraireDeZone(
        jour: json['weekday'] as int,
        ouvre: _hhmm(json['opens_at'] as String),
        ferme: _hhmm(json['closes_at'] as String),
      );

  /// 0 = lundi … 6 = dimanche.
  final int jour;

  /// `HH:MM`, à l'heure du pays de la zone.
  final String ouvre;
  final String ferme;

  /// Une plage qui franchit minuit s'écrit `ferme < ouvre`.
  bool get franchitMinuit => ferme.compareTo(ouvre) < 0;

  Map<String, dynamic> toJson() => {
        'weekday': jour,
        'opens_at': ouvre,
        'closes_at': ferme,
      };

  static String _hhmm(String valeur) => valeur.length >= 5 ? valeur.substring(0, 5) : valeur;

  static const jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
}

/// Fermeture ou ouverture exceptionnelle, datée — elle se lève d'elle-même.
class ExceptionDeZone {
  const ExceptionDeZone({
    required this.id,
    required this.nature,
    required this.debut,
    required this.fin,
    this.motif = '',
  });

  factory ExceptionDeZone.fromJson(Map<String, dynamic> json) => ExceptionDeZone(
        id: json['id'] as String,
        nature: json['kind'] as String,
        debut: DateTime.parse(json['starts_at'] as String),
        fin: DateTime.parse(json['ends_at'] as String),
        motif: json['reason'] as String? ?? '',
      );

  final String id;
  final String nature;
  final DateTime debut;
  final DateTime fin;
  final String motif;

  bool get estUneFermeture => nature == NatureExceptionZone.fermeture;
}
