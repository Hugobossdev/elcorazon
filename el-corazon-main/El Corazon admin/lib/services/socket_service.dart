import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket _socket;
  bool _isConnected = false;

  // Change this to your backend URL
  static const String _serverUrl = 'http://10.0.2.2:3000';

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void init() {
    _socket = IO.io(
        _serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('✅ [SocketService] Connected to $_serverUrl');
      _isConnected = true;
      // Join admin channel
      _socket.emit('join_room', 'admin_drivers');
    });

    _socket.onDisconnect((_) {
      debugPrint('❌ [SocketService] Disconnected');
      _isConnected = false;
    });
  }

  bool get isConnected => _isConnected;

  void onDriverLocation(Function(dynamic) callback) {
    _socket.on('driver_location', (data) {
      callback(data);
    });
  }

  void onNewOrder(Function(dynamic) callback) {
    _socket.on('new_order', (data) {
      callback(data);
    });
  }

  void onOrderUpdate(Function(dynamic) callback) {
    _socket.on('order_update', (data) {
      callback(data);
    });
  }

  void dispose() {
    _socket.disconnect();
  }
}
