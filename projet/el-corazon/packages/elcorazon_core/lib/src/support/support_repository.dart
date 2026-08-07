import 'package:elcorazon_core/src/models/money.dart';
import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/support/complaint.dart';
import 'package:elcorazon_core/src/support/return_request.dart';
import 'package:elcorazon_core/src/support/support_ticket.dart';

/// Accès à `/api/v1/support/*` — voir `backend/apps/support/{serializers,views}.py`.
///
/// Les trois ressources sont cloisonnées par le serveur : la liste ne rend que
/// ce qui appartient au compte connecté, et le ticket d'un autre client est
/// *introuvable* (404), jamais refusé par un code qui trahirait son existence
/// (ADR-005). Ce repository n'a donc aucun identifiant d'utilisateur à passer —
/// contrairement à l'accès Supabase qu'il remplace, où le `user_id` voyageait
/// dans chaque requête et n'était donc qu'une convention côté client.
class SupportRepository {
  SupportRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<SupportTicket>> getTickets({String? status}) {
    return _collect(
      '/support/tickets/',
      SupportTicket.fromJson,
      query: status == null ? null : {'status': status},
    );
  }

  Future<SupportTicket> getTicket(String ticketId) async {
    final response = await apiClient.get('/support/tickets/$ticketId/');
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  /// [category] doit être une valeur de `TicketCategory` — le serveur refuse
  /// tout le reste en 400 plutôt que de retomber sur une valeur par défaut.
  Future<SupportTicket> openTicket({
    required String category,
    required String subject,
    required String description,
    List<String> attachments = const [],
  }) async {
    final response = await apiClient.post(
      '/support/tickets/',
      data: {
        'category': category,
        'subject': subject,
        'description': description,
        'attachments': attachments,
      },
    );
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SupportMessage>> getMessages(String ticketId) {
    return _collect('/support/tickets/$ticketId/messages/', SupportMessage.fromJson);
  }

  Future<SupportMessage> reply({required String ticketId, required String content}) async {
    final response = await apiClient.post(
      '/support/tickets/$ticketId/messages/',
      data: {'content': content},
    );
    return SupportMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Complaint>> getComplaints({String? orderId}) {
    return _collect(
      '/support/complaints/',
      Complaint.fromJson,
      query: orderId == null ? null : {'order': orderId},
    );
  }

  Future<Complaint> fileComplaint({
    required String orderId,
    required String kind,
    required String subject,
    required String description,
    List<String> photos = const [],
  }) async {
    final response = await apiClient.post(
      '/support/complaints/',
      data: {
        'order': orderId,
        'kind': kind,
        'subject': subject,
        'description': description,
        'photos': photos,
      },
    );
    return Complaint.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ReturnRequest>> getReturns({String? orderId}) {
    return _collect(
      '/support/returns/',
      ReturnRequest.fromJson,
      query: orderId == null ? null : {'order': orderId},
    );
  }

  /// [refundAmount] est ce que le client *demande*. Le serveur le plafonne au
  /// total de la commande et exige qu'elle soit livrée — deux règles qu'on ne
  /// duplique volontairement pas ici : les rejouer côté client, c'est se
  /// condamner à les voir diverger.
  Future<ReturnRequest> requestReturn({
    required String orderId,
    required String reason,
    required List<String> items,
    required Money refundAmount,
  }) async {
    final response = await apiClient.post(
      '/support/returns/',
      data: {
        'order': orderId,
        'reason': reason,
        'items': items,
        'refund_amount': refundAmount.toJson(),
      },
    );
    return ReturnRequest.fromJson(response.data as Map<String, dynamic>);
  }

  /// Suit `next` jusqu'au bout : les volumes en jeu (les tickets d'un client)
  /// tiennent en une poignée de pages, et un fil de support tronqué à la
  /// première page serait pire qu'inutile.
  Future<List<T>> _collect<T>(
    String firstPage,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    final items = <T>[];
    String? path = firstPage;
    var parameters = query;

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => fromJson(json as Map<String, dynamic>)));
      // `next` porte déjà la requête complète — la repasser en paramètres la
      // dupliquerait.
      path = body['next'] as String?;
      parameters = null;
    }

    return items;
  }
}
