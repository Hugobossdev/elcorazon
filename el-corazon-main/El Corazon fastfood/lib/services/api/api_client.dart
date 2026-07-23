import 'dart:async';
import 'dart:convert';

import 'package:elcora_fast/config/api_config.dart';
import 'package:elcora_fast/services/api/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Client REST unique pour l'API Laravel (Phase B).
///
/// - Base URL : [ApiConfig.apiBaseUrl].
/// - Attache automatiquement `Authorization: Bearer <token>` si un jeton
///   Sanctum est stocké.
/// - Décode le JSON et lève [ApiException] sur toute réponse non 2xx.
///
/// Le jeton Sanctum étant opaque (non-JWT), il est stocké ici directement dans
/// [FlutterSecureStorage] sous une clé dédiée, indépendamment du
/// `SecureTokenStorageService` (qui valide un format JWT propre à Supabase).
class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String _tokenKey = 'api_sanctum_token';
  static const Duration _timeout = Duration(seconds: 30);

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final http.Client _http = http.Client();

  String? _cachedToken;

  // ---- Gestion du jeton --------------------------------------------------

  Future<void> setToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    _cachedToken ??= await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> get hasToken async => (await getToken())?.isNotEmpty ?? false;

  // ---- Verbes HTTP -------------------------------------------------------

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, String? bearerOverride}) =>
      _send('POST', path, body: body, bearerOverride: bearerOverride);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  // ---- Cœur --------------------------------------------------------------

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    String? bearerOverride,
  }) async {
    final uri = _buildUri(path, query);
    final headers = await _buildHeaders(bearerOverride: bearerOverride);

    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Délai dépassé. Vérifiez votre connexion.');
    } catch (e) {
      debugPrint('❌ ApiClient erreur réseau: $e');
      throw ApiException('Erreur réseau. Réessayez.');
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = ApiConfig.apiBaseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalized');
    if (query == null || query.isEmpty) return uri;

    final params = <String, String>{};
    query.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  Future<Map<String, String>> _buildHeaders({String? bearerOverride}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    // Bearer ponctuel (ex. échange de jeton Supabase) sinon jeton Sanctum stocké.
    final token = bearerOverride ?? await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    final status = response.statusCode;
    final dynamic decoded =
        response.body.isEmpty ? null : jsonDecode(response.body);

    if (status >= 200 && status < 300) {
      return decoded;
    }

    // Jeton invalide/expiré : on purge pour forcer une reconnexion.
    if (status == 401) {
      unawaited(clearToken());
    }

    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    throw ApiException(
      (map['message'] as String?) ?? 'Erreur (${status}).',
      statusCode: status,
      errors: _parseErrors(map['errors']),
    );
  }

  Map<String, List<String>>? _parseErrors(dynamic raw) {
    if (raw is! Map) return null;
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        (value is List) ? value.map((e) => e.toString()).toList() : [value.toString()],
      ),
    );
  }
}
