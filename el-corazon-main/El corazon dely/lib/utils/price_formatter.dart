class PriceFormatter {
  static String format(double price) {
    // Formatage en franc CFA avec séparateur de milliers
    final priceString = price.toStringAsFixed(0);
    final parts = <String>[];
    
    // Diviser le prix en groupes de 3 chiffres
    for (int i = priceString.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, priceString.substring(start, i));
    }
    
    return '${parts.join('.')} CFA';
  }
}

String formatPrice(double price) {
  return PriceFormatter.format(price);
}