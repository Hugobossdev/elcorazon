/// Montant tel que rendu par `common.serializers.MoneyField` côté serveur —
/// `{"amount": "1250", "currency": "XOF"}`. `amount` voyage en chaîne (ADR-007) :
/// un client JavaScript convertirait un nombre en `double` et perdrait
/// l'exactitude défendue jusqu'en base ; ici on reparse en entier.
class Money {
  const Money({required this.amountMinor, required this.currency});

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      amountMinor: int.parse(json['amount'] as String),
      currency: json['currency'] as String,
    );
  }

  /// Forme attendue par `common.serializers.MoneyField.to_internal_value` —
  /// `amount` en unité mineure et en chaîne, comme à l'aller. Envoyer une
  /// unité majeure (`"12.50"`) est refusé côté serveur plutôt que converti en
  /// silence : c'est une erreur d'intégration, pas un arrondi à faire.
  Map<String, String> toJson() => {'amount': '$amountMinor', 'currency': currency};

  final int amountMinor;
  final String currency;

  /// Nombre de décimales par devise (`common/money.py`, `CURRENCY_EXPONENTS`) —
  /// seul un sous-ensemble utile aux devises déjà en service ici.
  static const _exponents = {
    'XOF': 0,
    'XAF': 0,
    'GNF': 0,
    'EUR': 2,
    'USD': 2,
    'GHS': 2,
    'NGN': 2,
  };

  /// Valeur en unité majeure (ex. 1250 XOF -> 1250.0, 1250 EUR -> 12.50) —
  /// pour l'affichage uniquement, jamais pour recalculer un total.
  double toMajorUnits() {
    final exponent = _exponents[currency] ?? 0;
    return amountMinor / _pow10(exponent);
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  String toString() => '$amountMinor $currency';
}
