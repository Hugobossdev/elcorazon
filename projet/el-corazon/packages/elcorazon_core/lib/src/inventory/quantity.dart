/// Quantité de matière — miroir de `QuantityField`
/// (`backend/common/serializers.py`) : `{"amount": "1500", "unit": "g"}`.
///
/// ## Pourquoi une chaîne, et jamais un `double`
///
/// Pour la raison qui fait voyager les montants en chaîne (ADR-007) : un
/// `double` ne représente pas `0.1` exactement, et le serveur a précisément été
/// écrit pour que la matière ne dérive pas au dernier mètre. Cette classe ne
/// calcule donc **rien** — ni somme, ni conversion qui servirait à écrire. Elle
/// transporte ce que le serveur rend, et met en forme ce qu'un écran affiche.
///
/// Le serveur rend toujours l'**unité de référence** (`g`, `ml`, `unit`) ; la
/// saisie, elle, se fait dans l'unité du geste — on reçoit en kilogrammes.
class Quantity {
  const Quantity({required this.amount, required this.unit, this.dimension = ''});

  factory Quantity.fromJson(Map<String, dynamic> json) {
    return Quantity(
      amount: json['amount'].toString(),
      unit: json['unit'] as String,
      dimension: json['dimension'] as String? ?? '',
    );
  }

  /// Construit une quantité depuis une saisie : « 1,5 » en `kg`.
  ///
  /// La virgule est acceptée — c'est celle qu'on tape sur un clavier français.
  /// Tout ce qui n'est pas un nombre décimal lève [FormatException] **avant**
  /// l'envoi : le serveur refuserait de toute façon, mais l'écran doit pouvoir
  /// le dire sous le champ plutôt que dans un bandeau d'erreur réseau.
  factory Quantity.saisie(String texte, String unit) {
    final normalise = texte.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (!_decimal.hasMatch(normalise)) {
      throw FormatException('« $texte » n’est pas une quantité.', texte);
    }
    if (!unitsByDimension.values.any((unites) => unites.contains(unit))) {
      throw FormatException('Unité inconnue : $unit.', unit);
    }
    return Quantity(amount: normalise, unit: unit);
  }

  static final _decimal = RegExp(r'^-?\d+(\.\d+)?$');

  /// Unités saisissables par dimension, de la plus petite à la plus grande —
  /// la table du serveur (`UNITS_IN_BASE`), sans le milligramme, qu'on ne pèse
  /// pas en cuisine.
  static const unitsByDimension = {
    'mass': ['g', 'kg'],
    'volume': ['ml', 'cl', 'l'],
    'count': ['unit'],
  };

  /// Valeur décimale exacte, en chaîne.
  final String amount;

  /// `g`, `kg`, `ml`, `cl`, `l` ou `unit`.
  final String unit;

  /// `mass`, `volume` ou `count` — rendu par le serveur, vide sur une saisie.
  final String dimension;

  Map<String, dynamic> toJson() => {'amount': amount, 'unit': unit};

  bool get isNegative => amount.startsWith('-');

  bool get isZero => RegExp(r'^-?0+(\.0+)?$').hasMatch(amount);

  /// « 1,5 kg », « 250 g », « 12 unités » — pour l'affichage seul.
  ///
  /// Au-delà de mille grammes ou millilitres, l'écran lit des kilogrammes ou
  /// des litres : « 12 500 g » se relit mal à un mètre, et c'est la distance à
  /// laquelle un magasinier regarde une étagère. Le passage se fait en décalant
  /// la virgule dans la chaîne, sans flottant.
  String get label {
    var valeur = amount;
    var unite = unit;

    if ((unit == 'g' || unit == 'ml') && _partieEntiere(amount).length > 3) {
      valeur = _decalerAGauche(amount, 3);
      unite = unit == 'g' ? 'kg' : 'l';
    }

    final texte = _normaliser(valeur).replaceAll('.', ',');
    if (unite == 'unit') {
      final pluriel = texte.replaceAll('-', '') != '1';
      return '$texte ${pluriel ? 'unités' : 'unité'}';
    }
    return '$texte $unite';
  }

  static String _partieEntiere(String decimal) =>
      decimal.replaceAll('-', '').split('.').first;

  /// Divise par 10^[rangs] en déplaçant la virgule — exact, sans flottant.
  static String _decalerAGauche(String decimal, int rangs) {
    final negatif = decimal.startsWith('-');
    final brut = decimal.replaceAll('-', '');
    final morceaux = brut.split('.');
    final entier = morceaux.first.padLeft(rangs + 1, '0');
    final fraction = morceaux.length > 1 ? morceaux[1] : '';
    final coupure = entier.length - rangs;
    final resultat = '${entier.substring(0, coupure)}.${entier.substring(coupure)}$fraction';
    return '${negatif ? '-' : ''}$resultat';
  }

  /// Retire les zéros inutiles : « 1.500 » → « 1.5 », « 2.000 » → « 2 ».
  static String _normaliser(String decimal) {
    if (!decimal.contains('.')) return decimal;
    var texte = decimal.replaceFirst(RegExp(r'0+$'), '');
    if (texte.endsWith('.')) texte = texte.substring(0, texte.length - 1);
    return texte == '-0' ? '0' : texte;
  }

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => label;
}
