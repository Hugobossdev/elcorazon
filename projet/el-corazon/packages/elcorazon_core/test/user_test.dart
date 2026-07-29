import 'package:flutter_test/flutter_test.dart';
import 'package:elcorazon_core/elcorazon_core.dart';

/// Forme exacte de `UserSerializer` (`backend/apps/accounts/serializers.py`),
/// vérifiée côté serveur par `test_inscription_connexion_et_me_renvoient_les_memes_cles`.
const _payload = {
  'id': '019fa420-854a-7076-89c3-96eea7b8cf80',
  'email': 'courier-test@elcorazon.test',
  'phone': '+22890111111',
  'full_name': 'Kodjo Test',
  'user_type': 'courier',
  'avatar': null,
  'is_active': true,
  'email_verified_at': null,
  'phone_verified_at': null,
  'last_seen_at': null,
  'permissions': <String>[],
  'created_at': '2026-07-27T10:00:00Z',
  'updated_at': '2026-07-27T10:00:00Z',
};

void main() {
  group('User.fromJson', () {
    test('lit tous les champs du contrat', () {
      final user = User.fromJson(_payload);

      expect(user.id, '019fa420-854a-7076-89c3-96eea7b8cf80');
      expect(user.userType, UserAccountType.courier);
      expect(user.phone, '+22890111111');
      expect(user.avatar, isNull);
      expect(user.permissions, isEmpty);
      expect(user.createdAt, DateTime.parse('2026-07-27T10:00:00Z'));
    });

    test('un compte staff porte ses permissions', () {
      final user = User.fromJson({
        ..._payload,
        'user_type': UserAccountType.staff,
        'permissions': ['orders.refund', 'orders.read'],
      });

      expect(user.hasPermission('orders.refund'), isTrue);
      expect(user.hasPermission('orders.write'), isFalse);
    });

    test('created_at absent fait échouer bruyamment (ADR-009 : jamais nul)', () {
      final incomplete = {..._payload}..remove('created_at');

      expect(() => User.fromJson(incomplete), throwsA(isA<TypeError>()));
    });
  });
}
