import 'package:flutter/foundation.dart';
import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/rest_client.dart';

class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();
  final RestClient _rest = const RestClient();

  Future<String?> getRtcToken({
    required String channelId,
    required int uid,
    int expireSeconds = 3600,
  }) async {
    try {
      final uri =
          Uri.parse('${ApiConfig.backendUrl}/api/agora/rtc-token').replace(
        queryParameters: {
          'channel': channelId,
          'uid': uid.toString(),
          'expire': expireSeconds.toString(),
        },
      );

      final data = await _rest.getJson(uri);
      return data['token']?.toString();
    } catch (e) {
      debugPrint('AgoraTokenService: error $e');
      return null;
    }
  }
}
