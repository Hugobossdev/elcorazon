import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Permissions du back-office — ce que le serveur accorde, et rien d'autre.
///
/// Jusqu'au 1er août 2026, les rôles n'étaient appliqués que par l'interface :
/// un « Opérateur » privé d'un module en voyait l'onglet disparaître, puis
/// appelait son API sans obstacle. Le vocabulaire local (`manage_marketing`,
/// `manage_settings`) n'existait que dans le client.
///
/// Ces tests gardent le contrat du registre : `domaine.action`, lu depuis le
/// serveur, jamais recopié.
void main() {
  eccore.AdminRole role(List<String> permissions, {bool systeme = false}) {
    return eccore.AdminRole(
      id: 'role-1',
      name: 'Opérateur',
      description: '',
      permissions: permissions,
      isSystem: systeme,
      createdAt: DateTime(2026, 8),
    );
  }

  group('Registre des permissions', () {
    test('le domaine se lit avant le point', () {
      const entree = eccore.PermissionEntry(
        code: 'orders.refund',
        description: 'Rembourser tout ou partie d’une commande',
      );

      // C'est ce qui permet à l'écran de grouper par domaine sans table de
      // correspondance à entretenir.
      expect(entree.domain, 'orders');
    });

    test('une entrée se lit depuis le JSON du serveur', () {
      final entree = eccore.PermissionEntry.fromJson({
        'code': 'catalog.write',
        'description': 'Créer et modifier articles, catégories et options',
      });

      expect(entree.code, 'catalog.write');
      expect(entree.domain, 'catalog');
      expect(entree.description, isNotEmpty);
    });
  });

  group('Rôles', () {
    test('un rôle système est signalé comme non modifiable', () {
      // Le serveur refuse (403) ; l'écran doit le dire avant d'essayer.
      expect(role(const [], systeme: true).isSystem, isTrue);
      expect(role(const []).isSystem, isFalse);
    });

    test('un rôle sans permission n’accorde rien', () {
      expect(role(const []).permissions, isEmpty);
    });

    test('les permissions restent des codes serveur, pas des libellés', () {
      final r = role(const ['orders.read', 'orders.refund']);

      // Un libellé traduit ne serait accepté par aucune route.
      expect(r.permissions, contains('orders.read'));
      expect(r.permissions.every((p) => p.contains('.')), isTrue);
    });

    test('un rôle se lit depuis le JSON du serveur', () {
      final r = eccore.AdminRole.fromJson({
        'id': 'role-2',
        'name': 'Manager',
        'description': 'Gestion des opérations quotidiennes',
        'permissions': ['catalog.read', 'catalog.write', 'orders.read'],
        'is_system': false,
        'created_at': '2026-08-01T10:00:00Z',
      });

      expect(r.name, 'Manager');
      expect(r.permissions, hasLength(3));
      expect(r.isSystem, isFalse);
    });
  });

  group('Compte du personnel', () {
    test('les permissions sont l’union calculée par le serveur', () {
      final membre = eccore.StaffMember.fromJson({
        'id': 'staff-1',
        'email': 'agent@elcorazon.test',
        'full_name': 'Agent',
        'is_active': true,
        'roles': ['role-1', 'role-2'],
        'restaurants': ['el-corazon-lome'],
        'permissions': ['orders.read', 'catalog.read'],
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      });

      // La recomposer côté client à partir des rôles dériverait le jour où un
      // rôle change sans que l'écran ait rechargé la liste.
      expect(membre.hasPermission('orders.read'), isTrue);
      expect(membre.hasPermission('orders.refund'), isFalse);
    });

    test('un compte désactivé reste lisible', () {
      final membre = eccore.StaffMember.fromJson({
        'id': 'staff-2',
        'email': 'ancien@elcorazon.test',
        'full_name': 'Ancien',
        'is_active': false,
        'roles': <String>[],
        'restaurants': <String>[],
        'permissions': <String>[],
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T10:00:00Z',
      });

      // Il n'est jamais supprimé : son identifiant figure dans les journaux
      // de transitions de statut et de remboursements.
      expect(membre.isActive, isFalse);
      expect(membre.fullName, 'Ancien');
    });
  });
}
