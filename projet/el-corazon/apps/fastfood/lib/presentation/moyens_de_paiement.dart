import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/models/order.dart';

/// Les moyens de paiement que l'écran propose — ceux que le serveur accepte.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// La caisse désactivait en dur mobile money et carte (« bientôt ») pendant
/// que le panier collaboratif payait en mobile money et que le serveur
/// acceptait les quatre moyens : trois règles pour une seule plateforme. Le
/// serveur publie désormais la liste (`GET /payments/methods/`, réglage
/// `PAYMENT_METHODS`) et refuse le reste à la création. L'application la lit,
/// et n'en retient que la traduction vers ses icônes et ses descriptions.

/// Le moyen local qui correspond à un code du serveur, ou `null` s'il est
/// inconnu de cette version de l'application.
///
/// Inconnu, il n'est pas proposé : le rabattre sur un autre enverrait au
/// serveur un moyen que le client n'a pas choisi.
PaymentMethod? moyenDepuisServeur(String code) => switch (code) {
      'mobile_money' => PaymentMethod.mobileMoney,
      'card' => PaymentMethod.creditCard,
      'cash' => PaymentMethod.cash,
      'wallet' => PaymentMethod.wallet,
      _ => null,
    };

/// Un moyen proposé : ce que le serveur en dit, et sa traduction locale.
class MoyenPropose {
  const MoyenPropose({required this.moyen, required this.libelle});

  final PaymentMethod moyen;

  /// Le libellé **du serveur** — celui que le back-office et le livreur lisent.
  final String libelle;
}

/// Les moyens à proposer, dans l'ordre du serveur, sans ceux que cette version
/// ne sait pas représenter.
List<MoyenPropose> moyensProposes(List<eccore.AcceptedPaymentMethod> acceptes) {
  final proposes = <MoyenPropose>[];
  for (final accepte in acceptes) {
    final moyen = moyenDepuisServeur(accepte.code);
    if (moyen == null || proposes.any((p) => p.moyen == moyen)) continue;
    proposes.add(MoyenPropose(moyen: moyen, libelle: accepte.label));
  }
  return proposes;
}

/// Le moyen retenu une fois la liste connue : celui du client s'il est encore
/// accepté, sinon le premier proposé, sinon aucun — la caisse ne commande pas
/// sans moyen de paiement.
PaymentMethod? moyenRetenu(PaymentMethod? actuel, List<MoyenPropose> proposes) {
  if (actuel != null && proposes.any((p) => p.moyen == actuel)) return actuel;
  return proposes.isEmpty ? null : proposes.first.moyen;
}

/// Le moyen d'une commande de groupe : chaque convive y règle **sa** part en
/// ligne, donc mobile money, puis carte, s'ils sont acceptés. Faute de moyen
/// en ligne, le premier accepté — le serveur tranchera, et son refus sera
/// montré tel quel.
PaymentMethod? moyenPourLeGroupe(List<MoyenPropose> proposes) {
  for (final prefere in const [PaymentMethod.mobileMoney, PaymentMethod.creditCard]) {
    if (proposes.any((p) => p.moyen == prefere)) return prefere;
  }
  return proposes.isEmpty ? null : proposes.first.moyen;
}
