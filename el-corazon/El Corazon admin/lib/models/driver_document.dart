import 'package:flutter/foundation.dart';

/// Statut de validation d'un document
enum DocumentValidationStatus {
  pending, // En attente de validation
  approved, // Approuvé
  rejected, // Rejeté
  expired, // Expiré
}

extension DocumentValidationStatusExtension on DocumentValidationStatus {
  String get displayName {
    switch (this) {
      case DocumentValidationStatus.pending:
        return 'En attente';
      case DocumentValidationStatus.approved:
        return 'Approuvé';
      case DocumentValidationStatus.rejected:
        return 'Rejeté';
      case DocumentValidationStatus.expired:
        return 'Expiré';
    }
  }

  String get emoji {
    switch (this) {
      case DocumentValidationStatus.pending:
        return '⏳';
      case DocumentValidationStatus.approved:
        return '✅';
      case DocumentValidationStatus.rejected:
        return '❌';
      case DocumentValidationStatus.expired:
        return '⏰';
    }
  }
}

/// Type de document de livreur
enum DocumentType {
  license, // Permis de conduire
  identity, // Pièce d'identité
  vehicle, // Documents du véhicule
  insurance, // Assurance
  registration, // Carte grise
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.license:
        return 'Permis de conduire';
      case DocumentType.identity:
        return 'Pièce d\'identité';
      case DocumentType.vehicle:
        return 'Documents du véhicule';
      case DocumentType.insurance:
        return 'Assurance';
      case DocumentType.registration:
        return 'Carte grise';
    }
  }

  String get iconName {
    switch (this) {
      case DocumentType.license:
        return 'drive_eta';
      case DocumentType.identity:
        return 'badge';
      case DocumentType.vehicle:
        return 'directions_car';
      case DocumentType.insurance:
        return 'security';
      case DocumentType.registration:
        return 'description';
    }
  }

  bool get isRequired {
    // Tous les documents sont requis pour activer le compte
    return true;
  }
}

/// Modèle représentant un document de livreur
class DriverDocument {
  final String id;
  final String userId; // users.id (avec role = 'delivery')
  final DocumentType type;
  final DocumentValidationStatus status;
  final String? fileUrl; // URL du fichier uploadé (Supabase Storage)
  final String? fileName; // Nom du fichier
  final String? fileType; // Type MIME du fichier
  final int? fileSize; // Taille du fichier en bytes
  final DateTime? expiryDate; // Date d'expiration du document
  final String? validatedBy; // users.id de l'admin qui a validé
  final String? validationNotes; // Notes de validation
  final DateTime? validatedAt; // Date de validation
  final String? rejectionReason; // Raison du rejet si rejeté
  final DateTime uploadedAt; // Date de téléchargement
  final DateTime createdAt;
  final DateTime updatedAt;
  // Infos du livreur (jointure)
  final String? driverName;
  final String? driverEmail;
  final String? driverPhone;

  DriverDocument({
    required this.id,
    required this.userId,
    required this.type,
    this.status = DocumentValidationStatus.pending,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.expiryDate,
    this.validatedBy,
    this.validationNotes,
    this.validatedAt,
    this.rejectionReason,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
    this.driverName,
    this.driverEmail,
    this.driverPhone,
  });

  /// Vérifie si le document est approuvé
  bool get isApproved => status == DocumentValidationStatus.approved;

  /// Vérifie si le document est expiré
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Vérifie si le document nécessite une attention
  bool get needsAttention {
    return status == DocumentValidationStatus.rejected ||
        status == DocumentValidationStatus.expired ||
        (status == DocumentValidationStatus.approved && isExpired);
  }

  factory DriverDocument.fromMap(Map<String, dynamic> map) {
    // Parser le type de document
    DocumentType parseDocumentType(String? type) {
      if (type == null) return DocumentType.license;
      switch (type.toLowerCase()) {
        case 'license':
          return DocumentType.license;
        case 'identity':
          return DocumentType.identity;
        case 'vehicle':
          return DocumentType.vehicle;
        case 'insurance':
          return DocumentType.insurance;
        case 'registration':
          return DocumentType.registration;
        default:
          return DocumentType.license;
      }
    }

    // Parser le statut
    DocumentValidationStatus parseStatus(String? status) {
      if (status == null) return DocumentValidationStatus.pending;
      switch (status.toLowerCase()) {
        case 'pending':
          return DocumentValidationStatus.pending;
        case 'approved':
          return DocumentValidationStatus.approved;
        case 'rejected':
          return DocumentValidationStatus.rejected;
        case 'expired':
          return DocumentValidationStatus.expired;
        default:
          return DocumentValidationStatus.pending;
      }
    }

    // Parser les dates
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is DateTime) return date;
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic date) {
      if (date == null) return null;
      if (date is DateTime) return date;
      if (date is String) {
        try {
          return DateTime.parse(date);
        } catch (e) {
          debugPrint('Erreur parsing date: $e');
          return null;
        }
      }
      return null;
    }

    // Extraire les infos du livreur si présentes (jointure)
    String? driverName;
    String? driverEmail;
    String? driverPhone;
    
    if (map['drivers'] != null && map['drivers'] is Map) {
      final driverData = map['drivers'] as Map<String, dynamic>;
      driverName = driverData['name']?.toString();
      driverEmail = driverData['email']?.toString();
      driverPhone = driverData['phone']?.toString();
    }

    return DriverDocument(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
      type: parseDocumentType(
        map['document_type']?.toString() ?? map['type']?.toString(),
      ),
      status: parseStatus(map['status']?.toString()),
      fileUrl: map['file_url']?.toString() ?? map['fileUrl']?.toString(),
      fileName: map['file_name']?.toString() ?? map['fileName']?.toString(),
      fileType: map['file_type']?.toString() ?? map['fileType']?.toString(),
      fileSize: (map['file_size'] ?? map['fileSize']) as int?,
      expiryDate: parseNullableDate(map['expiry_date'] ?? map['expiryDate']),
      validatedBy:
          map['validated_by']?.toString() ?? map['validatedBy']?.toString(),
      validationNotes:
          map['validation_notes']?.toString() ??
          map['validationNotes']?.toString(),
      validatedAt: parseNullableDate(map['validated_at'] ?? map['validatedAt']),
      rejectionReason:
          map['rejection_reason']?.toString() ??
          map['rejectionReason']?.toString(),
      uploadedAt: parseDate(map['uploaded_at'] ?? map['uploadedAt']),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
      driverName: driverName,
      driverEmail: driverEmail,
      driverPhone: driverPhone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'document_type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'expiry_date': expiryDate?.toIso8601String(),
      'validated_by': validatedBy,
      'validation_notes': validationNotes,
      'validated_at': validatedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'uploaded_at': uploadedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Ne pas inclure driver infos dans toMap pour DB insert/update
    };
  }
  
  DriverDocument copyWith({
    String? id,
    String? userId,
    DocumentType? type,
    DocumentValidationStatus? status,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSize,
    DateTime? expiryDate,
    String? validatedBy,
    String? validationNotes,
    DateTime? validatedAt,
    String? rejectionReason,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? driverName,
    String? driverEmail,
    String? driverPhone,
  }) {
    return DriverDocument(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      expiryDate: expiryDate ?? this.expiryDate,
      validatedBy: validatedBy ?? this.validatedBy,
      validationNotes: validationNotes ?? this.validationNotes,
      validatedAt: validatedAt ?? this.validatedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      driverName: driverName ?? this.driverName,
      driverEmail: driverEmail ?? this.driverEmail,
      driverPhone: driverPhone ?? this.driverPhone,
    );
  }
}
