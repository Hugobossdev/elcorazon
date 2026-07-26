/// Utilitaire pour formater les prix en Franc CFA
class PriceFormatter {
  /// Formate un prix en Franc CFA avec séparateur de milliers
  /// 
  /// Exemples:
  /// - 1000 -> "1 000 CFA"
  /// - 5000 -> "5 000 CFA"
  /// - 12500 -> "12 500 CFA"
  /// - 150000 -> "150 000 CFA"
  static String format(double price) {
    // Gérer les valeurs invalides
    if (price.isNaN || price.isInfinite || price < 0) {
      return '0 CFA';
    }
    
    // Arrondir à l'entier le plus proche
    final priceInt = price.round();
    
    // Convertir en string et ajouter les séparateurs de milliers
    final priceString = priceInt.toString();
    final buffer = StringBuffer();
    
    // Ajouter les chiffres avec séparateur de milliers (espace)
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(priceString[i]);
    }
    
    return '${buffer.toString()} CFA';
  }
  
  /// Formate un prix avec 2 décimales (pour les montants précis)
  /// 
  /// Exemples:
  /// - 1000.50 -> "1 000,50 CFA"
  /// - 5000.25 -> "5 000,25 CFA"
  static String formatWithDecimals(double price) {
    // Gérer les valeurs invalides
    if (price.isNaN || price.isInfinite || price < 0) {
      return '0,00 CFA';
    }
    
    // Séparer la partie entière et décimale
    final priceInt = price.floor();
    final decimals = ((price - priceInt) * 100).round();
    
    // Formater la partie entière avec séparateur de milliers
    final intString = priceInt.toString();
    final buffer = StringBuffer();
    
    for (int i = 0; i < intString.length; i++) {
      if (i > 0 && (intString.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(intString[i]);
    }
    
    // Ajouter les décimales (format français avec virgule)
    return '${buffer.toString()},${decimals.toString().padLeft(2, '0')} CFA';
  }
}

/// Fonction helper pour formater un prix en CFA
String formatPrice(double price) {
  return PriceFormatter.format(price);
}

/// Fonction helper pour formater un prix avec décimales en CFA
String formatPriceWithDecimals(double price) {
  return PriceFormatter.formatWithDecimals(price);
}