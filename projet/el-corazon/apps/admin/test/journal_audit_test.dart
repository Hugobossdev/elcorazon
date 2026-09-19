import 'package:admin/services/journal_audit_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Le journal des décisions, à l'écran.
///
/// Il était écrit sans être lisible. Ces cas gardent la lecture des valeurs —
/// du JSON brut consigné par le serveur — et la remontée page par page.

eccore.AuditRecord _entree(String id) => eccore.AuditRecord(
      id: id,
      action: 'staff.roles',
      targetType: 'staff',
      targetId: 'membre-1',
      targetLabel: 'awa@elcorazon.com',
      before: const {'roles': <String>[]},
      after: const {
        'roles': ['Manager'],
      },
      createdAt: DateTime(2026, 9, 18),
    );

class _DepotFactice implements eccore.AuditJournalRepository {
  final List<String?> familles = [];
  final List<String> suites = [];

  @override
  eccore.ApiClient get apiClient => throw UnimplementedError();

  @override
  Future<eccore.Page<eccore.AuditRecord>> entries({
    String? famille,
    String? recherche,
    DateTime? depuis,
    DateTime? jusqua,
    int pageSize = 50,
  }) async {
    familles.add(famille);
    return eccore.Page(results: [_entree('1')], count: 2, next: 'http://x/?page=2');
  }

  @override
  Future<eccore.Page<eccore.AuditRecord>> pageAt(String url) async {
    suites.add(url);
    return eccore.Page(results: [_entree('2')], count: 2);
  }
}

void main() {
  group('Une valeur consignée se lit', () {
    test('une liste vide dit « aucun », pas « [] »', () {
      expect(valeurLisible(<String>[]), 'aucun');
      expect(valeurLisible(['Manager', 'Caisse']), 'Manager, Caisse');
    });

    test('un booléen se dit en mots', () {
      expect(valeurLisible(true), 'oui');
      expect(valeurLisible(false), 'non');
    });

    test('une absence se voit', () {
      expect(valeurLisible(null), '—');
    });
  });

  test('la suite s’ajoute à ce qu’on lit déjà, et s’arrête à la fin', () async {
    final depot = _DepotFactice();
    final journal = JournalAuditService(depot: depot);

    await journal.charger(famille: 'staff.');
    expect(journal.aUneSuite, isTrue);
    await journal.chargerLaSuite();

    expect(depot.familles.single, 'staff.');
    expect(journal.entrees.map((e) => e.id), ['1', '2']);
    expect(journal.aUneSuite, isFalse);
  });

  test('« Tout » retire la famille', () async {
    final depot = _DepotFactice();
    final journal = JournalAuditService(depot: depot);

    await journal.charger(famille: 'zone.');
    await journal.charger(effacerFamille: true);

    expect(depot.familles, ['zone.', null]);
  });
}
