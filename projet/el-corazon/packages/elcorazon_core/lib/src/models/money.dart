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

  /// Montant **saisi par un humain** dans un formulaire du back-office —
  /// « 12,50 » en euros, « 1250 » en francs CFA.
  ///
  /// C'est le seul sens de conversion qu'une application a le droit de faire :
  /// transformer une saisie en unité mineure avant de l'envoyer. Le serveur
  /// n'accepte que l'unité mineure (ADR-007) et refuse « 12.50 » plutôt que de
  /// deviner l'échelle.
  ///
  /// L'arrondi est explicite parce qu'un `double` ne représente pas 12,50 :
  /// `12.50 * 100` vaut 1249,999… en virgule flottante, et une troncature
  /// silencieuse ferait perdre un centime à chaque enregistrement.
  factory Money.fromMajorUnits(double amount, String currency) {
    final exponent = _exponents[currency] ?? 0;
    return Money(
      amountMinor: (amount * _pow10(exponent)).round(),
      currency: currency,
    );
  }

  static int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// Libellé affiché à la place du code ISO, quand l'usage en impose un.
  ///
  /// Personne en zone franc n'écrit « 1 500 XOF » : on écrit « 1 500 CFA ». Les
  /// devises absentes de cette table gardent leur code — c'est délibéré,
  /// inventer un symbole pour une devise qu'on ne sert pas encore serait pire
  /// que de rendre `NGN`.
  static const _symboles = {'XOF': 'CFA', 'XAF': 'CFA'};

  /// Montant tel qu'on le montre à un humain : « 12 500 CFA », « 12,50 EUR ».
  ///
  /// Espace fine insécable entre les groupes de milliers, virgule décimale —
  /// les conventions françaises, qui sont celles de tous les libellés du
  /// projet. Le nombre de décimales vient de la devise, pas d'un choix
  /// d'affichage : un montant en francs CFA n'a pas de centimes, en afficher
  /// deux laisserait croire à une précision qui n'existe pas.
  ///
  /// **Les montants négatifs sont rendus tels quels** (« -1 500 CFA »). Les
  /// trois formateurs d'application que cette méthode remplace les
  /// écrasaient à zéro ou produisaient « -.500 CFA » ; or un avoir, un
  /// remboursement ou un ajustement sont légitimement négatifs, et masquer un
  /// signe sur un montant est la dernière chose qu'une interface doive faire.
  String format() => formatPrice(toMajorUnits(), currency: currency);

  @override
  String toString() => '$amountMinor $currency';
}

/// Sépare les milliers par une espace insécable étroite (U+202F).
///
/// Une espace ordinaire autoriserait un retour à la ligne au milieu d'un
/// montant — « 12 » en fin de ligne et « 500 CFA » au début de la suivante.
const _separateurMilliers = ' ';

/// Formate un montant **en unité majeure** — 1250.0 pour 1 250 F CFA.
///
/// C'est la porte d'entrée des appelants qui manipulent encore un `double`,
/// c'est-à-dire tout ce qui n'a pas migré vers [Money]. Les trois applications
/// avaient chacune la leur, et elles ne rendaient pas la même chose : le client
/// et le livreur écrivaient « 12.500 CFA » avec un point, le back-office
/// « 12 500 CFA » avec une espace. Une même commande s'affichait donc de deux
/// façons selon l'écran qui la montrait.
///
/// `NaN` et l'infini rendent « 0 » suivi de la devise : ils ne représentent
/// aucun montant, et il n'y a rien de mieux à écrire. C'est le seul cas où
/// cette fonction substitue une valeur.
String formatPrice(double amount, {String currency = 'XOF'}) {
  final symbole = Money._symboles[currency] ?? currency;
  if (amount.isNaN || amount.isInfinite) return '0 $symbole';

  final exposant = Money._exponents[currency] ?? 0;
  final facteur = Money._pow10(exposant);

  // Passage par l'unité mineure avant tout découpage : `12.505` en euros doit
  // devenir « 12,51 », pas « 12,50 » — arrondir d'abord, découper ensuite.
  final mineur = (amount * facteur).round();
  final negatif = mineur < 0;
  final absolu = mineur.abs();

  final entier = (absolu ~/ facteur).toString();
  final tampon = StringBuffer();
  for (var i = 0; i < entier.length; i++) {
    if (i > 0 && (entier.length - i) % 3 == 0) tampon.write(_separateurMilliers);
    tampon.write(entier[i]);
  }

  final signe = negatif ? '-' : '';
  if (exposant == 0) return '$signe$tampon $symbole';

  final decimales = (absolu % facteur).toString().padLeft(exposant, '0');
  return '$signe$tampon,$decimales $symbole';
}
