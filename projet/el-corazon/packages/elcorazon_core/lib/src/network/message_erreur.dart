import 'package:elcorazon_core/src/network/api_exception.dart';

/// Traduit une erreur en une phrase destinée à quelqu'un, pas à un journal.
///
/// ## Pourquoi ce fichier est dans le socle
///
/// Les trois applications avaient le même défaut et l'ont corrigé une fois et
/// demie. `El Corazón Dely` s'est doté d'un `messageErreur` après avoir affiché
/// en plein service :
///
/// ```
/// Erreur lors de la mise à jour du statut:
/// ApiException(409, business_rule_violation, Votre dossier n'est pas validé…)
/// ```
///
/// Le client et le back-office, eux, affichaient encore `'Erreur : $e'` à dix-
/// sept endroits — un `DioException` ou un nom de classe Dart sous les yeux de
/// quelqu'un qui voulait chercher un plat ou valider un dossier. Le serveur
/// avait pourtant écrit la phrase à dire : le format RFC 9457 porte un `detail`
/// rédigé pour être lu (`backend/common/exceptions.py`), et l'application
/// l'enterrait sous sa propre plomberie.
///
/// La règle est donc unique et vit ici : **le `detail` du serveur est la phrase
/// à afficher quand il y en a une.** Le reste — panne réseau, session expirée,
/// serveur en vrac — n'en a pas et se nomme une fois, pour les trois.
///
/// Ce qui n'est **pas** ici : le `code`. C'est sur lui que le code raisonne
/// (ADR-009), jamais sur le message ; cette fonction ne fait que la traduction
/// inverse, vers l'écran.
///
/// ## Ce que chaque application ajoute
///
/// Les cas propres à un métier restent chez elle : une course prise par un
/// collègue chez le livreur, une adresse à rattacher à une session chez le
/// client. Elles enveloppent donc cette fonction au lieu de la remplacer, et
/// [repli] leur permet de nommer ce qu'elles n'ont pas su reconnaître.
///
/// [compteAttendu] nomme le type de compte de l'application — « livreur »,
/// « client », « administrateur ». Sans lui, les trois diraient la même phrase
/// vague à quelqu'un qui s'est simplement trompé d'application.
String messageErreurApi(
  Object erreur, {
  String? compteAttendu,
  String repli = 'Une erreur est survenue. Réessayez, et prévenez El Corazón si elle persiste.',
}) {
  if (erreur is ApiException) {
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
    // Le cas nominal : 400, 403, 404, 409 portent une phrase écrite pour la
    // personne qui la lira. C'est celle-là, et rien d'autre.
    return erreur.detail;
  }

  if (erreur is SessionExpiredException) {
    return 'Votre session a expiré. Reconnectez-vous.';
  }

  if (erreur is WrongAccountTypeException) {
    return compteAttendu == null
        ? 'Ce compte ne peut pas ouvrir cette application.'
        : 'Ce compte n\'est pas un compte $compteAttendu.';
  }

  return repli;
}
