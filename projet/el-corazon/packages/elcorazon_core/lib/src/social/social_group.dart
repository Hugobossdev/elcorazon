/// Groupe social — miroir de `SocialGroupSerializer`
/// (`backend/apps/social/serializers.py`).
///
/// [inviteCode] n'est servi que dans les groupes dont l'appelant est déjà
/// membre (`SocialGroupViewSet.get_queryset`) : c'est ce qui l'empêche de
/// devenir une clé distribuée à qui ne l'a pas. Il ne se fabrique donc jamais
/// côté client, contrairement à l'implémentation Supabase où il était tiré
/// d'un `millisecondsSinceEpoch` — prévisible, et donc devinable.
class SocialGroup {
  const SocialGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.inviteCode,
    required this.isPrivate,
    required this.maxMembers,
    required this.memberCount,
    required this.createdAt,
  });

  factory SocialGroup.fromJson(Map<String, dynamic> json) {
    return SocialGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String,
      inviteCode: json['invite_code'] as String,
      isPrivate: json['is_private'] as bool,
      maxMembers: json['max_members'] as int,
      memberCount: json['member_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String name;
  final String description;

  /// `family` | `friends` | `work` | `neighborhood` | `custom` (`GroupKind`).
  final String kind;
  final String inviteCode;
  final bool isPrivate;
  final int maxMembers;

  /// Compteur tenu par le serveur — l'adhésion le compare à [maxMembers] dans
  /// un `UPDATE` conditionnel unique, jamais recalculé ici.
  final int memberCount;
  final DateTime createdAt;

  bool get isFull => memberCount >= maxMembers;
}
