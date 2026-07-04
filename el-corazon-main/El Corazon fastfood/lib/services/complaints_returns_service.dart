import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Complaint {
  final String id;
  final String userId;
  final String orderId;
  final String type; // 'quality', 'delivery', 'service', 'other'
  final String subject;
  final String description;
  final List<String>? photos;
  final String status; // 'pending', 'under_review', 'resolved', 'rejected'
  final DateTime createdAt;
  final String? resolution;

  Complaint({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.type,
    required this.subject,
    required this.description,
    required this.createdAt, this.photos,
    this.status = 'pending',
    this.resolution,
  });

  factory Complaint.fromMap(Map<String, dynamic> map) {
    return Complaint(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      orderId: map['order_id'] as String,
      type: map['type'] as String,
      subject: map['subject'] as String,
      description: map['description'] as String,
      photos: map['photos'] != null ? List<String>.from(map['photos']) : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at']),
      resolution: map['resolution'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'order_id': orderId,
      'type': type,
      'subject': subject,
      'description': description,
      'photos': photos,
      'status': status,
    };
  }
}

class ReturnRequest {
  final String id;
  final String userId;
  final String orderId;
  final String reason;
  final List<String> items;
  final double refundAmount;
  final String status; // 'pending', 'approved', 'rejected', 'refunded'
  final DateTime createdAt;
  final DateTime? resolvedAt;

  ReturnRequest({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.reason,
    required this.items,
    required this.refundAmount,
    required this.createdAt, this.status = 'pending',
    this.resolvedAt,
  });

  factory ReturnRequest.fromMap(Map<String, dynamic> map) {
    return ReturnRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      orderId: map['order_id'] as String,
      reason: map['reason'] as String,
      items: List<String>.from(map['items']),
      refundAmount: (map['refund_amount'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at']),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'order_id': orderId,
      'reason': reason,
      'items': items,
      'refund_amount': refundAmount,
      'status': status,
    };
  }
}

class ComplaintsReturnsService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Complaint> _complaints = [];
  List<ReturnRequest> _returns = [];
  bool _isLoading = false;
  String? _error;

  List<Complaint> get complaints => List.unmodifiable(_complaints);
  List<ReturnRequest> get returns => List.unmodifiable(_returns);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charger les réclamations d'un utilisateur
  Future<void> loadComplaints(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('complaints')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _complaints = (response as List)
          .map((item) => Complaint.fromMap(item))
          .toList();
      
      debugPrint('✅ Chargé ${_complaints.length} réclamations pour $userId');
    } catch (e) {
      _error = 'Erreur lors du chargement des réclamations: $e';
      debugPrint('❌ $_error');
      _complaints = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les retours d'un utilisateur
  Future<void> loadReturns(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('return_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _returns = (response as List)
          .map((item) => ReturnRequest.fromMap(item))
          .toList();
      
      debugPrint('✅ Chargé ${_returns.length} retours pour $userId');
    } catch (e) {
      _error = 'Erreur lors du chargement des retours: $e';
      debugPrint('❌ $_error');
      _returns = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une réclamation
  Future<bool> createComplaint(Complaint complaint) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('complaints')
          .insert(complaint.toMap())
          .select()
          .single();

      final newComplaint = Complaint.fromMap(response);
      _complaints.insert(0, newComplaint);
      
      debugPrint('✅ Réclamation créée: ${newComplaint.id}');
      return true;
    } catch (e) {
      _error = 'Erreur lors de la création de la réclamation: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une demande de retour
  Future<bool> createReturn(ReturnRequest returnRequest) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('return_requests')
          .insert(returnRequest.toMap())
          .select()
          .single();

      final newReturn = ReturnRequest.fromMap(response);
      _returns.insert(0, newReturn);
      
      debugPrint('✅ Demande de retour créée: ${newReturn.id}');
      return true;
    } catch (e) {
      _error = 'Erreur lors de la création de la demande de retour: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtrer par statut
  List<Complaint> getComplaintsByStatus(String status) {
    return _complaints.where((c) => c.status == status).toList();
  }

  List<ReturnRequest> getReturnsByStatus(String status) {
    return _returns.where((r) => r.status == status).toList();
  }
}

