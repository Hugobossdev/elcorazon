import 'package:elcorazon_core/elcorazon_core.dart' show Journal;
import 'package:shared_preferences/shared_preferences.dart';

/// Retient si la présentation d'ouverture a déjà été vue.
///
/// ## Pourquoi un drapeau, et pas un compte
///
/// La présentation précède la connexion : elle s'affiche avant qu'on sache
/// qui regarde. Le drapeau est donc **local à l'appareil**, comme il doit
/// l'être — un client qui réinstalle la reverra, un client qui change de
/// compte sur le même téléphone non. C'est le comportement attendu : elle
/// présente l'application, pas le compte.
///
/// ## Pourquoi ce n'est pas un `ChangeNotifier`
///
/// Personne n'a besoin d'être prévenu quand la valeur change : elle est lue
/// une fois, à l'ouverture, et écrite une fois, à la sortie de la
/// présentation. Un service à écoute pour cela ajouterait un `Provider` au
/// graphe et un abonnement à chaque écran, pour une valeur qui ne bouge
/// jamais pendant qu'on la regarde.
class OnboardingService {
  OnboardingService._();

  static const String _cle = 'onboarding_vu';

  /// Vrai quand la présentation a déjà été parcourue sur cet appareil.
  ///
  /// En cas d'échec de lecture — stockage indisponible, premier démarrage
  /// après une mise à jour du système — rend `true` plutôt que `false` : mieux
  /// vaut sauter une présentation qu'imposer trois écrans à quelqu'un qui les
  /// a déjà vus et veut commander.
  static Future<bool> dejaVue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_cle) ?? false;
    } catch (e) {
      Journal.trace('⚠️ Lecture du drapeau de présentation: $e');
      return true;
    }
  }

  /// Note que la présentation a été parcourue — ou passée, ce qui revient au
  /// même : dans les deux cas la personne a décidé de ne plus la voir.
  static Future<void> marquerVue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cle, true);
    } catch (e) {
      // Sans conséquence grave : la présentation reparaîtra au prochain
      // démarrage. La taire serait pire — on chercherait pourquoi.
      Journal.trace('⚠️ Écriture du drapeau de présentation: $e');
    }
  }

  /// Remet la présentation à zéro. Sert aux tests et au débogage.
  static Future<void> reinitialiser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cle);
    } catch (e) {
      Journal.trace('⚠️ Réinitialisation du drapeau de présentation: $e');
    }
  }
}
