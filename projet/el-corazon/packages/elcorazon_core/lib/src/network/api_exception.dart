/// Erreurs de l'API — miroir du format RFC 9457 servi par le backend
/// (`backend/common/exceptions.py`).
///
/// Le code appelant doit toujours raisonner sur [code], jamais sur [detail] :
/// les messages sont traduisibles et peuvent changer, les codes non
/// (ADR-009).
library;

/// Une erreur `application/problem+json` renvoyée par l'API.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.detail,
    this.errors = const {},
    this.members = const {},
  });

  /// **Aucune réponse** : serveur injoignable, délai dépassé, requête annulée
  /// par le navigateur (CORS, schéma manquant).
  ///
  /// Réservée à ce cas-là. Elle couvrait aussi, jusqu'ici, toute réponse dont
  /// le corps n'était pas du JSON — un 500 en page HTML de Django, un 502 de
  /// proxy. Le 2026-09-13, l'annuaire rendait **500 `ProgrammingError`** (une
  /// migration non appliquée) : l'application l'a rapporté en
  /// `network_error`, puis en « aucun restaurant en service ». Le serveur avait
  /// répondu ; on cherchait du côté du Wi-Fi. Voir [ApiException.unreadable].
  factory ApiException.network(String detail) => ApiException(
    status: 0,
    code: 'network_error',
    detail: detail,
  );

  /// Le serveur **a répondu**, avec un statut, mais sans corps `problem+json`
  /// lisible : page HTML d'erreur, proxy, corps vide.
  ///
  /// Le statut est conservé — c'est la seule information fiable qu'on ait, et
  /// c'est elle qui distingue « serveur en panne » (5xx) de « route absente »
  /// (404 d'un préfixe `/api/v1` oublié) ou d'un refus d'un intermédiaire.
  factory ApiException.unreadable(int status) => ApiException(
    status: status,
    code: status >= 500 ? 'server_error' : 'unreadable_response',
    detail: status >= 500
        ? 'Le serveur a rencontré une erreur ($status).'
        : 'Réponse inattendue du serveur ($status).',
  );

  factory ApiException.fromProblemDetail(int status, Map<String, dynamic> body) {
    final errors = body['errors'];
    return ApiException(
      status: status,
      code: (body['code'] as String?) ?? 'unknown_error',
      detail: (body['detail'] as String?) ?? detailParDefaut,
      errors: errors is Map
          ? errors.map(
              (key, value) => MapEntry(
                key.toString(),
                value is List ? value.map((v) => v.toString()).toList() : <String>[value.toString()],
              ),
            )
          : const {},
      members: Map.unmodifiable({
        for (final entree in body.entries)
          if (!_membresDuContrat.contains(entree.key)) entree.key: entree.value,
      }),
    );
  }

  /// Ce que vaut [detail] quand le serveur n'en a pas écrit.
  ///
  /// C'est le cas des refus de **validation** (400) : DRF range la raison
  /// champ par champ dans `errors` et ne pose aucun `detail`. Nommer ce repli
  /// permet à `messageErreurApi` de le reconnaître et d'aller lire [errors].
  static const detailParDefaut = 'Une erreur est survenue.';

  /// Membres définis par la RFC 9457 elle-même. Tout le reste est une extension
  /// posée par le serveur, et c'est cela que [members] recueille.
  static const Set<String> _membresDuContrat = {
    'type',
    'title',
    'status',
    'detail',
    'instance',
    'code',
    'errors',
  };

  final int status;
  final String code;
  final String detail;
  final Map<String, List<String>> errors;

  /// Membres d'extension du corps `problem+json`, hors champs du contrat.
  ///
  /// Le serveur en pose depuis l'origine — `current_status` et
  /// `allowed_transitions` sur une transition refusée, `verification_status`
  /// sur un dossier livreur, `missing` sur un établissement incomplet — et le
  /// client n'en lisait aucun : ils étaient perdus au décodage, si bien qu'une
  /// erreur qui disait précisément quoi faire arrivait à l'écran comme une
  /// phrase générique.
  ///
  /// Volontairement non typés : ce sont des données de diagnostic dont la forme
  /// dépend de l'erreur. L'appelant sait ce qu'il attend d'un code donné, et le
  /// lit avec [stringList] ou une conversion explicite.
  final Map<String, dynamic> members;

  /// Membre d'extension lu comme une liste de phrases, ou une liste vide.
  ///
  /// Absorbe les trois formes que peut prendre un membre absent, scalaire ou
  /// déjà en liste, plutôt que de laisser chaque appelant écrire le même
  /// `is List` défensif.
  List<String> stringList(String membre) {
    final valeur = members[membre];
    if (valeur is List) return valeur.map((v) => v.toString()).toList(growable: false);
    if (valeur == null) return const [];
    return [valeur.toString()];
  }

  bool get isThrottled => status == 429;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;

  /// Aucune réponse n'est arrivée. Seul cas où « vérifiez votre connexion » est
  /// un conseil juste.
  bool get isNetworkError => status == 0;

  /// Le serveur a répondu, et c'est lui qui est en défaut.
  bool get isServerError => status >= 500;

  @override
  String toString() => 'ApiException($status, $code, $detail)';
}

/// Le rafraîchissement de session a échoué — le refresh token est absent,
/// expiré ou déjà consommé (rotation côté serveur). L'appelant doit
/// déconnecter l'utilisateur, pas retenter.
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'SessionExpiredException($cause)';
}

/// Connexion ou session restaurée pour un type de compte que cette app
/// n'accepte pas (ex. un compte client qui tente d'ouvrir l'app livreur).
class WrongAccountTypeException implements Exception {
  const WrongAccountTypeException(this.actual, this.expected);

  final String actual;
  final String expected;

  @override
  String toString() => 'WrongAccountTypeException(actual: $actual, expected: $expected)';
}
