import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage du compte connecté.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// `models/user.dart` recopiait `eccore.User` en plus étroit, et le traduisait
/// dans `AppService._fromDjangoUser`. La traduction inventait plus qu'elle ne
/// convertissait :
///
/// * `role` était écrit **en dur** à `UserRole.client`, une énumération qui ne
///   comptait qu'une seule valeur. Le serveur rend pourtant un `user_type`
///   réel (`customer` | `courier` | `staff`) ;
/// * `loyaltyPoints` et `badges` gardaient leur valeur par défaut — zéro et
///   liste vide. L'écran de profil affichait donc « 0 pts » à tout le monde,
///   une barre de progression toujours à zéro et jamais aucun badge, alors que
///   `GamificationService` tient le vrai solde depuis le socle ;
/// * `preferences` n'était lu nulle part.
extension ProfilAffiche on eccore.User {
  /// Le type de compte, dans les mots de l'application.
  String get libelleDuType {
    switch (userType) {
      case eccore.UserAccountType.customer:
        return 'Client';
      case eccore.UserAccountType.courier:
        return 'Livreur';
      case eccore.UserAccountType.staff:
        return 'Personnel';
      default:
        return 'Compte';
    }
  }

  /// La pastille du type de compte.
  String get pastilleDuType {
    switch (userType) {
      case eccore.UserAccountType.courier:
        return '🛵';
      case eccore.UserAccountType.staff:
        return '🧑‍🍳';
      default:
        return '🍔';
    }
  }

  /// Vrai pour un compte client — le seul que cette application sert.
  bool get estClient => userType == eccore.UserAccountType.customer;

  /// Les initiales, pour l'avatar de repli.
  String get initiales {
    final nom = fullName.trim();
    if (nom.isEmpty) return '?';
    return nom.length < 2 ? nom.toUpperCase() : nom.substring(0, 2).toUpperCase();
  }
}

/// Le palier de fidélité affiché sur le profil.
///
/// L'ancienne version testait aussi un badge nommé `loyal_customer`. Ce code
/// n'existe pas côté serveur — les badges rendus portent `id`, `title`,
/// `description`, `icon`, `target`, `isUnlocked` — et le test ne pouvait donc
/// jamais être vrai. Restent les seuils, qui eux fonctionnent dès que les
/// points viennent de la bonne source.
String palierDeFidelite(int points) {
  if (points >= 500) return 'VIP';
  if (points >= 200) return 'Fidèle';
  return 'Standard';
}
