import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/repositories/django_support_repository.dart';

/// Tickets de support, contre le backend Django (Phase 6).
///
/// Les modèles `SupportTicket`/`SupportMessage` qui vivaient ici sont
/// supprimés au profit de ceux de `elcorazon_core` : ils portaient un
/// `user_id` (et un couple `admin_id`/`user_id` pour distinguer l'auteur d'un
/// message) qui n'a plus de raison d'être — le serveur cloisonne par le compte
/// authentifié, et `author.user_type` dit de quel côté du fil parle un
/// message.
class SupportService extends ChangeNotifier {
  final DjangoSupportRepository _repository = DjangoSupportRepository();

  List<eccore.SupportTicket> _tickets = [];
  final Map<String, List<eccore.SupportMessage>> _messages = {};
  bool _isLoading = false;
  String? _error;

  List<eccore.SupportTicket> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge les tickets du compte connecté. Plus d'identifiant en paramètre :
  /// la requête ne désigne plus l'utilisateur, le serveur le déduit du jeton.
  Future<void> loadTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tickets = await _repository.getTickets();
      debugPrint('✅ Chargé ${_tickets.length} tickets de support');
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Chargement des tickets: ${e.code}');
      _tickets = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge le fil d'un ticket (pagination suivie jusqu'au bout côté
  /// repository).
  Future<void> loadMessages(String ticketId) async {
    try {
      _messages[ticketId] = await _repository.getMessages(ticketId);
      notifyListeners();
    } on eccore.ApiException catch (e) {
      debugPrint('❌ Chargement du fil $ticketId: ${e.code}');
    }
  }

  /// Ouvre un ticket. [category] doit être une valeur de `TicketCategory`
  /// côté serveur (`order`, `payment`, `account`, `delivery`, `other`) — le
  /// statut, la résolution et la date de résolution ne s'écrivent pas d'ici.
  Future<bool> createTicket({
    required String category,
    required String subject,
    required String description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ticket = await _repository.openTicket(
        category: category,
        subject: subject,
        description: description,
      );
      _tickets.insert(0, ticket);
      debugPrint('✅ Ticket créé: ${ticket.id}');
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('❌ Création du ticket: ${e.code}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMessage({required String ticketId, required String content}) async {
    try {
      final message = await _repository.reply(ticketId: ticketId, content: content);
      (_messages[ticketId] ??= []).add(message);
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      debugPrint('❌ Envoi du message sur $ticketId: ${e.code}');
      return false;
    }
  }

  List<eccore.SupportMessage> getMessages(String ticketId) => _messages[ticketId] ?? [];

  List<eccore.SupportTicket> getTicketsByStatus(String status) =>
      _tickets.where((ticket) => ticket.status == status).toList();

  List<eccore.SupportTicket> get openTickets =>
      _tickets.where((t) => t.status == 'open' || t.status == 'in_progress').toList();
}
