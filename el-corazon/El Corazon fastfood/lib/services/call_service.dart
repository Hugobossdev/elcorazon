import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/services/agora_service.dart';
import 'package:elcora_fast/services/notification_service.dart';
// Permission handling - using platform channels or checking at runtime

/// État d'un appel
enum CallState {
  idle,
  calling, // Appel en cours d'établissement
  ringing, // Sonne
  connected, // Connecté
  ended, // Terminé
  rejected, // Rejeté
  missed, // Manqué
  failed, // Échoué
}

/// Type d'appel
enum CallType {
  voice, // Appel vocal uniquement
  video, // Appel vidéo (pour future implémentation)
}

/// Direction de l'appel
enum CallDirection {
  outgoing, // Appel sortant
  incoming, // Appel entrant
}

/// Modèle d'appel
class Call {
  final String id;
  final String orderId;
  final String callerId;
  final String receiverId;
  final String? callerName;
  final String? receiverName;
  final CallType type;
  final CallDirection direction;
  final CallState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration; // Durée en secondes
  final String? channelId; // Canal Agora

  Call({
    required this.id,
    required this.orderId,
    required this.callerId,
    required this.receiverId,
    required this.direction,
    required this.createdAt,
    this.callerName,
    this.receiverName,
    this.type = CallType.voice,
    this.state = CallState.idle,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.channelId,
  });

  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      callerId: map['caller_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString() ?? '',
      callerName: map['caller_name']?.toString(),
      receiverName: map['receiver_name']?.toString(),
      type:
          map['type']?.toString() == 'video' ? CallType.video : CallType.voice,
      direction: map['direction']?.toString() == 'incoming'
          ? CallDirection.incoming
          : CallDirection.outgoing,
      state: _parseCallState(map['state']?.toString()),
      createdAt: DateTime.parse(map['created_at']?.toString() ?? ''),
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'].toString())
          : null,
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'].toString())
          : null,
      duration: map['duration'] as int?,
      channelId: map['channel_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'caller_name': callerName,
      'receiver_name': receiverName,
      'type': type == CallType.video ? 'video' : 'voice',
      'direction':
          direction == CallDirection.incoming ? 'incoming' : 'outgoing',
      'state': state.name,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration': duration,
      'channel_id': channelId,
    };
  }

  static CallState _parseCallState(String? state) {
    switch (state) {
      case 'calling':
        return CallState.calling;
      case 'ringing':
        return CallState.ringing;
      case 'connected':
        return CallState.connected;
      case 'ended':
        return CallState.ended;
      case 'rejected':
        return CallState.rejected;
      case 'missed':
        return CallState.missed;
      case 'failed':
        return CallState.failed;
      default:
        return CallState.idle;
    }
  }
}

/// Service de gestion des appels entre livreur et client
class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AgoraService _agoraService = AgoraService();
  final NotificationService _notificationService = NotificationService();

  Call? _currentCall;
  StreamSubscription<Map<String, dynamic>>? _callSubscription;
  RealtimeChannel? _callChannel;

  // Streams
  final StreamController<Call> _callStateController =
      StreamController<Call>.broadcast();
  final StreamController<Call> _incomingCallController =
      StreamController<Call>.broadcast();

  Stream<Call> get callStateStream => _callStateController.stream;
  Stream<Call> get incomingCallStream => _incomingCallController.stream;

  Call? get currentCall => _currentCall;
  bool get isInCall =>
      _currentCall != null &&
      (_currentCall!.state == CallState.connected ||
          _currentCall!.state == CallState.ringing ||
          _currentCall!.state == CallState.calling);

  /// Initialise le service d'appel
  Future<void> initialize({required String userId}) async {
    try {
      // S'abonner aux appels entrants
      _callChannel = _supabase
          .channel('calls_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'calls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: userId,
            ),
            callback: (payload) {
              final callData = payload.newRecord;
              final call = Call.fromMap(callData);
              if (call.state == CallState.ringing) {
                _handleIncomingCall(call);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'calls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: userId,
            ),
            callback: (payload) {
              final callData = payload.newRecord;
              final call = Call.fromMap(callData);
              _handleCallUpdate(call);
            },
          )
          .subscribe();

      debugPrint('CallService: Initialisé pour l\'utilisateur $userId');
    } catch (e) {
      debugPrint('CallService: Erreur d\'initialisation - $e');
    }
  }

  /// Gère un appel entrant
  void _handleIncomingCall(Call call) {
    _currentCall = call;
    _incomingCallController.add(call);
    notifyListeners();

    // Afficher une notification
    _notificationService.showOrderConfirmationNotification(
      call.orderId,
      'Appel entrant de ${call.callerName ?? "Livreur"}',
    );
  }

  /// Gère une mise à jour d'appel
  void _handleCallUpdate(Call call) {
    _currentCall = call;
    _callStateController.add(call);
    notifyListeners();

    // Si l'appel est terminé, nettoyer
    if (call.state == CallState.ended ||
        call.state == CallState.rejected ||
        call.state == CallState.missed) {
      _currentCall = null;
    }
  }

  /// Initie un appel sortant
  Future<Call?> initiateCall({
    required String orderId,
    required String callerId,
    required String receiverId,
    String? callerName,
    String? receiverName,
    CallType type = CallType.voice,
  }) async {
    try {
      // Vérifier les permissions
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        debugPrint('CallService: Permissions refusées');
        return null;
      }

      // Générer un ID de canal unique basé sur la commande
      final channelId = 'order_${orderId}_call';

      // Créer l'appel en base de données
      final callResponse = await _supabase
          .from('calls')
          .insert({
            'order_id': orderId,
            'caller_id': callerId,
            'receiver_id': receiverId,
            'caller_name': callerName,
            'receiver_name': receiverName,
            'type': type == CallType.video ? 'video' : 'voice',
            'direction': 'outgoing',
            'state': 'calling',
            'channel_id': channelId,
          })
          .select()
          .single();

      final call = Call.fromMap(callResponse);

      // Initialiser Agora
      await _agoraService.initialize();
      final uid = callerId.hashCode.abs() % 2147483647;
      final joined = await _agoraService.joinChannel(channelId, uid: uid);

      if (!joined) {
        // Marquer l'appel comme échoué
        await _updateCallState(call.id, CallState.failed);
        return null;
      }

      // Mettre à jour l'état de l'appel
      await _updateCallState(call.id, CallState.ringing);

      _currentCall = call;
      notifyListeners();

      return call;
    } catch (e) {
      debugPrint('CallService: Erreur lors de l\'initiation de l\'appel - $e');
      return null;
    }
  }

  /// Accepte un appel entrant
  Future<bool> acceptCall(Call call) async {
    try {
      // Vérifier les permissions
      final hasPermission = await _checkPermissions();
      if (!hasPermission) {
        return false;
      }

      // Initialiser Agora et rejoindre le canal
      await _agoraService.initialize();
      final uid = call.receiverId.hashCode.abs() % 2147483647;
      final joined = await _agoraService.joinChannel(
        call.channelId ?? 'order_${call.orderId}_call',
        uid: uid,
      );

      if (!joined) {
        await _updateCallState(call.id, CallState.failed);
        return false;
      }

      // Mettre à jour l'état de l'appel
      await _supabase.from('calls').update({
        'state': 'connected',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('id', call.id);

      _currentCall = Call.fromMap({
        ...call.toMap(),
        'state': 'connected',
        'started_at': DateTime.now().toIso8601String(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CallService: Erreur lors de l\'acceptation de l\'appel - $e');
      return false;
    }
  }

  /// Rejette un appel entrant
  Future<void> rejectCall(Call call) async {
    try {
      await _updateCallState(call.id, CallState.rejected);
      _currentCall = null;
      notifyListeners();
    } catch (e) {
      debugPrint('CallService: Erreur lors du rejet de l\'appel - $e');
    }
  }

  /// Termine un appel
  Future<void> endCall() async {
    if (_currentCall == null) return;

    try {
      final call = _currentCall!;
      final now = DateTime.now();
      final duration = call.startedAt != null
          ? now.difference(call.startedAt!).inSeconds
          : 0;

      // Mettre à jour l'appel en base de données
      await _supabase.from('calls').update({
        'state': 'ended',
        'ended_at': now.toIso8601String(),
        'duration': duration,
      }).eq('id', call.id);

      // Quitter le canal Agora
      await _agoraService.leaveChannel();

      _currentCall = null;
      notifyListeners();
    } catch (e) {
      debugPrint('CallService: Erreur lors de la fin de l\'appel - $e');
    }
  }

  /// Met à jour l'état d'un appel
  Future<void> _updateCallState(String callId, CallState state) async {
    try {
      await _supabase
          .from('calls')
          .update({'state': state.name}).eq('id', callId);
    } catch (e) {
      debugPrint('CallService: Erreur mise à jour état appel - $e');
    }
  }

  /// Vérifie les permissions nécessaires
  /// Note: Les permissions sont gérées par Agora SDK automatiquement
  Future<bool> _checkPermissions() async {
    try {
      // Agora SDK gère les permissions automatiquement
      // On retourne true par défaut, Agora demandera les permissions si nécessaire
      return true;
    } catch (e) {
      debugPrint('CallService: Erreur vérification permissions - $e');
      return false;
    }
  }

  /// Récupère l'historique des appels pour une commande
  Future<List<Call>> getCallHistory(String orderId) async {
    try {
      final response = await _supabase
          .from('calls')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => Call.fromMap(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('CallService: Erreur récupération historique - $e');
      return [];
    }
  }

  /// Nettoie les ressources
  @override
  void dispose() {
    _callSubscription?.cancel();
    _callChannel?.unsubscribe();
    _callStateController.close();
    _incomingCallController.close();
    super.dispose();
  }
}
