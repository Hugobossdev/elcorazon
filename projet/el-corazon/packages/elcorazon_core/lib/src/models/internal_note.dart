/// Une note **interne** du personnel — sur une commande ou sur un client.
///
/// Jamais vue du client ni du livreur : elle vit sur des routes du back-office
/// (`/orders/manage/{id}/notes/`, `/administration/customers/{id}/notes/`) que
/// ni l'un ni l'autre n'atteignent. C'est ce qui la distingue des consignes de
/// livraison ou de la note laissée sur une ligne, qui sont les **leurs**.
///
/// Une note ne se modifie ni ne s'efface : elle est une trace. On en ajoute une
/// seconde pour corriger la première.
class InternalNote {
  const InternalNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.authorName,
  });

  factory InternalNote.fromJson(Map<String, dynamic> json) => InternalNote(
        id: json['id'] as String,
        authorName: json['author_name'] as String?,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;

  /// Nul si le compte auteur n'existe plus sous ce nom — la note, elle, reste.
  final String? authorName;
  final String content;
  final DateTime createdAt;
}
