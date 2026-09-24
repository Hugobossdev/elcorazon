import 'package:intl/intl.dart';

/// Formateurs d'affichage du back-office.
///
/// ## Trois méthodes retirées, et pourquoi
///
/// `formatCurrency`, `formatPrice` et `formatPhone` vivaient ici et **aucun
/// écran ne les appelait**. Toutes trois codaient un marché en dur : la devise
/// par défaut `XOF`, le symbole `CFA`, et un indicatif `+225` ajouté à tout
/// numéro sans préfixe — ivoirien, alors que l'établissement historique est à
/// Lomé.
///
/// Elles n'ont pas été corrigées mais supprimées, parce que leur règle existe
/// déjà ailleurs et en mieux :
///
/// * les montants passent par `formatPrice()` du socle
///   (`apps/admin/lib/utils/price_formatter.dart`), qui déduit les décimales de
///   la devise au lieu de la supposer ;
/// * un indicatif se lit sur le pays de l'établissement (`phone_prefix`), que
///   le serveur rend sur chaque fiche.
///
/// Les garder revenait à conserver un marché écrit en dur dans un produit
/// multi-pays, derrière un angle mort : `flutter analyze` ne signale pas une
/// méthode publique inutilisée, et `tools/code_mort.py` raisonne par fichier —
/// or ce fichier-ci est bien atteint, pour `formatRelativeTime`.
///
/// Le reste a suivi le même chemin : validations (prix plafonné à 9 999,99,
/// soit dix mille francs CFA), calculs, dates et fichiers qu'aucun écran
/// n'appelait, adossés à `admin_constants.dart` — nom de société
/// « FastFoodGo », noms de tables Supabase, couleurs de statut, tous morts
/// depuis la v2. Les règles réelles vivent là où le serveur les impose.
class AdminHelpers {
  AdminHelpers._(); // Constructeur privé

  // =====================================================
  // FORMATTING
  // =====================================================

  /// Formate une date selon le format français
  static String formatDate(DateTime date, {bool includeTime = false}) {
    if (includeTime) {
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
    }
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  /// Formate une date relative (il y a X temps)
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return formatDate(date);
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}
