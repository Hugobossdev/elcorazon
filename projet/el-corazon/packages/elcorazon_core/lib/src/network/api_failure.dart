import 'dart:async';

import 'package:elcorazon_core/src/network/api_exception.dart';

/// **De quelle nature est cet échec ?** — la question qu'on doit se poser avant
/// d'en tirer une conclusion métier.
///
/// ## Le défaut que cette classification ferme
///
/// L'application cliente a affiché « Aucun restaurant n'est en service » pour
/// trois pannes qui n'avaient rien à voir avec l'absence de cuisine : un
/// serveur injoignable, un 500 de l'annuaire, et un chargement encore en
/// cours. Chaque fois, un échec avait été rattrapé puis réduit à « la liste est
/// vide » — et une liste vide se lit « personne ne vous livre ».
///
/// Une panne n'est jamais une réponse métier. Distinguer ces natures au même
/// endroit pour les trois applications est ce qui permet à chaque écran de dire
/// le bon geste : réessayer, se reconnecter, prévenir El Corazón — ou, quand le
/// serveur a **réellement répondu** « personne ici », attendre qu'une cuisine
/// ouvre dans le quartier.
enum ApiFailure {
  /// Aucune réponse : serveur injoignable, délai, requête bloquée (CORS).
  network,

  /// 401 — session absente ou expirée.
  authentication,

  /// 403 — la session est valide, le droit manque.
  authorization,

  /// 404 — la ressource n'existe pas (ou plus).
  notFound,

  /// 429 — trop de demandes.
  throttled,

  /// 4xx argumenté — le serveur a refusé, et dit pourquoi.
  rejected,

  /// 5xx — le serveur a répondu, et c'est lui qui est en défaut.
  server,

  /// Une réponse est arrivée, mais ne correspond pas au contrat : JSON d'une
  /// autre forme, champ manquant, type inattendu.
  invalidResponse,

  /// Rien de ce qui précède — une erreur de programmation, le plus souvent.
  unknown;

  /// Classe un échec, quelle que soit sa forme.
  ///
  /// `FormatException` et `TypeError` sont rangées en [invalidResponse] : c'est
  /// ce que lèvent `jsonDecode` et un `as String` sur un champ absent, et un
  /// décodage raté signifie que le serveur a répondu autre chose que ce que
  /// l'application sait lire — pas qu'il n'y a rien à lire.
  static ApiFailure of(Object erreur) {
    if (erreur is ApiException) {
      if (erreur.isNetworkError) return ApiFailure.network;
      if (erreur.isUnauthorized) return ApiFailure.authentication;
      if (erreur.isForbidden) return ApiFailure.authorization;
      if (erreur.status == 404) return ApiFailure.notFound;
      if (erreur.isThrottled) return ApiFailure.throttled;
      if (erreur.isServerError) return ApiFailure.server;
      if (erreur.code == 'unreadable_response') return ApiFailure.invalidResponse;
      return ApiFailure.rejected;
    }
    if (erreur is SessionExpiredException) return ApiFailure.authentication;
    if (erreur is TimeoutException) return ApiFailure.network;
    if (erreur is FormatException || erreur is TypeError) {
      return ApiFailure.invalidResponse;
    }
    return ApiFailure.unknown;
  }

  /// Code stable, pour les journaux et les écrans qui comparent.
  String get code => switch (this) {
    ApiFailure.network => 'NETWORK_ERROR',
    ApiFailure.authentication => 'AUTHENTICATION_ERROR',
    ApiFailure.authorization => 'AUTHORIZATION_ERROR',
    ApiFailure.notFound => 'NOT_FOUND',
    ApiFailure.throttled => 'THROTTLED',
    ApiFailure.rejected => 'API_ERROR',
    ApiFailure.server => 'SERVER_ERROR',
    ApiFailure.invalidResponse => 'INVALID_RESPONSE',
    ApiFailure.unknown => 'UNKNOWN_ERROR',
  };

  /// Réessayer à l'identique peut-il aboutir ? Vrai pour les pannes, faux pour
  /// les refus : un 403 rejoué rend un 403.
  bool get isTransient => switch (this) {
    ApiFailure.network || ApiFailure.server || ApiFailure.throttled => true,
    _ => false,
  };
}
