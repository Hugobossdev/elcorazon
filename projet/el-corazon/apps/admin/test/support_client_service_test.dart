import 'package:admin/services/support_client_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Le service client du back-office.
///
/// Les routes du support n'étaient ouvertes qu'aux clients : le back-office ne
/// voyait aucun ticket. Ces cas gardent ce qu'on demande au serveur — « à
/// traiter » en une requête — et ce que la file devient après un geste.

eccore.ManagedTicket _ticket(String id, {String statut = 'open'}) => eccore.ManagedTicket(
      id: id,
      customerId: 'client-$id',
      customerName: 'Client $id',
      customerEmail: '$id@example.com',
      category: 'order',
      subject: 'Sujet $id',
      description: 'Description',
      status: statut,
      createdAt: DateTime(2026, 9, 18),
    );

eccore.ManagedReturn _retour(String id, {String statut = 'pending'}) => eccore.ManagedReturn(
      id: id,
      orderId: 'commande-$id',
      orderReference: 'EC$id',
      orderTotal: const eccore.Money(amountMinor: 4500, currency: 'XOF'),
      restaurantName: 'El Corazón Lomé',
      customerName: 'Client $id',
      reason: 'Manquant',
      items: const ['Bissap'],
      refundAmount: const eccore.Money(amountMinor: 500, currency: 'XOF'),
      status: statut,
      createdAt: DateTime(2026, 9, 18),
    );

class _DepotFactice implements eccore.ManagedSupportRepository {
  _DepotFactice({this.tickets_ = const [], this.retours_ = const []});

  List<eccore.ManagedTicket> tickets_;
  List<eccore.ManagedReturn> retours_;
  final List<List<String>?> statutsDemandes = [];

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<eccore.Page<eccore.ManagedTicket>> tickets({
    List<String>? statuts,
    String? search,
    int pageSize = 50,
  }) async {
    statutsDemandes.add(statuts);
    final lignes = statuts == null ? tickets_ : tickets_.where((t) => statuts.contains(t.status));
    return eccore.Page(results: lignes.toList(), count: lignes.length);
  }

  @override
  Future<eccore.Page<eccore.ManagedComplaint>> complaints({
    List<String>? statuts,
    int pageSize = 50,
  }) async =>
      const eccore.Page(results: [], count: 0);

  @override
  Future<eccore.Page<eccore.ManagedReturn>> returns({
    List<String>? statuts,
    int pageSize = 50,
  }) async {
    final lignes = statuts == null ? retours_ : retours_.where((r) => statuts.contains(r.status));
    return eccore.Page(results: lignes.toList(), count: lignes.length);
  }

  @override
  Future<eccore.ManagedTicket> setTicketStatus({
    required String ticketId,
    required String status,
    String resolution = '',
  }) async =>
      _ticket(ticketId, statut: status);

  @override
  Future<eccore.ManagedReturn> decideReturn({
    required String returnId,
    required String status,
    String resolution = '',
  }) async =>
      _retour(returnId, statut: status);

  @override
  Future<eccore.ManagedTicket> ticket(String ticketId) async => _ticket(ticketId);

  @override
  Future<eccore.SupportMessage> reply({required String ticketId, required String content}) =>
      throw UnimplementedError();

  @override
  Future<eccore.ManagedComplaint> decideComplaint({
    required String complaintId,
    required String status,
    String resolution = '',
  }) =>
      throw UnimplementedError();
}

void main() {
  test('« à traiter » demande ouverts et en cours en une seule requête', () async {
    final depot = _DepotFactice(
      tickets_: [_ticket('a'), _ticket('b', statut: 'in_progress'), _ticket('c', statut: 'closed')],
    );
    final service = SupportClientService(depot: depot);

    await service.charger();

    expect(depot.statutsDemandes.single, ATraiter.tickets);
    expect(service.tickets.map((t) => t.id), ['a', 'b']);
  });

  test('l’historique ne filtre pas', () async {
    final depot = _DepotFactice(tickets_: [_ticket('a'), _ticket('c', statut: 'closed')]);
    final service = SupportClientService(depot: depot);

    await service.charger(aTraiter: false);

    expect(depot.statutsDemandes.single, isNull);
    expect(service.tickets, hasLength(2));
  });

  test('un ticket résolu sort de la file « à traiter »', () async {
    final service = SupportClientService(depot: _DepotFactice(tickets_: [_ticket('a')]));
    await service.charger();

    final refus = await service.changerStatutTicket('a', 'resolved', resolution: 'Réglé.');

    expect(refus, isNull);
    expect(service.tickets, isEmpty);
  });

  test('un retour approuvé reste à traiter : il attend encore son remboursement', () async {
    final service = SupportClientService(depot: _DepotFactice(retours_: [_retour('a')]));
    await service.charger();

    await service.statuerRetour('a', 'approved');

    expect(service.retours.single.status, 'approved');
    expect(service.retours.single.decisionsPossibles, contains('refunded'));
  });

  test('un retour refusé sort de la file', () async {
    final service = SupportClientService(depot: _DepotFactice(retours_: [_retour('a')]));
    await service.charger();

    await service.statuerRetour('a', 'rejected', resolution: 'Non.');

    expect(service.retours, isEmpty);
  });
}
