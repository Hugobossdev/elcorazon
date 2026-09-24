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

eccore.ManagedRefund _remboursement(String id, {String statut = 'pending'}) =>
    eccore.ManagedRefund(
      id: id,
      orderId: 'commande-$id',
      orderReference: 'EC0000$id',
      restaurantName: 'El Corazón Lomé',
      customerName: 'Cliente $id',
      provider: 'paydunya',
      amount: const eccore.Money(amountMinor: 1500, currency: 'XOF'),
      reason: 'Plat manquant',
      status: statut,
      requestedByName: 'Gérant',
      createdAt: DateTime(2026, 9, 19),
    );

class _DepotFactice implements eccore.ManagedPayoutRepository {
  _DepotFactice(this.retraits, {this.remboursements = const []});

  List<eccore.ManagedWithdrawal> retraits;
  List<eccore.ManagedRefund> remboursements;
  final List<String?> statutsDemandes = [];
  final List<String> constats = [];
  final List<(String, String)> abandons = [];
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
  Future<eccore.Page<eccore.ManagedRefund>> refunds({String? status, int pageSize = 50}) async {
    statutsDemandes.add(status);
    final lignes =
        status == null ? remboursements : remboursements.where((r) => r.status == status).toList();
    return eccore.Page(results: lignes, count: lignes.length);
  }

  @override
  Future<eccore.ManagedRefund> settleRefund({
    required String refundId,
    String providerReference = '',
  }) =>
      throw UnimplementedError();

  /// Une demande abandonnée : le motif rejoint le dossier, et la ligne quitte
  /// « à traiter ».
  @override
  Future<eccore.ManagedRefund> cancelRefund({
    required String refundId,
    required String reason,
  }) async {
    abandons.add((refundId, reason));
    await retenue?.future;
    if (refus != null) throw refus!;
    final avant = remboursements.firstWhere((r) => r.id == refundId);
    return eccore.ManagedRefund(
      id: avant.id,
      orderId: avant.orderId,
      orderReference: avant.orderReference,
      restaurantName: avant.restaurantName,
      customerName: avant.customerName,
      provider: avant.provider,
      amount: avant.amount,
      reason: '${avant.reason} — abandonné : $reason',
      status: eccore.StatutVersement.annule,
      requestedByName: avant.requestedByName,
      createdAt: avant.createdAt,
    );
  }
}

void main() {
  abandons();

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

/// L'abandon d'un remboursement — la sortie qui manquait.
///
/// Une demande saisie par erreur restait « en attente » pour toujours **et**
/// consommait le plafond du remboursable : la commande ne pouvait plus être
/// remboursée du bon montant, et le seul recours était l'administration Django.
void abandons() {
  test('une demande abandonnée quitte « à traiter » avec son motif', () async {
    final depot = _DepotFactice([], remboursements: [_remboursement('7')]);
    final service = VersementsService(depot: depot);
    await service.chargerRemboursements();

    final refus = await service.abandonnerRemboursement('7', motif: 'Doublon');

    expect(refus, isNull);
    expect(depot.abandons.single, ('7', 'Doublon'));
    expect(service.remboursements, isEmpty);
    expect(service.totalRemboursements, 0);
  });

  test('dans « tout l’historique », la ligne reste et porte son statut', () async {
    final depot = _DepotFactice([], remboursements: [_remboursement('7')]);
    final service = VersementsService(depot: depot);
    await service.chargerRemboursements(filtre: FiltreVersements.tous);

    await service.abandonnerRemboursement('7', motif: 'Doublon');

    expect(service.remboursements.single.status, eccore.StatutVersement.annule);
    expect(service.remboursements.single.reason, contains('Doublon'));
  });

  test('un double clic n’abandonne qu’une fois', () async {
    final depot = _DepotFactice([], remboursements: [_remboursement('7')])
      ..retenue = Completer<void>();
    final service = VersementsService(depot: depot);
    await service.chargerRemboursements();

    final premier = service.abandonnerRemboursement('7', motif: 'Doublon');
    final second = await service.abandonnerRemboursement('7', motif: 'Doublon');
    depot.retenue!.complete();
    await premier;

    expect(second, isNotNull);
    expect(depot.abandons, hasLength(1));
  });
}
