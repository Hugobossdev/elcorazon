/// Plage d'ouverture d'un établissement — miroir de
/// `ManagedOpeningHoursSerializer` (`backend/apps/restaurants/serializers.py`).
///
/// **Une plage, pas une journée.** Le service du midi et celui du soir sont
/// deux lignes du même jour ; un modèle « ouverture / fermeture » par jour ne
/// saurait pas les représenter, et c'est précisément ce que faisait l'écran des
/// réglages du back-office — une heure d'ouverture, une heure de fermeture,
/// sept interrupteurs, le tout rangé dans les préférences locales du poste.
///
/// Une plage qui franchit minuit se saisit telle quelle : `22:00 → 02:00`,
/// donc [closesAt] avant [opensAt]. Le serveur le reconnaît
/// ([crossesMidnight]) et le service d'ouverture en tient compte. Obliger à
/// saisir deux lignes sur deux jours serait la faute classique du service de
/// nuit du week-end.
class OpeningHours {
  const OpeningHours({
    required this.id,
    required this.restaurantId,
    required this.weekday,
    required this.opensAtMinutes,
    required this.closesAtMinutes,
    required this.crossesMidnight,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) {
    return OpeningHours(
      id: json['id'] as String,
      restaurantId: json['restaurant'].toString(),
      weekday: json['weekday'] as int,
      opensAtMinutes: parseTime(json['opens_at'] as String),
      closesAtMinutes: parseTime(json['closes_at'] as String),
      crossesMidnight: json['crosses_midnight'] as bool? ?? false,
    );
  }

  final String id;
  final String restaurantId;

  /// **Lundi = 0**, dimanche = 6 — l'alignement de `date.weekday()` en Python,
  /// que le serveur a choisi pour éviter la conversion manuelle qui décale
  /// d'un jour. Ce n'est *pas* la convention de `DateTime.weekday` en Dart, où
  /// lundi vaut 1 : voir [depuisDateTimeWeekday].
  final int weekday;

  /// Minutes depuis minuit — même représentation que [CourierShift], pour que
  /// les deux plannings se comparent sans conversion.
  final int opensAtMinutes;
  final int closesAtMinutes;

  /// Calculé par le serveur : `closes_at < opens_at`. Rendu plutôt que déduit
  /// ici, pour que la règle n'existe qu'à un seul endroit.
  final bool crossesMidnight;

  /// `HH:MM:SS` → minutes depuis minuit. Les secondes sont ignorées : le
  /// serveur les rend, aucune ouverture ne s'y joue.
  static int parseTime(String valeur) {
    final parts = valeur.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Minutes depuis minuit → `HH:MM`, la forme qu'accepte `TimeField`.
  static String formatTime(int minutes) {
    final heures = (minutes ~/ 60).toString().padLeft(2, '0');
    final reste = (minutes % 60).toString().padLeft(2, '0');
    return '$heures:$reste';
  }

  /// Le jour d'un `DateTime` Dart, dans la convention du serveur.
  ///
  /// `DateTime.weekday` compte lundi = 1 ; le serveur compte lundi = 0. Le
  /// décalage se fait ici, une fois, plutôt que dans chaque écran.
  static int depuisDateTimeWeekday(int dartWeekday) => dartWeekday - 1;

  String get opensAt => formatTime(opensAtMinutes);
  String get closesAt => formatTime(closesAtMinutes);
}
