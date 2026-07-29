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
  });

  /// Réponse qui n'est pas au format `problem+json` (panne réseau, timeout,
  /// erreur 5xx sans corps exploitable, HTML d'un proxy...).
  factory ApiException.network(String detail) => ApiException(
    status: 0,
    code: 'network_error',
    detail: detail,
  );

  factory ApiException.fromProblemDetail(int status, Map<String, dynamic> body) {
    final errors = body['errors'];
    return ApiException(
      status: status,
      code: (body['code'] as String?) ?? 'unknown_error',
      detail: (body['detail'] as String?) ?? 'Une erreur est survenue.',
      errors: errors is Map
          ? errors.map(
              (key, value) => MapEntry(
                key.toString(),
                value is List ? value.map((v) => v.toString()).toList() : <String>[value.toString()],
              ),
            )
          : const {},
    );
  }

  final int status;
  final String code;
  final String detail;
  final Map<String, List<String>> errors;

  bool get isThrottled => status == 429;
  bool get isUnauthorized => status == 401;

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
