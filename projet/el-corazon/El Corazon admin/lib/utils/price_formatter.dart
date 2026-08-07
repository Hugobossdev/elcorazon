import 'package:elcorazon_core/elcorazon_core.dart' as socle;

/// Délégation vers la règle d'affichage des montants du socle.
///
/// Les trois applications portaient chacune la sienne, et elles ne rendaient
/// pas la même chose pour un même montant : « 12 500 CFA » ici, « 12.500 CFA »
/// chez le client et le livreur. La règle est désormais unique et testée —
/// `formatPrice()` / `Money.format()` dans `elcorazon_core`.
///
/// `formatWithDecimals` n'est pas repris : aucun appelant, et son calcul de
/// décimales était faux au-delà de 0,995. Le nombre de décimales se déduit
/// maintenant de la devise, pas d'un choix d'appelant.
///
/// Ce fichier ne subsiste que pour laisser intacts les points d'appel qui
/// manipulent encore un `double`. Il disparaîtra au lot 3, quand les écrans
/// porteront des `Money` — voir `docs/refactoring-2026-08.md` §4.
class PriceFormatter {
  /// Formate un montant exprimé en **unité majeure** — 12500.0 pour
  /// 12 500 F CFA — en francs CFA, la seule devise que ces écrans affichent.
  ///
  /// Deux différences avec la version qu'elle remplace, toutes deux voulues :
  /// les milliers sont séparés par une espace insécable étroite, qu'aucun
  /// retour à la ligne ne peut couper, et un montant négatif garde son signe au
  /// lieu d'être écrasé à « 0 CFA » — un avoir ou un remboursement est
  /// légitimement négatif.
  static String format(double price) => socle.formatPrice(price);
}

/// Voir [PriceFormatter.format].
String formatPrice(double price) => socle.formatPrice(price);
