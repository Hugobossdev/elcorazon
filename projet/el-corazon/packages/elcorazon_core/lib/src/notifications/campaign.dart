/// Segments adressables par une campagne — valeurs d'`Audience` côté serveur.
///
/// Volontairement **fermé** : « les clients qui n'ont pas commandé depuis
/// trente jours » est une requête que le serveur sait écrire, pas un filtre
/// libre que le client compose. Un ciblage arbitraire depuis un écran
/// reviendrait à laisser choisir qui reçoit un message de masse à partir de
/// critères que personne n'a relus.
abstract final class CampaignAudience {
  static const allCustomers = 'all_customers';
  static const couriers = 'couriers';
  static const activeCustomers = 'active_customers';
  static const lapsedCustomers = 'lapsed_customers';

  static const values = [
    allCustomers,
    couriers,
    activeCustomers,
    lapsedCustomers,
  ];
}

abstract final class CampaignStatus {
  static const draft = 'draft';
  static const sent = 'sent';
}

/// Envoi de masse préparé, tracé, et qui ne part qu'une fois — miroir de
/// `CampaignSerializer`.
///
/// Trois champs viennent du serveur seul : [status], [sentAt] et
/// [recipientCount]. Les rendre inscriptibles permettrait de marquer
/// « envoyée » une campagne jamais partie, ou d'annoncer un nombre de
/// destinataires que personne n'a reçus.
class Campaign {
  const Campaign({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.audienceLabel,
    required this.segmentDays,
    required this.status,
    required this.recipientCount,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
    this.createdByEmail,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      audience: json['audience'] as String,
      audienceLabel: json['audience_label'] as String? ?? '',
      segmentDays: json['segment_days'] as int? ?? 30,
      status: json['status'] as String,
      sentAt: json['sent_at'] == null
          ? null
          : DateTime.parse(json['sent_at'] as String),
      recipientCount: json['recipient_count'] as int? ?? 0,
      createdByEmail: json['created_by_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String title;
  final String body;
  final String audience;

  /// Libellé du segment, rendu par le serveur — l'écran ne le traduit pas
  /// lui-même, sans quoi un segment ajouté côté serveur s'afficherait par son
  /// code technique.
  final String audienceLabel;

  /// Fenêtre des segments « récemment » et « sans commande récente ».
  final int segmentDays;
  final String status;
  final DateTime? sentAt;

  /// Notifications **réellement écrites**, donc hors comptes ayant refusé le
  /// marketing. Compter la taille du segment donnerait un taux d'ouverture
  /// flatteur et faux.
  final int recipientCount;

  /// Auteur, déduit du jeton par le serveur : une trace qu'on pourrait
  /// renseigner soi-même ne trace rien.
  final String? createdByEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDraft => status == CampaignStatus.draft;

  /// Une campagne envoyée est **immuable** : la modifier ferait mentir la
  /// trace, et « qu'a-t-on envoyé le 3 mars ? » n'aurait plus de réponse.
  bool get isSent => status == CampaignStatus.sent;
}
