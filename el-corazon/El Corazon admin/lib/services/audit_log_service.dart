import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer le journal d'activité (audit log)
class AuditLogService extends ChangeNotifier {
  static final AuditLogService _instance = AuditLogService._internal();
  factory AuditLogService() => _instance;
  AuditLogService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  List<AuditLogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AuditLogEntry> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Enregistrer une action dans le journal d'activité
  Future<bool> logAction({
    required String userId,
    required String action,
    required AuditLogActionType actionType,
    String? resourceId,
    String? resourceType,
    Map<String, dynamic>? details,
    String? ipAddress,
  }) async {
    try {
      final entry = AuditLogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        action: action,
        actionType: actionType,
        resourceId: resourceId,
        resourceType: resourceType,
        details: details,
        ipAddress: ipAddress,
        timestamp: DateTime.now(),
      );

      // Insérer dans la base de données
      await _supabase.from('audit_logs').insert({
        'id': entry.id,
        'user_id': entry.userId,
        'action': entry.action,
        'action_type': entry.actionType.name,
        'resource_id': entry.resourceId,
        'resource_type': entry.resourceType,
        'details': entry.details,
        'ip_address': entry.ipAddress,
        'timestamp': entry.timestamp.toIso8601String(),
      });

      // Ajouter à la liste locale
      _logs.insert(0, entry);
      notifyListeners();

      debugPrint('AuditLogService: Action enregistrée - $action');
      return true;
    } catch (e) {
      debugPrint('AuditLogService: Erreur enregistrement - $e');
      return false;
    }
  }

  /// Charger les logs d'activité
  Future<void> loadLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    AuditLogActionType? actionType,
    String? resourceType,
    int limit = 100,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      var query = _supabase.from('audit_logs').select('*');

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (actionType != null) {
        query = query.eq('action_type', actionType.name);
      }

      if (resourceType != null) {
        query = query.eq('resource_type', resourceType);
      }

      final response = await query
          .order('timestamp', ascending: false)
          .limit(limit);

      _logs = (response as List)
          .map((data) => AuditLogEntry.fromMap(data))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('AuditLogService: Erreur chargement logs - $e');
    }
  }

  /// Obtenir les statistiques d'activité
  Future<Map<String, dynamic>> getActivityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('audit_logs').select('*');

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      final response = await query;

      final logs = (response as List)
          .map((data) => AuditLogEntry.fromMap(data))
          .toList();

      // Calculer les statistiques
      final totalActions = logs.length;
      final actionsByType = <String, int>{};
      final actionsByUser = <String, int>{};
      final actionsByResource = <String, int>{};

      for (final log in logs) {
        actionsByType[log.actionType.name] =
            (actionsByType[log.actionType.name] ?? 0) + 1;
        actionsByUser[log.userId] = (actionsByUser[log.userId] ?? 0) + 1;
        if (log.resourceType != null) {
          actionsByResource[log.resourceType!] =
              (actionsByResource[log.resourceType!] ?? 0) + 1;
        }
      }

      return {
        'totalActions': totalActions,
        'actionsByType': actionsByType,
        'actionsByUser': actionsByUser,
        'actionsByResource': actionsByResource,
      };
    } catch (e) {
      debugPrint('AuditLogService: Erreur statistiques - $e');
      return {};
    }
  }

  /// Initialiser le service
  Future<void> initialize() async {
    // Le service est prêt à être utilisé
    // Pas besoin de chargement initial
  }
}

/// Type d'action d'audit
enum AuditLogActionType {
  create,
  update,
  delete,
  view,
  login,
  logout,
  approve,
  reject,
  assign,
  refund,
  payment,
  export,
  import,
  other,
}

/// Entrée du journal d'activité
class AuditLogEntry {
  final String id;
  final String userId;
  final String action;
  final AuditLogActionType actionType;
  final String? resourceId;
  final String? resourceType;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.userId,
    required this.action,
    required this.actionType,
    this.resourceId,
    this.resourceType,
    this.details,
    this.ipAddress,
    required this.timestamp,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      action: map['action'] ?? '',
      actionType: AuditLogActionType.values.firstWhere(
        (e) => e.name == map['action_type'],
        orElse: () => AuditLogActionType.other,
      ),
      resourceId: map['resource_id'],
      resourceType: map['resource_type'],
      details: map['details'] != null
          ? Map<String, dynamic>.from(map['details'])
          : null,
      ipAddress: map['ip_address'],
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'action_type': actionType.name,
      'resource_id': resourceId,
      'resource_type': resourceType,
      'details': details,
      'ip_address': ipAddress,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

