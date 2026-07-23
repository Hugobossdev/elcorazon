/// Exception levée par [ApiClient] lorsqu'une requête échoue (réseau ou
/// réponse HTTP non 2xx). Contient le message et les erreurs de validation
/// renvoyés par l'API Laravel.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.errors,
  });

  /// Message lisible (issu de `message` de la réponse Laravel si présent).
  final String message;

  /// Code HTTP (null pour une erreur réseau/parse).
  final int? statusCode;

  /// Erreurs de validation Laravel : { champ: [messages] }.
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Premier message d'erreur de validation, s'il existe.
  String? get firstValidationError {
    if (errors == null || errors!.isEmpty) return null;
    final first = errors!.values.first;
    return first.isNotEmpty ? first.first : null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
