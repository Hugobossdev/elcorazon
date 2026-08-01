/// Créneau planifié d'un livreur — miroir de `CourierShiftSerializer`.
///
/// **Indicatif, et non opposable.** L'éligibilité d'un livreur reste
/// `can_accept_orders` côté serveur (invariant L1) : en ligne, dossier validé,
/// compte actif. Un créneau ne s'y ajoute pas — un livreur présent, en ligne, à
/// qui le serveur refuserait une course parce qu'il est 18 h 05 verrait un refus
/// qu'aucun écran ne sait expliquer, et la commande resterait sans porteur.
///
/// Le planning sert à l'exploitation : savoir qui elle attend, et constater les
/// écarts.
class CourierShift {
  const CourierShift({
    required this.id,
    required this.courierId,
    required this.courierName,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.isAvailable,
  });

  factory CourierShift.fromJson(Map<String, dynamic> json) {
    return CourierShift(
      id: json['id'] as String,
      courierId: json['courier'] as String,
      courierName: json['courier_name'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as int,
      startMinutes: _minutes(json['start_time'] as String),
      endMinutes: _minutes(json['end_time'] as String),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  final String id;
  final String courierId;
  final String courierName;

  /// Jour ISO : 1 = lundi, 7 = dimanche. Un entier plutôt qu'un nom — il se
  /// trie, il s'indexe, et il ne dépend pas de la langue de l'interface.
  final int dayOfWeek;

  /// Minutes depuis minuit, **heure locale de l'établissement**.
  ///
  /// Ni `DateTime` ni instant UTC : « le mardi de 9 h à 17 h » se répète, et
  /// l'exprimer en instants obligerait à régénérer les lignes chaque semaine,
  /// avec un décalage à chaque changement d'heure.
  final int startMinutes;
  final int endMinutes;

  /// Faux = absence signalée. Le créneau reste dans le planning : le retirer
  /// ferait disparaître l'information qu'on vient justement y lire.
  final bool isAvailable;

  Duration get start => Duration(minutes: startMinutes);
  Duration get end => Duration(minutes: endMinutes);

  /// `HH:MM`, la forme qu'attend le serveur.
  static String formatTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  static int _minutes(String heure) {
    final parties = heure.split(':');
    return int.parse(parties[0]) * 60 + int.parse(parties[1]);
  }
}
