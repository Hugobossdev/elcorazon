import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/repositories/django_support_repository.dart';

/// Réclamations et demandes de retour, contre le backend Django (Phase 6).
///
/// Deux règles qui étaient hors de portée de l'implémentation Supabase (où le
/// client insérait la ligne lui-même) sont désormais tenues par le serveur, et
/// volontairement pas rejouées ici : la commande doit appartenir au client, et
/// un retour ne peut être demandé que sur une commande **livrée**, pour un
/// montant qui ne dépasse pas son total (`SupportService.request_return`).
/// Un refus remonte donc dans [error] avec le motif du serveur, au lieu d'être
/// deviné à partir d'un état local.
class ComplaintsReturnsService extends ChangeNotifier {
  final DjangoSupportRepository _repository = DjangoSupportRepository();

  List<eccore.Complaint> _complaints = [];
  List<eccore.ReturnRequest> _returns = [];
  bool _isLoading = false;
  String? _error;

  List<eccore.Complaint> get complaints => List.unmodifiable(_complaints);
  List<eccore.ReturnRequest> get returns => List.unmodifiable(_returns);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadComplaints() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _complaints = await _repository.getComplaints();
      debugPrint('✅ Chargé ${_complaints.length} réclamations');
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Chargement des réclamations: ${e.code}');
      _complaints = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReturns() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _returns = await _repository.getReturns();
      debugPrint('✅ Chargé ${_returns.length} demandes de retour');
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Chargement des retours: ${e.code}');
      _returns = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [kind] : `quality` | `delivery` | `service` | `other` (`ComplaintKind`).
  Future<bool> createComplaint({
    required String orderId,
    required String kind,
    required String subject,
    required String description,
    List<String> photos = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final complaint = await _repository.fileComplaint(
        orderId: orderId,
        kind: kind,
        subject: subject,
        description: description,
        photos: photos,
      );
      _complaints.insert(0, complaint);
      debugPrint('✅ Réclamation créée: ${complaint.id}');
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Création de la réclamation: ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// [refundAmountMinor] est en **unité mineure** (1500 F CFA -> 1500), comme
  /// partout ailleurs depuis ADR-007 — plus de `double` qui se promène.
  Future<bool> createReturn({
    required String orderId,
    required String reason,
    required List<String> items,
    required int refundAmountMinor,
    String currency = 'XOF',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final demande = await _repository.requestReturn(
        orderId: orderId,
        reason: reason,
        items: items,
        refundAmountMinor: refundAmountMinor,
        currency: currency,
      );
      _returns.insert(0, demande);
      debugPrint('✅ Demande de retour créée: ${demande.id}');
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Création de la demande de retour: ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<eccore.Complaint> getComplaintsByStatus(String status) =>
      _complaints.where((c) => c.status == status).toList();

  List<eccore.ReturnRequest> getReturnsByStatus(String status) =>
      _returns.where((r) => r.status == status).toList();
}
