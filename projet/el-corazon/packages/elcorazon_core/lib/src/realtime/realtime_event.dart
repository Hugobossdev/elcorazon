/// Événement reçu sur un canal temps réel (`ws/orders/{id}/tracking/`,
/// `ws/orders/{id}/chat/`, ...) — miroir de ce qu'envoie
/// `common.consumers.AuthorizedConsumer.realtime_event`/`_catch_up` :
/// `seq`/`type` fusionnés avec la charge au même niveau JSON.
class RealtimeEvent {
  const RealtimeEvent({required this.seq, required this.type, required this.payload});

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final payload = Map<String, dynamic>.from(json)
      ..remove('seq')
      ..remove('type');
    return RealtimeEvent(
      seq: json['seq'] as int,
      type: json['type'] as String,
      payload: payload,
    );
  }

  final int seq;
  final String type;
  final Map<String, dynamic> payload;
}
