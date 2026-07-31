/// Appel client ↔ livreur — miroir de `CallSerializer`
/// (`backend/apps/calls/serializers.py`).
///
/// Le média reste en pair-à-pair chez Agora ; ce modèle ne porte que la
/// signalisation. [channelName] est **dérivé de l'appel côté serveur** et non
/// composé par le client : l'app fabriquait `order_{id}_call`, si bien que
/// connaître un identifiant de commande suffisait à rejoindre la conversation.
class Call {
  const Call({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.status,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.channelName,
    required this.durationSeconds,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String,
      orderId: json['order'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      callerId: json['caller'] as String,
      callerName: json['caller_name'] as String? ?? '',
      calleeId: json['callee'] as String,
      calleeName: json['callee_name'] as String? ?? '',
      channelName: json['channel_name'] as String,
      answeredAt:
          json['answered_at'] == null ? null : DateTime.parse(json['answered_at'] as String),
      endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String orderId;

  /// `voice` | `video` (`CallKind`).
  final String kind;

  /// `ringing` | `accepted` | `declined` | `ended` | `missed` (`CallStatus`).
  /// Les quatre issues sont terminales côté serveur : raccrocher deux fois ne
  /// compte pas deux durées.
  final String status;

  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String channelName;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final DateTime createdAt;

  bool get isRinging => status == 'ringing';
  bool get isActive => status == 'ringing' || status == 'accepted';
}

/// De quoi rejoindre le canal Agora — miroir de `RtcCredentialsSerializer`.
///
/// Le certificat d'application n'y figure pas : il signe le jeton côté serveur
/// et ne quitte jamais celui-ci. L'app l'embarquait auparavant dans son `.env`,
/// c'est-à-dire dans un binaire distribué.
class RtcCredentials {
  const RtcCredentials({
    required this.channelName,
    required this.token,
    required this.uid,
    required this.appId,
    required this.expiresIn,
  });

  factory RtcCredentials.fromJson(Map<String, dynamic> json) {
    return RtcCredentials(
      channelName: json['channel_name'] as String,
      token: json['token'] as String,
      uid: json['uid'] as int,
      appId: json['app_id'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }

  final String channelName;
  final String token;

  /// `1` pour l'appelant, `2` pour le destinataire — attribué par le serveur.
  /// L'app dérivait cet entier d'un hachage tronqué d'UUID, qui peut entrer en
  /// collision : deux participants au même `uid` s'expulsent du canal.
  final int uid;
  final String appId;
  final int expiresIn;
}
