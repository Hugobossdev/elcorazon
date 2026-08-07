import 'package:flutter/foundation.dart';

/// Traces de mise au point — **muettes en production**.
///
/// Pourquoi ce journal existe
/// --------------------------
///
/// Les trois applications appelaient `debugPrint` : 663 fois au 7 août 2026.
/// Contrairement à `print`, que `avoid_print` interdit déjà, `debugPrint`
/// **s'exécute en production** — il écrit dans le journal système de l'appareil,
/// que n'importe quelle application outillée peut lire sur Android.
///
/// Or l'audit de ces 663 appels a trouvé des adresses de livraison complètes et
/// des coordonnées GPS de clients (`GeocodingService: Adresse géocodée -
/// $address -> $latLng`, dans les trois applications). Ce n'est pas une trace
/// de mise au point qu'on laisse traîner : c'est la position du domicile d'un
/// client, écrite en clair sur son téléphone et sur celui du livreur.
///
/// [trace] ferme cette fuite par construction : en dehors du mode debug, elle
/// ne fait rien du tout, et l'argument n'est même pas construit si l'appelant
/// passe par [traceDifferee].
///
/// Ce qu'il n'est pas
/// ------------------
///
/// Ni un collecteur d'erreurs, ni un journal applicatif persistant. Une erreur
/// qu'il faut voir en production doit remonter à un service de rapport
/// d'incidents, pas à `stdout` — c'est une décision d'outillage qui n'est pas
/// prise ici.
abstract final class Journal {
  /// Écrit [message] en mode debug, et rien ailleurs.
  ///
  /// Le seuil est `kDebugMode` et non `kReleaseMode` : un build de profilage
  /// sert à mesurer, et des écritures sur la sortie standard faussent la
  /// mesure autant qu'elles la polluent.
  static void trace(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  /// Comme [trace], mais ne construit le message que s'il va être écrit.
  ///
  /// À réserver aux traces dont la composition coûte — sérialiser une réponse,
  /// parcourir une liste. Pour une chaîne interpolée ordinaire, [trace] suffit
  /// et se lit mieux.
  static void traceDifferee(String Function() message) {
    if (!kDebugMode) return;
    debugPrint(message());
  }
}
