import 'package:flutter/material.dart';

/// Tokens de couleurs sémantiques pour l'admin.
///
/// Objectif: éviter `Colors.*` dans l'UI et rester cohérent avec le `ColorScheme`
/// (light/dark) défini par `ModernTheme`.
class AdminColorTokens {
  AdminColorTokens._();

  static AdminSemanticColors semantic(ColorScheme scheme) =>
      AdminSemanticColors._(scheme);
}

class AdminSemanticColors {
  final ColorScheme _scheme;

  const AdminSemanticColors._(this._scheme);

  /// Couleurs "état" (KPI, badges, statuts).
  Color get success => _scheme.secondary;
  Color get warning => _scheme.tertiary;
  Color get info => _scheme.primary;
  Color get danger => _scheme.error;

  /// Couleurs neutres (surfaces, bordures, shadows).
  Color get border => _scheme.outline.withValues(alpha: 0.35);
  Color get borderSubtle => _scheme.outline.withValues(alpha: 0.18);
  Color get shadow => _scheme.shadow.withValues(alpha: 0.10);
}


