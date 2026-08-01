import '../network/api_client.dart';
import 'admin_role.dart';
import 'customer.dart';
import 'customer_stats.dart';

/// Administration des comptes — `/api/v1/administration/`,
/// `/api/v1/restaurants/staff/` et la fiche client de `/api/v1/analytics/`
/// (`backend/apps/accounts/backoffice.py`).
///
/// Trois choses que l'implémentation précédente laissait au client et qui sont
/// désormais des décisions du serveur :
///
/// * **le blocage révoque les jetons.** Écrire `is_active = false` dans une
///   table ne ferme rien pendant la durée de vie des jetons en circulation :
///   le compte bloqué continuait de commander jusqu'à expiration ;
/// * **les rôles sont appliqués.** Ils n'existaient que côté interface, si
///   bien qu'un « Opérateur » privé du module marketing pouvait appeler l'API
///   marketing sans obstacle ;
/// * **le registre des permissions vient du code**, il ne se recopie plus dans
///   l'écran qui compose un rôle.
///
/// Un client ne s'édite pas ici : son nom, son adresse électronique et son
/// téléphone sont ses données, qu'il modifie depuis son application. Les rendre
/// modifiables au back-office ouvrirait un chemin de reprise de compte par
/// « mot de passe oublié ».
class AdministrationRepository {
  AdministrationRepository({required this.apiClient});

  final ApiClient apiClient;

  // -------------------------------------------------------------- clients

  /// Comptes clients — le serveur filtre déjà sur le type de compte.
  Future<List<Customer>> customers({bool? isActive, String? search}) {
    return _collect(
      '/administration/customers/',
      Customer.fromJson,
      queryParameters: {
        if (isActive != null) 'is_active': isActive.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  Future<Customer> customer(String customerId) async {
    final response = await apiClient.get('/administration/customers/$customerId/');
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ferme un compte et révoque ses jetons (permission `customers.block`).
  ///
  /// Le motif est exigé par le serveur : un compte fermé sans motif est un
  /// litige qu'on ne saura pas instruire six mois plus tard, quand le client
  /// rappellera.
  Future<Customer> blockCustomer({
    required String customerId,
    required String reason,
  }) async {
    final response = await apiClient.post(
      '/administration/customers/$customerId/block/',
      data: {'reason': reason},
    );
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Customer> unblockCustomer(String customerId) async {
    final response = await apiClient.post(
      '/administration/customers/$customerId/unblock/',
    );
    return Customer.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fiche chiffrée d'un client — commandes, dépense, adresses, fidélité.
  Future<CustomerStats> customerStats(String customerId) async {
    final response = await apiClient.get(
      '/analytics/reports/customers/$customerId/',
    );
    return CustomerStats.fromJson(response.data as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------- rôles

  Future<List<AdminRole>> roles() {
    return _collect('/administration/roles/', AdminRole.fromJson);
  }

  /// Registre des permissions tel qu'il est dans le code du serveur.
  Future<List<PermissionEntry>> permissionRegistry() async {
    final response = await apiClient.get('/administration/roles/permissions/');
    final data = response.data as List<dynamic>;
    return data
        .map((json) => PermissionEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<AdminRole> createRole({
    required String name,
    required List<String> permissions,
    String description = '',
  }) async {
    final response = await apiClient.post(
      '/administration/roles/',
      data: {
        'name': name,
        'description': description,
        'permissions': permissions,
      },
    );
    return AdminRole.fromJson(response.data as Map<String, dynamic>);
  }

  /// Modifie un rôle. Le serveur refuse les rôles système (403).
  ///
  /// Il n'y a **pas** de suppression : un rôle retiré à chaud priverait sans
  /// préavis les comptes qui le portent, et l'effet ne se verrait qu'au
  /// prochain refus. Un rôle qui ne sert plus se vide de ses permissions.
  Future<AdminRole> updateRole({
    required String roleId,
    String? name,
    String? description,
    List<String>? permissions,
  }) async {
    final response = await apiClient.patch(
      '/administration/roles/$roleId/',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (permissions != null) 'permissions': permissions,
      },
    );
    return AdminRole.fromJson(response.data as Map<String, dynamic>);
  }

  // ------------------------------------------------------------ personnel

  /// Comptes du personnel des établissements du compte connecté.
  Future<List<StaffMember>> staff({bool? isActive, String? search}) {
    return _collect(
      '/restaurants/staff/',
      StaffMember.fromJson,
      queryParameters: {
        if (isActive != null) 'is_active': isActive.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  /// Remplace les rôles d'un membre du personnel.
  ///
  /// En bloc et non par ajout : « quels rôles porte ce compte » est la question
  /// que pose l'écran, et un verbe d'ajout obligerait à en écrire un de retrait,
  /// avec deux chemins pour un même état.
  Future<StaffMember> assignRoles({
    required String staffId,
    required List<String> roleIds,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/staff/$staffId/',
      data: {'roles': roleIds},
    );
    return StaffMember.fromJson(response.data as Map<String, dynamic>);
  }

  /// Désactive un compte du personnel — le serveur révoque ses jetons.
  ///
  /// Jamais de suppression : ce compte a signé des transitions de statut, des
  /// remboursements et des validations de dossier, et son identifiant figure
  /// dans ces journaux.
  Future<StaffMember> setStaffActive({
    required String staffId,
    required bool isActive,
  }) async {
    final response = await apiClient.patch(
      '/restaurants/staff/$staffId/',
      data: {'is_active': isActive},
    );
    return StaffMember.fromJson(response.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- interne

  /// Suit `next` jusqu'au bout : une liste tronquée à la première page ferait
  /// disparaître des comptes d'un écran d'administration sans rien signaler.
  Future<List<T>> _collect<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final items = <T>[];
    String? next = path;
    Map<String, dynamic>? parametres = queryParameters;

    while (next != null) {
      final response = await apiClient.get(next, queryParameters: parametres);
      final body = response.data;

      if (body is List<dynamic>) {
        items.addAll(body.map((json) => fromJson(json as Map<String, dynamic>)));
        break;
      }

      final page = body as Map<String, dynamic>;
      items.addAll(
        (page['results'] as List<dynamic>).map(
          (json) => fromJson(json as Map<String, dynamic>),
        ),
      );
      next = page['next'] as String?;
      parametres = null;
    }

    return items;
  }
}
