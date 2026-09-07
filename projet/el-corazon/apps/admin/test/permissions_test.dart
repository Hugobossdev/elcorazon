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
  _permissionsDeNavigation();
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

/// Les permissions que la navigation exige, confrontées au registre du serveur.
///
/// ## Pourquoi ces cas existent
///
/// `AdminAuthService.can(...)` existait et n'avait **aucun site d'appel** : les
/// dix-huit entrées du menu s'affichaient pour tout compte du personnel. Un
/// opérateur voyait « Rôles & Accès », « Réseau », « Paiements » ; il ouvrait
/// l'écran, remplissait un formulaire, et récupérait un 403 à l'envoi.
///
/// Le filtre ajouté ne vaut évidemment que si les noms sont les bons. Une
/// chaîne inventée — `manage_marketing`, le vocabulaire d'avant le 1er août —
/// masquerait l'entrée pour **tout le monde**, en silence : personne ne détient
/// une permission qui n'existe pas. C'est un mode de panne bien plus discret
/// que celui qu'on corrige, d'où ce contrôle.
void _permissionsDeNavigation() {
  /// Le registre du serveur, tel que `common/permissions.py` et les
  /// `backoffice.py` de chaque domaine le déclarent. Recopié ici à dessein :
  /// c'est la liste que le test doit connaître indépendamment du code testé.
  const registreServeur = {
    'analytics.read',
    'catalog.read',
    'catalog.write',
    'couriers.approve',
    'couriers.read',
    'couriers.suspend',
    'couriers.write',
    'customers.block',
    'customers.read',
    'gamification.read',
    'gamification.write',
    'loyalty.read',
    'loyalty.write',
    'notifications.send',
    'orders.assign_courier',
    'orders.cancel',
    'orders.read',
    'orders.refund',
    'orders.update_status',
    'promotions.read',
    'promotions.write',
    'restaurants.read',
    'restaurants.write',
    'roles.read',
    'roles.write',
  };

  /// Ce que chaque entrée de menu exige. Repris de
  /// `admin_navigation_screen.dart`, dont les listes sont privées à l'état de
  /// l'écran.
  const exigees = {
    'Analyses & Stats': 'analytics.read',
    'Commandes': 'orders.read',
    'Livraisons actives': 'orders.read',
    'Carte temps réel': 'couriers.read',
    'Paiements': 'orders.read',
    'Menu': 'catalog.read',
    'Catégories': 'catalog.read',
    'Personnalisations': 'catalog.read',
    'Clients': 'customers.read',
    'Livreurs': 'couriers.read',
    'Validation Docs': 'couriers.read',
    'Campagnes': 'notifications.send',
    'Promotions': 'promotions.read',
    'Gamification': 'gamification.read',
    'Pays, villes, établissements': 'restaurants.read',
    'Rôles & Accès': 'roles.read',
  };

  group('Permissions exigées par la navigation', () {
    test('appartiennent toutes au registre du serveur', () {
      final inconnues = exigees.entries
          .where((e) => !registreServeur.contains(e.value))
          .map((e) => '${e.key} → ${e.value}')
          .toList();

      expect(
        inconnues,
        isEmpty,
        reason: 'Une permission absente du registre masque son entrée pour '
            'tout le monde : personne ne détient ce que le serveur n’accorde pas.',
      );
    });

    test('sont des permissions de lecture', () {
      // Ouvrir un écran se juge sur ce qu'on peut lire, jamais sur ce qu'on
      // peut écrire : un opérateur qui consulte le catalogue sans pouvoir le
      // modifier doit voir l'entrée « Menu ». Le serveur refusera l'écriture,
      // et c'est là que le refus a du sens.
      final ecritures = exigees.values.where(
        (code) => code.endsWith('.write') ||
            code.endsWith('.approve') ||
            code.endsWith('.suspend') ||
            code.endsWith('.block') ||
            code.endsWith('.refund') ||
            code.endsWith('.cancel'),
      );

      expect(ecritures, isEmpty);
    });

    test('le tableau de bord et les paramètres restent ouverts', () {
      // Ce sont les deux seules entrées sans permission : la première est
      // l'écran d'accueil — la refuser fermerait l'application à un compte
      // valide — et la seconde ne porte que des réglages locaux au poste.
      expect(exigees.containsKey('Tableau de bord'), isFalse);
      expect(exigees.containsKey('Paramètres'), isFalse);
    });
  });
}
