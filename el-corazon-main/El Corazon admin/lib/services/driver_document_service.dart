import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../models/driver_document.dart' as model;
import '../models/document_history.dart';

/// Types de documents requis pour les livreurs (codes côté base de données)
enum DriverDocumentType {
  idCard,
  driverLicense,
  vehicleRegistration,
  vehicleInsurance,
  backgroundCheck,
  profilePhoto,
}

extension DriverDocumentTypeExtension on DriverDocumentType {
  String get displayName {
    switch (this) {
      case DriverDocumentType.idCard:
        return 'Carte d\'identité / Passeport';
      case DriverDocumentType.driverLicense:
        return 'Permis de conduire';
      case DriverDocumentType.vehicleRegistration:
        return 'Carte grise';
      case DriverDocumentType.vehicleInsurance:
        return 'Assurance véhicule';
      case DriverDocumentType.backgroundCheck:
        return 'Casier judiciaire';
      case DriverDocumentType.profilePhoto:
        return 'Photo de profil';
    }
  }

  String get dbCode {
    switch (this) {
      case DriverDocumentType.idCard:
        return 'id_card';
      case DriverDocumentType.driverLicense:
        return 'driver_license';
      case DriverDocumentType.vehicleRegistration:
        return 'vehicle_registration';
      case DriverDocumentType.vehicleInsurance:
        return 'vehicle_insurance';
      case DriverDocumentType.backgroundCheck:
        return 'background_check';
      case DriverDocumentType.profilePhoto:
        return 'profile_photo';
    }
  }
}

class DriverDocumentService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  model.DriverDocument _mapToModelDocument(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{...data};

    // Mapper driver_id -> user_id attendu par le modèle
    // Si on a accès à drivers.user_id via jointure
    if (data['drivers'] != null && data['drivers']['user_id'] != null) {
      normalized['user_id'] = data['drivers']['user_id'].toString();
    } else {
      normalized['user_id'] =
          data['user_id']?.toString() ?? data['driver_id']?.toString() ?? '';
    }

    // Extraire les infos du user si présentes (jointure profonde)
    if (data['drivers'] != null && data['drivers']['users'] != null) {
      final userData = data['drivers']['users'];
      // Créer une structure temporaire pour que le modèle puisse l'extraire
      // ou l'injecter directement dans le modèle si on met à jour le modèle
      // Le modèle attend 'drivers' -> {name, email...}
      // On va aplatir la structure pour matcher ce que le modèle attend (voir modification précédente du modèle)
      normalized['drivers'] = userData;
    }

    // Mapper URL de fichier
    normalized['file_url'] =
        data['file_url'] ?? data['document_url'] ?? data['fileUrl'];

    // Mapper type de document (codes DB -> codes du modèle)
    final rawType = data['document_type']?.toString();
    if (rawType != null) {
      String mapped;
      switch (rawType) {
        case 'driver_license':
          mapped = 'license';
          break;
        case 'id_card':
          mapped = 'identity';
          break;
        case 'vehicle_registration':
          mapped = 'registration';
          break;
        case 'vehicle_insurance':
          mapped = 'insurance';
          break;
        default:
          mapped = rawType;
      }
      normalized['document_type'] = mapped;
    }

    return model.DriverDocument.fromMap(normalized);
  }

  /// Récupérer tous les documents d'un livreur
  Future<List<model.DriverDocument>> getDriverDocuments(String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId);

      return (response as List)
          .map((data) => _mapToModelDocument(Map<String, dynamic>.from(data)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Récupérer un document spécifique par type
  Future<model.DriverDocument?> getDocumentByType(
    String driverId,
    DriverDocumentType type,
  ) async {
    try {
      final response = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', driverId)
          .eq('document_type', type.dbCode)
          .maybeSingle();

      if (response == null) return null;
      return _mapToModelDocument(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error fetching document by type: $e');
      return null;
    }
  }

  /// Récupérer tous les documents en attente de validation
  Future<List<model.DriverDocument>> getPendingDocuments() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabase
          .from('driver_documents')
          .select('*, drivers:driver_id(user_id, users:user_id(name, email, phone))')
          .eq('status', 'pending');

      return (response as List)
          .map((data) => _mapToModelDocument(Map<String, dynamic>.from(data)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending documents: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Récupérer les documents nécessitant une attention (expirés ou expirant bientôt)
  Future<List<model.DriverDocument>> getDocumentsNeedingAttention() async {
    try {
      _isLoading = true;
      notifyListeners();

      final now = DateTime.now();
      final warningDate = now.add(const Duration(days: 30));

      final response = await _supabase
          .from('driver_documents')
          .select('*, drivers:driver_id(user_id, users:user_id(name, email, phone))')
          .or('status.eq.expired,expiry_date.lte.${warningDate.toIso8601String()}')
          .neq('status', 'rejected');

      return (response as List)
          .map((data) => _mapToModelDocument(Map<String, dynamic>.from(data)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching documents needing attention: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Uploader un document
  Future<bool> uploadDocument({
    required String driverId,
    required DriverDocumentType type,
    required File file,
    DateTime? expiryDate,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Upload file to Storage
      final fileExt = path.extension(file.path);
      final fileName =
          '$driverId/${type.dbCode}_${DateTime.now().millisecondsSinceEpoch}$fileExt';

      await _supabase.storage.from('driver_documents').upload(fileName, file);

      final documentUrl =
          _supabase.storage.from('driver_documents').getPublicUrl(fileName);

      // 2. Insert/Update record in DB
      final existingDoc = await getDocumentByType(driverId, type);

      if (existingDoc != null) {
        // Update existing document
        await _supabase.from('driver_documents').update({
          'document_url': documentUrl,
          'status': 'pending', // Reset status to pending on new upload
          'rejection_reason': null,
          'expiry_date': expiryDate?.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingDoc.id);
      } else {
        // Insert new document
        await _supabase.from('driver_documents').insert({
          'driver_id': driverId,
          'document_type': type.dbCode,
          'document_url': documentUrl,
          'status': 'pending',
          'expiry_date': expiryDate?.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error uploading document: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mettre à jour la date d'expiration
  Future<bool> updateDocumentExpiry(
      String documentId, DateTime expiryDate) async {
    try {
      await _supabase.from('driver_documents').update({
        'expiry_date': expiryDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating expiry date: $e');
      return false;
    }
  }

  /// Enregistrer l'historique des modifications
  Future<void> _logDocumentHistory({
    required String documentId,
    required String driverId,
    required String newStatus,
    String? previousStatus,
    String? reason,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      String? changedBy;
      
      // Essayer de récupérer l'ID utilisateur public de l'admin
      if (user != null) {
         try {
           final adminUser = await _supabase
               .from('users')
               .select('id')
               .eq('auth_user_id', user.id)
               .maybeSingle();
           changedBy = adminUser?['id'] as String?;
         } catch (_) {
           // Fallback si la table users n'est pas accessible ou structure différente
           debugPrint('Could not fetch admin user ID for history log');
         }
      }

      await _supabase.from('driver_document_history').insert({
        'document_id': documentId,
        'driver_id': driverId,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'changed_by': changedBy,
        'change_reason': reason,
        'changed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging document history: $e');
    }
  }

  /// Approuver un document
  Future<bool> approveDocument(String documentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Récupérer infos pour historique
      final currentDoc = await _supabase
          .from('driver_documents')
          .select('status, driver_id')
          .eq('id', documentId)
          .single();
      final previousStatus = currentDoc['status'] as String?;
      final driverId = currentDoc['driver_id'] as String;

      await _supabase.from('driver_documents').update({
        'status': 'approved',
        'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);

      // Log history
      await _logDocumentHistory(
        documentId: documentId,
        driverId: driverId,
        newStatus: 'approved',
        previousStatus: previousStatus,
        reason: 'Document validé par l\'administrateur',
      );

      // Vérifier si tous les documents sont approuvés pour activer le compte
      await _checkAndActivateAccount(driverId);

      return true;
    } catch (e) {
      debugPrint('Error approving document: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rejeter un document
  Future<bool> rejectDocument(String documentId, String reason) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Récupérer infos pour historique
      final currentDoc = await _supabase
          .from('driver_documents')
          .select('status, driver_id')
          .eq('id', documentId)
          .single();
      final previousStatus = currentDoc['status'] as String?;
      final driverId = currentDoc['driver_id'] as String;

      await _supabase.from('driver_documents').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);

      // Log history
      await _logDocumentHistory(
        documentId: documentId,
        driverId: driverId,
        newStatus: 'rejected',
        previousStatus: previousStatus,
        reason: reason,
      );

      // Désactiver le compte si un document requis est rejeté
      await _deactivateAccount(driverId);

      // Envoyer une notification au livreur
      await _sendDocumentRejectionNotification(driverId, reason);

      return true;
    } catch (e) {
      debugPrint('Error rejecting document: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marquer un document comme expiré
  Future<bool> markDocumentExpired(String documentId) async {
    try {
      await _supabase.from('driver_documents').update({
        'status': 'expired',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', documentId);

      // Désactiver le compte
      final doc = await _supabase
          .from('driver_documents')
          .select('driver_id')
          .eq('id', documentId)
          .single();
      final driverId = doc['driver_id'] as String;

      await _deactivateAccount(driverId);

      return true;
    } catch (e) {
      debugPrint('Error marking document expired: $e');
      return false;
    }
  }

  /// Vérifier si tous les documents requis sont approuvés
  Future<bool> areAllRequiredDocumentsApproved(String driverId) async {
    try {
      final documents = await getDriverDocuments(driverId);

      // Types requis côté admin
      final requiredTypes = [
        model.DocumentType.license,
        model.DocumentType.identity,
        model.DocumentType.vehicle,
        model.DocumentType.insurance,
        model.DocumentType.registration,
      ];

      for (final type in requiredTypes) {
        final doc = documents
            .where((d) => d.type == type)
            .cast<model.DriverDocument?>()
            .firstWhere(
              (d) => d != null,
              orElse: () => null,
            );

        if (doc == null ||
            doc.status != model.DocumentValidationStatus.approved) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Vérifier et activer le compte si tous les documents sont approuvés
  Future<void> _checkAndActivateAccount(String driverId) async {
    if (await areAllRequiredDocumentsApproved(driverId)) {
      await _supabase.from('drivers').update({
        'is_active': true,
        'status': 'offline', // Prêt à travailler mais hors ligne
      }).eq('id', driverId);

      // Envoyer notification
      await _sendAccountActivatedNotification(driverId);
    }
  }

  /// Désactiver le compte
  Future<void> _deactivateAccount(String driverId) async {
    await _supabase.from('drivers').update({
      'is_active': false,
      'status': 'unavailable',
    }).eq('id', driverId);
  }

  /// Envoyer notification de rejet
  Future<void> _sendDocumentRejectionNotification(
      String driverId, String reason) async {
    try {
      // Récupérer le user_id associé au driver
      final driver = await _supabase
          .from('drivers')
          .select('user_id')
          .eq('id', driverId)
          .single();
      final userId = driver['user_id'];

      if (userId != null) {
        await _supabase.from('notifications').insert({
          'user_id': userId,
          'title': 'Document rejeté',
          'message': 'Un de vos documents a été rejeté. Raison : $reason',
          'type': 'document_rejected',
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Envoyer notification d'activation
  Future<void> _sendAccountActivatedNotification(String driverId) async {
    try {
      // Récupérer le user_id associé au driver
      final driver = await _supabase
          .from('drivers')
          .select('user_id')
          .eq('id', driverId)
          .single();
      final userId = driver['user_id'];

      if (userId != null) {
        await _supabase.from('notifications').insert({
          'user_id': userId,
          'title': 'Compte activé',
          'message':
              'Tous vos documents ont été validés. Vous pouvez maintenant commencer à livrer !',
          'type': 'account_activated',
          'is_read': false,
        });
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Supprimer un document
  Future<bool> deleteDocument(String documentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get file path from DB first to delete from storage
      await _supabase
          .from('driver_documents')
          .select('document_url')
          .eq('id', documentId)
          .single();

      // Extract file path from URL if needed or store path in DB
      // For now just deleting DB record

      await _supabase.from('driver_documents').delete().eq('id', documentId);
      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Vérifier les documents expirés
  Future<void> checkExpiredDocuments() async {
    try {
      final now = DateTime.now();

      // Find expired documents that are not marked as expired yet
      final expiredDocs = await _supabase
          .from('driver_documents')
          .select('id, driver_id')
          .lt('expiry_date', now.toIso8601String())
          .neq('status', 'expired');

      for (var doc in expiredDocs as List) {
        await markDocumentExpired(doc['id']);
      }
    } catch (e) {
      debugPrint('Error checking expired documents: $e');
    }
  }

  /// Obtenir l'historique des modifications d'un document
  Future<List<DocumentHistory>> getDocumentHistory(String documentId) async {
    try {
      final response = await _supabase
          .from('driver_document_history')
          .select('*, changed_by:users!driver_document_history_changed_by_fkey(name)')
          .eq('document_id', documentId)
          .order('changed_at', ascending: false);

      return (response as List)
          .map((data) => DocumentHistory.fromMap(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching document history: $e');
      return [];
    }
  }

  /// Vérifier les expirations à venir (tâche planifiée)
  Future<void> checkUpcomingExpirations() async {
    // Logique pour envoyer des rappels aux livreurs dont les documents expirent bientôt
  }
}
