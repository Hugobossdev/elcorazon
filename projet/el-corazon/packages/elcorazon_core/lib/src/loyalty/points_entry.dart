/// Mouvement du journal de points — miroir de `PointsEntrySerializer`.
/// Immuable côté serveur (F5) : un solde contesté se vérifie ligne par ligne,
/// jamais en reconstruisant un total côté client.
class PointsEntry {
  const PointsEntry({
    required this.id,
    required this.kind,
    required this.delta,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  factory PointsEntry.fromJson(Map<String, dynamic> json) {
    return PointsEntry(
      id: json['id'] as String,
      kind: json['kind'] as String,
      delta: json['delta'] as int,
      balanceAfter: json['balance_after'] as int,
      description: json['description'] as String? ?? '',
      orderId: json['order'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;

  /// `earned` | `spent` | `expired` | `adjusted` (`EntryKind` côté serveur).
  final String kind;
  final int delta;
  final int balanceAfter;
  final String description;
  final String? orderId;
  final DateTime createdAt;
}
