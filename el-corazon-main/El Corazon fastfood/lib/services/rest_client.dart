import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RestClientException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;
  RestClientException(this.message, {this.statusCode, this.body});

  @override
  String toString() => 'RestClientException($message, status=$statusCode)';
}

/// Petit client HTTP unifié (timeouts, headers, logs, JSON).
class RestClient {
  final Duration timeout;
  final Map<String, String> defaultHeaders;

  const RestClient({
    this.timeout = const Duration(seconds: 12),
    this.defaultHeaders = const {
      'Accept': 'application/json',
    },
  });

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final resp = await http
        .get(uri, headers: {...defaultHeaders, ...?headers})
        .timeout(timeout);
    return _decode(resp);
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final encoded = body == null ? null : jsonEncode(body);
    final resp = await http
        .post(
          uri,
          headers: {
            ...defaultHeaders,
            'Content-Type': 'application/json',
            ...?headers,
          },
          body: encoded,
        )
        .timeout(timeout);
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final text = resp.body;
    if (kDebugMode) {
      debugPrint('HTTP ${resp.request?.method} ${resp.request?.url} -> ${resp.statusCode}');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw RestClientException(
        'HTTP error',
        statusCode: resp.statusCode,
        body: text,
      );
    }
    if (text.isEmpty) return <String, dynamic>{};
    final decoded = json.decode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}


