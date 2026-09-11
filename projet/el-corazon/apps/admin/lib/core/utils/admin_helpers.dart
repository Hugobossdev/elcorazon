import 'package:intl/intl.dart';
import 'package:admin/core/constants/admin_constants.dart';

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

  /// Formate un ID de commande (affiche les 8 premiers caractères)
  static String formatOrderId(String id) {
    if (id.length <= 8) return id.toUpperCase();
    return id.substring(0, 8).toUpperCase();
  }

  /// Formate un pourcentage
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formate un nombre avec séparateurs de milliers
  static String formatNumber(int number) {
    return NumberFormat('#,###', 'fr_FR').format(number);
  }

  // =====================================================
  // VALIDATION
  // =====================================================

  /// Valide un email
  static bool isValidEmail(String email) {
    return RegExp(AdminConstants.emailPattern).hasMatch(email.trim());
  }

  /// Valide un numéro de téléphone
  static bool isValidPhone(String phone) {
    return RegExp(AdminConstants.phonePattern).hasMatch(phone.trim());
  }

  /// Valide une URL
  static bool isValidUrl(String url) {
    return RegExp(AdminConstants.urlPattern).hasMatch(url.trim());
  }

  /// Valide un prix
  static bool isValidPrice(double price) {
    return price >= AdminConstants.minPrice &&
        price <= AdminConstants.maxPrice;
  }

  /// Valide un mot de passe
  static bool isValidPassword(String password) {
    return password.length >= AdminConstants.minPasswordLength &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  /// Valide un nom (non vide, longueur max)
  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= AdminConstants.maxNameLength;
  }

  // =====================================================
  // CALCULATIONS
  // =====================================================

  /// Calcule le pourcentage de variation
  static double calculatePercentageChange(
      double oldValue, double newValue,) {
    if (oldValue == 0) return newValue > 0 ? 100 : 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  /// Calcule la valeur moyenne d'une liste
  static double calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Arrondit un nombre à N décimales
  static double roundToDecimals(double value, int decimals) {
    final factor = 10.0 * decimals;
    return (value * factor).round() / factor;
  }

  // =====================================================
  // DATE UTILITIES
  // =====================================================

  /// Vérifie si une date est aujourd'hui
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Vérifie si une date est cette semaine
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }

  /// Vérifie si une date est ce mois
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// Vérifie si une date est cette année
  static bool isThisYear(DateTime date) {
    return date.year == DateTime.now().year;
  }

  /// Obtient le début du jour
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Obtient la fin du jour
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  // =====================================================
  // STRING UTILITIES
  // =====================================================

  /// Tronque un texte avec ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Capitalise la première lettre
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Formate un nom propre (capitalise chaque mot)
  static String formatProperName(String name) {
    return name.split(' ').map((word) => capitalize(word)).join(' ');
  }

  /// Masque un email (affiche seulement le début et la fin)
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final domain = parts[1];
    if (username.length <= 2) return email;
    final visible = username.substring(0, 2);
    final hidden = '*' * (username.length - 2);
    return '$visible$hidden@$domain';
  }

  // =====================================================
  // FILE UTILITIES
  // =====================================================

  /// Formate la taille d'un fichier
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Obtient l'extension d'un fichier
  static String getFileExtension(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  /// Vérifie si un fichier est une image
  static bool isImageFile(String filename) {
    final ext = getFileExtension(filename);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext);
  }

  // =====================================================
  // COLOR UTILITIES
  // =====================================================

  /// Convertit une couleur hex en int
  static int hexToInt(String hex) {
    return int.parse(hex.replaceAll('#', ''), radix: 16);
  }

  /// Obtient une couleur basée sur un pourcentage (rouge à vert)
  static int getPercentageColor(double percentage) {
    if (percentage >= 80) return 0xFF4CAF50; // Vert
    if (percentage >= 50) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Rouge
  }
}

/// Extension pour DateTime avec des méthodes helper
extension DateTimeExtension on DateTime {
  bool get isToday => AdminHelpers.isToday(this);
  bool get isThisWeek => AdminHelpers.isThisWeek(this);
  bool get isThisMonth => AdminHelpers.isThisMonth(this);
  bool get isThisYear => AdminHelpers.isThisYear(this);
  DateTime get startOfDay => AdminHelpers.startOfDay(this);
  DateTime get endOfDay => AdminHelpers.endOfDay(this);
}
