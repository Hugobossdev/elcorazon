class DocumentHistory {
  final String id;
  final String documentId;
  final String driverId;
  final String? previousStatus;
  final String? newStatus;
  final String? changedBy; // ID de l'admin
  final String? changedByName; // Nom de l'admin (si joint)
  final String? changeReason;
  final DateTime changedAt;

  DocumentHistory({
    required this.id,
    required this.documentId,
    required this.driverId,
    this.previousStatus,
    this.newStatus,
    this.changedBy,
    this.changedByName,
    this.changeReason,
    required this.changedAt,
  });

  factory DocumentHistory.fromMap(Map<String, dynamic> map) {
    String? adminName;
    if (map['changed_by'] is Map) {
      adminName = map['changed_by']['name'];
    }

    return DocumentHistory(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      driverId: map['driver_id'] as String,
      previousStatus: map['previous_status'] as String?,
      newStatus: map['new_status'] as String?,
      changedBy: map['changed_by'] is String
          ? map['changed_by'] as String?
          : null,
      changedByName: adminName,
      changeReason: map['change_reason'] as String?,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }
}
