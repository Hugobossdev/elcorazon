import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportTicket {
  final String id;
  final String userId;
  final String category;
  final String subject;
  final String description;
  final List<String>? attachments;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.description,
    required this.createdAt, this.attachments,
    this.status = 'open',
    this.resolvedAt,
    this.resolution,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    return SupportTicket(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      category: map['category'] as String,
      subject: map['subject'] as String,
      description: map['description'] as String,
      attachments: map['attachments'] != null
          ? List<String>.from(map['attachments'])
          : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at']),
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'])
          : null,
      resolution: map['resolution'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'category': category,
      'subject': subject,
      'description': description,
      'attachments': attachments,
      'status': status,
    };
  }
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String? adminId;
  final String? userId;
  final bool isFromAdmin;
  final String message;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.isFromAdmin, required this.message, required this.createdAt, this.adminId,
    this.userId,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) {
    return SupportMessage(
      id: map['id'] as String,
      ticketId: map['ticket_id'] as String,
      adminId: map['admin_id'] as String?,
      userId: map['user_id'] as String?,
      isFromAdmin: map['admin_id'] != null,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticket_id': ticketId,
      if (adminId != null) 'admin_id': adminId,
      if (userId != null) 'user_id': userId,
      'message': message,
    };
  }
}

class SupportService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<SupportTicket> _tickets = [];
  final Map<String, List<SupportMessage>> _messages = {};
  bool _isLoading = false;
  String? _error;

  List<SupportTicket> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charger les tickets de support d'un utilisateur
  Future<void> loadTickets(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _tickets = (response as List)
          .map((item) => SupportTicket.fromMap(item))
          .toList();

      debugPrint('✅ Chargé ${_tickets.length} tickets pour $userId');
    } catch (e) {
      _error = 'Erreur lors du chargement des tickets: $e';
      debugPrint('❌ $_error');
      _tickets = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les messages d'un ticket
  Future<void> loadMessages(String ticketId) async {
    try {
      final response = await _supabase
          .from('support_messages')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      _messages[ticketId] = (response as List)
          .map((item) => SupportMessage.fromMap(item))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors du chargement des messages: $e');
    }
  }

  /// Créer un nouveau ticket
  Future<bool> createTicket(SupportTicket ticket) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('support_tickets')
          .insert(ticket.toMap())
          .select()
          .single();

      final newTicket = SupportTicket.fromMap(response);
      _tickets.insert(0, newTicket);

      debugPrint('✅ Ticket créé: ${newTicket.id}');
      return true;
    } catch (e) {
      _error = 'Erreur lors de la création du ticket: $e';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajouter un message à un ticket
  Future<bool> addMessage(SupportMessage message) async {
    try {
      final response = await _supabase
          .from('support_messages')
          .insert(message.toMap())
          .select()
          .single();

      final newMessage = SupportMessage.fromMap(response);

      if (_messages[message.ticketId] == null) {
        _messages[message.ticketId] = [];
      }
      _messages[message.ticketId]!.add(newMessage);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du message: $e');
      return false;
    }
  }

  /// Obtenir les messages d'un ticket
  List<SupportMessage> getMessages(String ticketId) {
    return _messages[ticketId] ?? [];
  }

  /// Filtrer les tickets par statut
  List<SupportTicket> getTicketsByStatus(String status) {
    return _tickets.where((ticket) => ticket.status == status).toList();
  }

  /// Obtenir les tickets ouverts
  List<SupportTicket> get openTickets => _tickets
      .where((t) => t.status == 'open' || t.status == 'in_progress')
      .toList();
}
