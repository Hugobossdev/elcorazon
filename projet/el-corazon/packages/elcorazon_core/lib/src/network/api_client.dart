import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import 'api_exception.dart';

/// Client HTTP unique vers `/api/v1/` — attache le jeton d'accès, rafraîchit
/// la session sur un 401 et traduit les réponses en [ApiException].
///
/// Le rafraîchissement est *single-flight* : si plusieurs requêtes échouent en
/// 401 en même temps (jeton d'accès expiré), une seule d'entre elles déclenche
/// l'appel à `/auth/token/refresh/` ; les autres attendent le même [Future].
/// C'est nécessaire parce que le refresh token est à usage unique côté
/// serveur (rotation + liste noire, ADR-004) — un deuxième appel concurrent
/// avec le même jeton échouerait sinon systématiquement.
class ApiClient {
  /// [testAdapter] n'a qu'un usage : simuler le serveur dans les tests (voir
  /// `test/api_client_test.dart`), en particulier pour vérifier que deux 401
  /// concurrents ne déclenchent bien qu'un seul appel de rafraîchissement.
  /// Ne jamais le renseigner en dehors des tests.
  ApiClient({required String baseUrl, required this.tokenStorage, HttpClientAdapter? testAdapter})
    : dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15))),
      _refreshDio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 15))) {
    if (testAdapter != null) {
      dio.httpClientAdapter = testAdapter;
      _refreshDio.httpClientAdapter = testAdapter;
    }
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onError: _handleError),
    );
  }

  /// Client principal — porte l'intercepteur, sert tous les appels de l'app.
  final Dio dio;

  /// Client nu, sans intercepteur : sert uniquement l'appel de
  /// rafraîchissement lui-même. Le faire passer par [dio] rebouclerait sur le
  /// même intercepteur si jamais le refresh token est, lui aussi, rejeté.
  final Dio _refreshDio;

  final TokenStorage tokenStorage;

  Future<String>? _refreshInFlight;

  /// Routes qui s'ouvrent sans session (`AllowAny` côté serveur).
  ///
  /// Elles sont exclues des deux traitements de l'intercepteur, et pour deux
  /// raisons distinctes :
  ///
  /// * **Aucun jeton n'y est joint.** Django authentifie avant d'appliquer
  ///   `AllowAny` : un jeton d'accès périmé présenté à `/auth/login/` fait
  ///   répondre 401 *avant* que la vue ne voie les identifiants. La connexion
  ///   deviendrait impossible tant que le stockage n'est pas vidé — c'est-à-dire
  ///   précisément quand l'utilisateur cherche à se reconnecter.
  /// * **Leur 401 ne se rejoue pas.** Il signifie « identifiants refusés », pas
  ///   « jeton expiré » ; le confondre avec le second remonte `session_expired`
  ///   à l'écran de connexion au lieu du vrai motif, et consomme au passage un
  ///   refresh token encore valide pour rien.
  static const _publicAuthPaths = {
    '/auth/login/',
    '/auth/register/',
    '/auth/token/refresh/',
  };

  static bool _isPublicAuthPath(String path) =>
      _publicAuthPaths.any(path.contains);

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: queryParameters));

  Future<Response<dynamic>> post(String path, {Object? data, Map<String, String>? headers}) =>
      _send(
        () => dio.post<dynamic>(
          path,
          data: data,
          options: headers == null ? null : Options(headers: headers),
        ),
      );

  Future<Response<dynamic>> patch(String path, {Object? data}) =>
      _send(() => dio.patch<dynamic>(path, data: data));

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _send(() => dio.delete<dynamic>(path, data: data));

  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isPublicAuthPath(options.path)) {
      handler.next(options);
      return;
    }

    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _handleError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final alreadyRetried = request.extra['retried'] == true;

    if (error.response?.statusCode != 401 ||
        _isPublicAuthPath(request.path) ||
        alreadyRetried) {
      handler.next(error);
      return;
    }

    try {
      final newAccessToken = await _refresh();
      request.headers['Authorization'] = 'Bearer $newAccessToken';
      request.extra['retried'] = true;
      handler.resolve(await dio.fetch(request));
    } on SessionExpiredException catch (cause) {
      handler.reject(
        DioException(requestOptions: request, error: cause, type: DioExceptionType.unknown),
      );
    } catch (_) {
      handler.next(error);
    }
  }

  /// Verrou *single-flight* : `??=` ne recrée le futur que s'il n'y en a pas
  /// déjà un en cours. Les appelants qui arrivent pendant qu'il tourne
  /// reçoivent la même instance et n'émettent donc aucune requête HTTP
  /// supplémentaire. Le futur n'est libéré qu'une fois résolu — il ne peut
  /// donc pas y avoir de fenêtre où deux rafraîchissements partent en même
  /// temps.
  Future<String> _refresh() {
    return _refreshInFlight ??= _doActualRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String> _doActualRefresh() async {
    // Lu au moment de l'exécution, pas capturé plus tôt : un appel hors de cet
    // intercepteur (changement de mot de passe, qui révoque tout) a pu
    // remplacer ce jeton entre-temps.
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SessionExpiredException('Aucun jeton de rafraîchissement stocké.');
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final body = response.data!;
      final access = body['access'] as String;
      final refresh = body['refresh'] as String;
      await tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
      return access;
    } on DioException catch (cause) {
      // Le jeton de rafraîchissement est à usage unique côté serveur : un
      // rejet ici signifie qu'il est expiré, révoqué ou déjà consommé — dans
      // les trois cas, il ne redeviendra pas valide, et le conserver ferait
      // échouer silencieusement toutes les requêtes suivantes de la même
      // façon.
      await tokenStorage.clearTokens();
      throw SessionExpiredException(cause);
    }
  }

  ApiException _mapDioError(DioException error) {
    if (error.error is SessionExpiredException) {
      return ApiException(
        status: 401,
        code: 'session_expired',
        detail: 'Votre session a expiré, reconnectez-vous.',
      );
    }

    final response = error.response;
    final data = response?.data;
    if (response != null && data is Map<String, dynamic>) {
      return ApiException.fromProblemDetail(response.statusCode ?? 0, data);
    }

    return ApiException.network(error.message ?? 'Impossible de joindre le serveur.');
  }
}
