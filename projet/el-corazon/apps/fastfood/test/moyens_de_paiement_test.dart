import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/presentation/moyens_de_paiement.dart';

List<eccore.AcceptedPaymentMethod> _serveur(List<String> codes) => [
      for (final code in codes) eccore.AcceptedPaymentMethod(code: code, label: 'lib-$code'),
    ];

void main() {
  group('moyensProposes', () {
    test('suit l’ordre et les libellés du serveur', () {
      final proposes = moyensProposes(_serveur(['cash', 'mobile_money']));

      expect(proposes.map((p) => p.moyen), [PaymentMethod.cash, PaymentMethod.mobileMoney]);
      expect(proposes.first.libelle, 'lib-cash');
    });

    test('écarte un code inconnu plutôt que de le rabattre sur un autre', () {
      final proposes = moyensProposes(_serveur(['crypto', 'card']));

      expect(proposes.map((p) => p.moyen), [PaymentMethod.creditCard]);
    });
  });

  group('moyenRetenu', () {
    test('garde le choix du client tant qu’il est accepté', () {
      final proposes = moyensProposes(_serveur(['cash', 'mobile_money']));

      expect(moyenRetenu(PaymentMethod.mobileMoney, proposes), PaymentMethod.mobileMoney);
    });

    test('retombe sur le premier accepté, ou sur rien', () {
      expect(
        moyenRetenu(PaymentMethod.wallet, moyensProposes(_serveur(['cash']))),
        PaymentMethod.cash,
      );
      expect(moyenRetenu(null, const []), isNull);
    });
  });

  group('moyenPourLeGroupe', () {
    test('préfère un moyen en ligne, chaque convive payant sa part', () {
      final proposes = moyensProposes(_serveur(['cash', 'card', 'mobile_money']));

      expect(moyenPourLeGroupe(proposes), PaymentMethod.mobileMoney);
    });

    test('à défaut, le premier accepté — le serveur tranchera', () {
      expect(moyenPourLeGroupe(moyensProposes(_serveur(['cash']))), PaymentMethod.cash);
    });
  });
}
