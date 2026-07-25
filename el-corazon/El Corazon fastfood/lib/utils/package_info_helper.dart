import 'dart:io';

import 'package:flutter/services.dart';

/// Helpers maison pour récupérer les infos de l'app sans package_info_plus.
class PackageInfoHelper {
  static const MethodChannel _channel =
      MethodChannel('dev.flutter.packageinfo');

  static Future<String> get appName async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>('getAppName');
        return result ?? 'My App';
      } catch (_) {
        return 'My App';
      }
    }
    if (Platform.isIOS) {
      return 'My App';
    }
    return 'My App';
  }

  static Future<String> get version async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<String>('getVersion');
        return result ?? '1.0.0';
      } catch (_) {
        return '1.0.0';
      }
    }
    return '1.0.0';
  }
}
