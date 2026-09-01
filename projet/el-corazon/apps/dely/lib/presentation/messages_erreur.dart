import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce qu'on dit au livreur quand une action échoue.
///
/// ## Pourquoi ce fichier existe
///
/// Dix-sept endroits interpolaient l'exception brute dans un message :
/// `Text('Erreur lors de la mise à jour du statut: $e')`. Le livreur lisait
/// donc, en plein service :
///
/// ```
/// Erreur lors de la mise à jour du statut:
/// ApiException(409, business_rule_violation, Votre dossier n'est pas
/// validé ; vous ne pouvez pas encore recevoir de courses.)
/// ```
///
/// Le serveur avait pourtant écrit exactement la phrase qu'il fallait lui
/// dire — le format RFC 9457 porte un `detail` rédigé pour être affiché
/// (`backend/common/exceptions.py`) — et l'application l'enterrait sous le nom
/// de sa propre classe et un code technique. Sur `AppService.loginDriver`,
/// l'emballage était double : `Exception: Erreur de connexion:
/// ApiException(401, invalid_credentials, ...)`.
///
/// ## La règle
///
/// Le `detail` du serveur est **la** phrase à afficher quand il y en a une. Le
/// reste — panne réseau, session expirée, liste périmée — n'a pas de detail
/// serveur et se nomme ici, une fois.
///
/// Ce qui n'est **pas** ici : le `code`. C'est sur lui que le code raisonne
/// (ADR-009), jamais sur le message ; ce fichier ne fait que la traduction
/// inverse, vers l'écran.
String messageErreur(Object erreur) {
  if (erreur is eccore.ApiException) {
    // Un échec de transport n'a pas de `detail` utile : le serveur n'a rien
    // répondu. Le distinguer, parce que le geste attendu n'est pas le même —
    // réessayer plus tard plutôt que corriger quelque chose.
    if (erreur.status == 0) {
      return 'Pas de connexion au serveur. Vérifiez votre réseau, puis réessayez.';
    }
    if (erreur.isUnauthorized) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (erreur.isThrottled) {
      return 'Trop de demandes d\'affilée. Patientez quelques secondes.';
    }
    if (erreur.status >= 500) {
      return 'Le serveur ne répond pas correctement. Réessayez dans un instant.';
    }
    // Le cas nominal : 400, 403, 404, 409 portent une phrase écrite pour le
    // livreur. C'est celle-là, et rien d'autre, qu'il doit lire.
    return erreur.detail;
  }

  if (erreur is eccore.SessionExpiredException) {
    return 'Votre session a expiré. Reconnectez-vous.';
  }

  if (erreur is eccore.WrongAccountTypeException) {
    return 'Ce compte n\'est pas un compte livreur.';
  }

  // `AppService._requireCourse` lève ceci quand un écran travaille sur une
  // liste périmée — une course qu'un collègue a prise entre-temps, par
  // exemple. Le geste utile est de recharger, pas de réessayer.
  if (erreur is StateError) {
    return 'Cette course n\'est plus dans votre liste. Rafraîchissez l\'écran.';
  }

  return 'Une erreur est survenue. Réessayez, et prévenez El Corazón si elle persiste.';
}
