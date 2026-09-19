import 'dart:async';

import 'package:admin/services/versements_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce que le back-office fait des sorties d'argent.
///
/// Une demande de retrait livreur restait « en attente » pour toujours, gains
/// débités : rien ne pouvait la solder. Ces cas gardent ce que l'écran montre
/// et ce qu'il envoie — en particulier qu'un double clic ne signe pas deux fois.

eccore.ManagedWithdrawal _retrait(
  String id, {
  int montant = 4000,
  String devise = 'XOF',
  String statut = 'pending',
}) =>
    eccore.ManagedWithdrawal(
      id: id,
      courierId: 'livreur-$id',
      courierName: 'Livreur $id',
      restaurantSlug: 'el-corazon-lome',
      restaurantName: 'El Corazón Lomé',
      amount: eccore.Money(amountMinor: montant, currency: devise),
      status: statut,
      createdAt: DateTime(2026, 9, 18),
    );

class _DepotFactice implements eccore.ManagedPayoutRepository {
  _DepotFactice(this.retraits);

  List<eccore.ManagedWithdrawal> retraits;
  final List<String?> statutsDemandes = [];
  final List<String> constats = [];
  Completer<void>? retenue;
  eccore.ApiException? refus;

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<eccore.Page<eccore.ManagedWithdrawal>> withdrawals({
    String? status,
    String? search,
    int pageSize = 50,
  }) async {
    statutsDemandes.add(status);
    final lignes = status == null ? retraits : retraits.where((r) => r.status == status).toList();
    return eccore.Page(results: lignes, count: lignes.length);
  }

  @override
  Future<eccore.ManagedWithdrawal> settleWithdrawal({
    required String withdrawalId,
    required String providerReference,
  }) async {
    constats.add(withdrawalId);
    await retenue?.future;
    if (refus != null) throw refus!;
    final avant = retraits.firstWhere((r) => r.id == withdrawalId);
    return eccore.ManagedWithdrawal(
      id: avant.id,
      courierId: avant.courierId,
      courierName: avant.courierName,
      restaurantSlug: avant.restaurantSlug,
      restaurantName: avant.restaurantName,
      amount: avant.amount,
      status: eccore.StatutVersement.verse,
      providerReference: providerReference,
      createdAt: avant.createdAt,
    );
  }

  @override
  Future<eccore.ManagedWithdrawal> rejectWithdrawal({
    required String withdrawalId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<eccore.Page<eccore.ManagedRefund>> refunds({String? status, int pageSize = 50}) async =>
      const eccore.Page(results: [], count: 0);

  @override
  Future<eccore.ManagedRefund> settleRefund({
    required String refundId,
    String providerReference = '',
  }) =>
      throw UnimplementedError();
}

void main() {
  test('« À traiter » demande au serveur les seules demandes en attente', () async {
    final depot = _DepotFactice([_retrait('a'), _retrait('b', statut: 'completed')]);
    final service = VersementsService(depot: depot);

    await service.chargerRetraits();

    expect(depot.statutsDemandes.single, eccore.StatutVersement.enAttente);
    expect(service.retraits.map((r) => r.id), ['a']);
  });

  test('« Tout l’historique » ne filtre pas', () async {
    final depot = _DepotFactice([_retrait('a'), _retrait('b', statut: 'completed')]);
    final service = VersementsService(depot: depot);

    await service.chargerRetraits(filtre: FiltreVersements.tous);

    expect(depot.statutsDemandes.single, isNull);
    expect(service.retraits, hasLength(2));
  });

  test('une demande constatée sort de « À traiter »', () async {
    // La garder laisserait croire qu'il reste un geste à faire.
    final depot = _DepotFactice([_retrait('a'), _retrait('b')]);
    final service = VersementsService(depot: depot);
    await service.chargerRetraits();

    final refus = await service.constaterRetrait('a', reference: 'PD-1');

    expect(refus, isNull);
    expect(service.retraits.map((r) => r.id), ['b']);
    expect(service.totalRetraits, 1);
  });

  test('dans l’historique, elle reste, avec son nouveau statut', () async {
    final depot = _DepotFactice([_retrait('a')]);
    final service = VersementsService(depot: depot);
    await service.chargerRetraits(filtre: FiltreVersements.tous);

    await service.constaterRetrait('a', reference: 'PD-1');

    expect(service.retraits.single.status, eccore.StatutVersement.verse);
    expect(service.retraits.single.providerReference, 'PD-1');
  });

  test('un double clic ne signe pas deux fois', () async {
    final depot = _DepotFactice([_retrait('a')])..retenue = Completer<void>();
    final service = VersementsService(depot: depot);
    await service.chargerRetraits();

    final premier = service.constaterRetrait('a', reference: 'PD-1');
    expect(service.enCours('a'), isTrue);
    final second = await service.constaterRetrait('a', reference: 'PD-1');
    depot.retenue!.complete();
    await premier;

    expect(depot.constats, ['a']);
    expect(second, isNotNull);
    expect(service.enCours('a'), isFalse);
  });

  test('un refus du serveur est rendu en toutes lettres, et la ligne reste', () async {
    final depot = _DepotFactice([_retrait('a')])
      ..refus = const eccore.ApiException(
        status: 409,
        code: 'illegal_transition',
        detail: 'Ce retrait a déjà été versé.',
      );
    final service = VersementsService(depot: depot);
    await service.chargerRetraits();

    final refus = await service.constaterRetrait('a', reference: 'PD-1');

    expect(refus, 'Ce retrait a déjà été versé.');
    expect(service.retraits, hasLength(1));
  });

  test('la somme à verser se tient par devise, jamais additionnée', () async {
    // Un réseau à plusieurs pays paie en francs CFA et en cedis : un total
    // unique serait un nombre sans unité.
    final depot = _DepotFactice([
      _retrait('a'),
      _retrait('b', montant: 1500),
      _retrait('c', montant: 12000, devise: 'GHS'),
    ]);
    final service = VersementsService(depot: depot);

    await service.chargerRetraits();

    expect(service.aVerserParDevise, {'XOF': 5500, 'GHS': 12000});
  });
}
