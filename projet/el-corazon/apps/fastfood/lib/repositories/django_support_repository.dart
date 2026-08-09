import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/main.dart' show apiClient;

/// Support contre le backend Django (Phase 6) : tickets, fil de messages,
/// réclamations et demandes de retour.
///
/// Aucun modèle local ne double ceux du package partagé, contrairement aux
/// domaines migrés plus tôt (fidélité, commandes) où des classes locales
/// préexistaient et étaient consommées par des écrans : les modèles Supabase
/// de `support_service.dart` et `complaints_returns_service.dart` ont été
/// supprimés avec le code qui les remplissait, et les écrans lisent désormais
/// directement les types de `elcorazon_core`.
class DjangoSupportRepository {
  DjangoSupportRepository() : _support = eccore.SupportRepository(apiClient: apiClient);

  final eccore.SupportRepository _support;

  Future<List<eccore.SupportTicket>> getTickets() => _support.getTickets();

  Future<eccore.SupportTicket> openTicket({
    required String category,
    required String subject,
    required String description,
  }) {
    return _support.openTicket(category: category, subject: subject, description: description);
  }

  Future<List<eccore.SupportMessage>> getMessages(String ticketId) =>
      _support.getMessages(ticketId);

  Future<eccore.SupportMessage> reply({required String ticketId, required String content}) =>
      _support.reply(ticketId: ticketId, content: content);

  Future<List<eccore.Complaint>> getComplaints() => _support.getComplaints();

  Future<eccore.Complaint> fileComplaint({
    required String orderId,
    required String kind,
    required String subject,
    required String description,
    List<String> photos = const [],
  }) {
    return _support.fileComplaint(
      orderId: orderId,
      kind: kind,
      subject: subject,
      description: description,
      photos: photos,
    );
  }

  Future<List<eccore.ReturnRequest>> getReturns() => _support.getReturns();

  Future<eccore.ReturnRequest> requestReturn({
    required String orderId,
    required String reason,
    required List<String> items,
    required int refundAmountMinor,
    required String currency,
  }) {
    return _support.requestReturn(
      orderId: orderId,
      reason: reason,
      items: items,
      refundAmount: eccore.Money(amountMinor: refundAmountMinor, currency: currency),
    );
  }
}
