import 'package:elcorazon_core/src/network/api_client.dart';
import 'package:elcorazon_core/src/network/page.dart';

/// Le journal des décisions d'exploitation — `/restaurants/audit/`
/// (`backend/common/audit.py`, `AuditEntryViewSet`).
///
/// Il était écrit à chaque changement de barème, de zone ou d'emplacement, et
/// ne se lisait nulle part. Il consigne désormais aussi les **droits** :
/// permissions d'un rôle, rôles et périmètre d'un compte du personnel, blocage
/// d'un client — motif compris.

/// Une décision consignée, avec sa valeur d'avant.
class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.before,
    required this.after,
    required this.createdAt,
    this.actorName,
  });

  factory AuditRecord.fromJson(Map<String, dynamic> json) => AuditRecord(
        id: json['id'] as String,
        actorName: json['actor_name'] as String?,
        action: json['action'] as String,
        targetType: json['target_type'] as String,
        targetId: json['target_id'] as String,
        targetLabel: json['target_label'] as String? ?? '',
        before: Map<String, dynamic>.from(json['before'] as Map? ?? const {}),
        after: Map<String, dynamic>.from(json['after'] as Map? ?? const {}),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;

  /// Nul pour un changement sans auteur — commande de peuplement, `shell`.
  final String? actorName;

  /// `domaine.objet` — `zone.tariff`, `staff.roles`…
  final String action;
  final String targetType;
  final String targetId;

  /// Le nom de la cible **au moment du changement** : il reste lisible même
  /// si elle a été renommée ou retirée depuis.
  final String targetLabel;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final DateTime createdAt;

  /// Les clés dont la valeur a changé, dans l'ordre où elles apparaissent.
  ///
  /// Une entrée porte parfois plusieurs champs dont un seul a bougé (l'adresse
  /// avec la position) : montrer d'abord ce qui a changé épargne de comparer
  /// deux blocs à l'œil.
  List<String> get clesModifiees => [
        for (final cle in {...before.keys, ...after.keys})
          if ('${before[cle]}' != '${after[cle]}') cle,
      ];
}

/// Familles d'actions, telles que le filtre les propose.
///
/// Le filtre part au serveur en `action__startswith` : « staff. » couvre les
/// rôles, le périmètre, l'activation et le mot de passe d'un compte.
abstract final class FamilleAudit {
  static const familles = <String, String>{
    'role.': 'Rôles',
    'staff.': 'Personnel',
    'customer.': 'Clients',
    'zone.': 'Zones et barèmes',
    'restaurant.': 'Établissements',
    'country.': 'Pays',
    // L'argent qui sort, et ceux qui le reçoivent : ce qu'on vient le plus
    // souvent chercher dans un journal, et que les familles ne proposaient pas.
    'refund.': 'Remboursements',
    'payout.': 'Versements livreurs',
    'courier.': 'Dossiers livreurs',
    'review.': 'Avis',
  };

  /// Libellé d'une action. Une action inconnue s'affiche telle quelle.
  static String libelle(String action) => switch (action) {
        'role.permissions' => 'Permissions d’un rôle',
        'staff.roles' => 'Rôles d’un compte',
        'staff.scope' => 'Périmètre d’un compte',
        'staff.activation' => 'Activation d’un compte',
        'staff.password' => 'Mot de passe remplacé',
        'customer.block' => 'Blocage d’un client',
        'zone.tariff' => 'Barème de zone',
        'zone.boundary' => 'Contour de zone',
        'zone.create' => 'Création de zone',
        'zone.activation' => 'Ouverture de zone',
        'zone.delete' => 'Suppression de zone',
        'restaurant.create' => 'Ouverture d’un établissement',
        'restaurant.status' => 'État d’un établissement',
        'restaurant.location' => 'Emplacement d’un établissement',
        'restaurant.zone' => 'Zone d’un établissement',
        'country.activation' => 'Ouverture de pays',
        // Les sorties d'argent et les décisions envers un client : écrites au
        // journal depuis longtemps, elles s'y lisaient sous leur nom technique.
        'payout.settle' => 'Versement livreur constaté',
        'payout.reject' => 'Versement livreur refusé',
        'refund.request' => 'Remboursement demandé',
        'refund.settle' => 'Remboursement constaté',
        'refund.cancel' => 'Remboursement abandonné',
        'review.visibility' => 'Visibilité d’un avis',
        'complaint.decision' => 'Décision sur une réclamation',
        'return.decision' => 'Décision sur un retour',
        'ticket.resolution' => 'Résolution d’un ticket',
        'courier.verification' => 'Dossier livreur',
        _ => action,
      };
}

class AuditJournalRepository {
  AuditJournalRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Une page du journal, le plus récent d'abord — `audit.read`.
  ///
  /// Le serveur cloisonne : hors du siège, seules les entrées qui touchent les
  /// établissements du compte, leurs zones et leur personnel sont rendues.
  Future<Page<AuditRecord>> entries({
    String? famille,
    String? recherche,
    DateTime? depuis,
    DateTime? jusqua,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      '/restaurants/audit/',
      queryParameters: {
        'page_size': pageSize,
        if (famille != null) 'action__startswith': famille,
        if (recherche != null && recherche.trim().isNotEmpty) 'search': recherche.trim(),
        if (depuis != null) 'created_at__gte': depuis.toUtc().toIso8601String(),
        if (jusqua != null) 'created_at__lte': jusqua.toUtc().toIso8601String(),
      },
    );
    return Page.fromJson(response.data as Map<String, dynamic>, AuditRecord.fromJson);
  }

  /// La page suivante, par l'URL complète que le serveur a rendue.
  Future<Page<AuditRecord>> pageAt(String url) async {
    final response = await apiClient.get(url);
    return Page.fromJson(response.data as Map<String, dynamic>, AuditRecord.fromJson);
  }
}
