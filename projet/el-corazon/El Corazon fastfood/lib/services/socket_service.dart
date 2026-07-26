import '../config/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket _socket;
  bool _isConnected = false;
  bool _isInitialized = false;

  // Change this to your backend URL
  // For Android Emulator: http://10.0.2.2:3000
  // For iOS Simulator: http://localhost:3000
  // For Physical Device: Your PC's IP address
  static String get _serverUrl => ApiConfig.backendUrl;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void init() {
    if (_isInitialized) {
      debugPrint('⚠️ [SocketService] Already initialized, skipping...');
      return;
    }

    debugPrint('🔌 [SocketService] Initializing connection to $_serverUrl');

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setTimeout(20000) // 20 secondes de timeout pour Render.com
          .enableReconnection() // Activer la reconnexion automatique
          .setReconnectionDelay(2000) // 2 secondes de délai initial
          .setReconnectionDelayMax(5000) // 5 secondes de délai max
          .setReconnectionAttempts(99999) // Tentatives quasi infinies
          .build(),
    );

    _socket.onConnect((_) {
      debugPrint('✅ [SocketService] Connected to $_serverUrl');
      _isConnected = true;
    });

    _socket.onDisconnect((reason) {
      debugPrint('❌ [SocketService] Disconnected: $reason');
      _isConnected = false;
    });

    _socket.onConnectError((error) {
      debugPrint('⚠️ [SocketService] Connection Error: $error');
      debugPrint('   Server URL: $_serverUrl');
      _isConnected = false;
    });

    _socket.onConnectTimeout((_) {
      debugPrint('⏱️ [SocketService] Connection Timeout');
      debugPrint('   Server URL: $_serverUrl');
      _isConnected = false;
    });

    _socket.onError((error) {
      debugPrint('💥 [SocketService] Socket Error: $error');
    });

    _isInitialized = true;
    _socket.connect();
  }

  bool get isConnected => _isConnected;

  void joinRoom(String room) {
    if (!_isConnected) return;
    _socket.emit('join_room', room);
    debugPrint('➡️ [SocketService] Joined room: $room');
  }

  void leaveRoom(String room) {
    if (!_isConnected) return;
    _socket.emit('leave_room', room);
    debugPrint('⬅️ [SocketService] Left room: $room');
  }

  void onOrderUpdate(Function(dynamic) callback) {
    _socket.on('order_status', (data) {
      debugPrint('🔔 [SocketService] Order Update: $data');
      callback(data);
    });
  }

  void onDriverLocation(Function(dynamic) callback) {
    _socket.on('driver_location', (data) {
      // debugPrint('📍 [SocketService] Driver Location: $data');
      callback(data);
    });
  }

  void dispose() {
    _socket.disconnect();
  }
}
