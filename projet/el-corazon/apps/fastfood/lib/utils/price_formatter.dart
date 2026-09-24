import 'package:elcorazon_core/elcorazon_core.dart' as socle;

import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Délégation vers la règle d'affichage des montants du socle.
///
/// Les trois applications portaient chacune la sienne, et elles ne rendaient
/// pas la même chose pour un même montant : « 12.500 CFA » ici et chez le
/// livreur, « 12 500 CFA » au back-office. La règle est désormais unique et
/// testée — `formatPrice()` / `Money.format()` dans `elcorazon_core`.
///
/// Ce fichier ne subsiste que pour laisser intacts les points d'appel qui
/// manipulent encore un `double`. Il disparaîtra au lot 3, quand les écrans
/// porteront des `Money` — voir `docs/refactoring-2026-08.md` §4.
class PriceFormatter {
  /// Formate un montant exprimé en **unité majeure** — 12500.0 pour
  /// 12 500 F CFA.
  ///
  /// La devise est [devise] quand l'appelant la connaît (celle d'une
  /// commande), sinon celle de l'établissement courant, que le serveur rend
  /// (`KitchenContextService.currency`). Elle était jusqu'ici implicite : le
  /// socle retombait sur le franc CFA, et un établissement d'Accra affichait
  /// ses prix en « CFA ».
  ///
  /// Devise encore inconnue — l'annuaire n'a pas répondu : le nombre seul,
  /// sans unité, plutôt qu'une unité devinée.
  static String format(double price, {String? devise}) {
    final code = (devise != null && devise.isNotEmpty)
        ? devise
        : (KitchenContextService().currency ?? '');
    if (code.isEmpty) return socle.formatPrice(price, currency: '').trim();
    return socle.formatPrice(price, currency: code);
  }
}

/// Voir [PriceFormatter.format].
String formatPrice(double price, {String? devise}) =>
    PriceFormatter.format(price, devise: devise);
