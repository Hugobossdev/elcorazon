/// Vocabulaires fermés de la gamification, tels que le serveur les accepte.
///
/// ## Pourquoi un fichier à part
///
/// Les formulaires du back-office proposaient leurs propres listes :
/// `orders_count`, `total_spent`, `streak_days` comme **nature de défi**, là où
/// le serveur attend `daily`, `weekly`, `monthly` ou `special` ; et quatre
/// critères de succès dont deux seulement existent (`AchievementCondition`).
/// Chaque création de défi revenait donc en 400, et le dialogue, fermé avant la
/// réponse, ne le disait pas.
///
/// Ces valeurs sont désormais écrites **une fois**, ici, et comparées à celles
/// de Django par `tools/contrat_vocabulaire.py`, que la CI exécute : une valeur
/// ajoutée ou renommée d'un seul côté fait échouer la porte avant d'atteindre
/// un écran. Le serveur reste la source de vérité ; ce fichier en est le miroir
/// vérifié.
library;

/// Nature d'un défi — `apps.gamification.models.ChallengeKind`.
///
/// Elle **qualifie** le défi (sa cadence annoncée au client) ; la fenêtre
/// réelle est portée par `starts_at` / `ends_at`, que le serveur n'infère pas
/// de la nature.
abstract final class ChallengeKind {
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';
  static const special = 'special';

  static const values = [daily, weekly, monthly, special];

  static String libelle(String valeur) => switch (valeur) {
        daily => 'Quotidien',
        weekly => 'Hebdomadaire',
        monthly => 'Mensuel',
        special => 'Spécial',
        _ => valeur,
      };

  /// Durée proposée par défaut pour la fenêtre d'un défi de cette nature.
  ///
  /// Une **proposition** de formulaire, jamais une règle : le serveur ne la
  /// connaît pas, et un défi hebdomadaire peut démarrer un mercredi.
  static Duration dureeProposee(String valeur) => switch (valeur) {
        daily => const Duration(days: 1),
        weekly => const Duration(days: 7),
        monthly => const Duration(days: 30),
        _ => const Duration(days: 14),
      };
}

/// Ce qu'un succès ou un défi compte — `apps.gamification.models.AchievementCondition`.
///
/// Deux critères, parce que le serveur n'en **mesure** que deux
/// (`GamificationService`) : le nombre de commandes livrées, et le total payé
/// sur ces commandes. Une « série de jours » ou un « nombre de commandes par
/// catégorie » proposés à l'écran étaient refusés à l'enregistrement — et, s'ils
/// avaient été acceptés, n'auraient jamais rien compté.
abstract final class AchievementCondition {
  static const ordersCount = 'orders_count';

  /// Total payé sur les commandes livrées, **en unité mineure**. Pour le franc
  /// CFA (XOF comme XAF), l'unité mineure est le franc : 5 000 veut dire
  /// 5 000 F. Le serveur additionne les commandes de toutes les cuisines, sans
  /// conversion.
  static const totalSpentMinor = 'total_spent_minor';

  static const values = [ordersCount, totalSpentMinor];

  static String libelle(String valeur) => switch (valeur) {
        ordersCount => 'Nombre de commandes livrées',
        totalSpentMinor => 'Total payé (unité mineure de la devise)',
        _ => valeur,
      };

  /// Ce que représente le seuil saisi, pour l'aide du champ.
  static String uniteDuSeuil(String valeur) => switch (valeur) {
        ordersCount => 'commandes livrées',
        totalSpentMinor => 'unités mineures (francs pour XOF/XAF)',
        _ => '',
      };
}
