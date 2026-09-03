/// Ce que le serveur répond après avoir émis (ou refusé d'émettre) un code —
/// miroir de `VerificationChallengeSerializer`
/// (`backend/apps/accounts/serializers.py`).
///
/// [retryAfter] et [expiresAt] viennent du serveur, jamais d'une constante
/// locale : ce sont les réglages qui gouvernent réellement l'émission
/// (`ACCOUNT_VERIFICATION_*`). Un compte à rebours qui les devinerait finirait
/// par proposer « Renvoyer » à un moment où le serveur refuse encore, et
/// l'écran afficherait alors une erreur pour un geste qu'il venait lui-même
/// d'autoriser.
///
/// Rien ici ne dit si l'adresse correspond à un compte : la réponse est
/// volontairement identique dans les deux cas (voir `ResendVerificationView`).
class VerificationChallenge {
  const VerificationChallenge({
    required this.email,
    required this.expiresAt,
    required this.retryAfter,
    required this.codeLength,
    required this.detail,
  });

  factory VerificationChallenge.fromJson(Map<String, dynamic> json) {
    return VerificationChallenge(
      email: json['email'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      retryAfter: json['retry_after'] as int,
      codeLength: json['code_length'] as int,
      detail: json['detail'] as String? ?? '',
    );
  }

  /// Adresse à laquelle le code a été adressé — celle que l'écran affiche.
  final String email;

  /// Instant après lequel le code ne vaut plus rien.
  final DateTime expiresAt;

  /// Secondes à attendre avant qu'un renvoi soit accepté.
  final int retryAfter;

  /// Nombre de chiffres attendus — la grille de saisie s'y adapte plutôt que
  /// de figer six cases.
  final int codeLength;

  /// Phrase rédigée par le serveur, à afficher telle quelle.
  final String detail;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
