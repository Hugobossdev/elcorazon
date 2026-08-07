import 'package:elcorazon_core/elcorazon_core.dart' as socle;

/// Délégation vers la règle d'affichage des montants du socle.
///
/// Les trois applications portaient chacune la sienne, et elles ne rendaient
/// pas la même chose pour un même montant : « 12.500 CFA » ici et chez le
/// client, « 12 500 CFA » au back-office. La règle est désormais unique et
/// testée — `formatPrice()` / `Money.format()` dans `elcorazon_core`.
///
/// Ce fichier ne subsiste que pour laisser intacts les points d'appel qui
/// manipulent encore un `double`. Il disparaîtra au lot 3, quand les écrans
/// porteront des `Money` — voir `docs/refactoring-2026-08.md` §4.
class PriceFormatter {
  /// Formate un montant exprimé en **unité majeure** — 12500.0 pour
  /// 12 500 F CFA — en francs CFA, la seule devise que ces écrans affichent.
  ///
  /// Trois différences avec la version qu'elle remplace, toutes voulues : les
  /// milliers sont séparés par une espace insécable étroite et non par un
  /// point, un montant négatif garde son signe au lieu de rendre « -.500 CFA »,
  /// et `NaN` comme l'infini rendent « 0 CFA » au lieu de « NaN CFA ».
  static String format(double price) => socle.formatPrice(price);
}

/// Voir [PriceFormatter.format].
String formatPrice(double price) => socle.formatPrice(price);
