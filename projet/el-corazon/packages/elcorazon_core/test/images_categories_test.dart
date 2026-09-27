import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Photos des catégories (lot 3) : lues sur la carte publique et au
/// back-office, posées en multipart, retirées par un `null` explicite.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

const _categorie = {
  'id': 'c1',
  'restaurant': 'el-corazon-lome',
  'name': 'Grillades',
  'slug': 'grillades',
  'emoji': '',
  'description': '',
  'sort_order': 0,
  'is_active': true,
  'image': 'https://cdn.test/categories/grillades.webp',
};

class _Serveur implements HttpClientAdapter {
  final List<RequestOptions> requetes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requetes.add(options);
    final retrait = options.data is Map && (options.data as Map)['image'] == null;
    return ResponseBody.fromString(
      '{"id":"c1","restaurant":"el-corazon-lome","name":"Grillades","slug":"grillades",'
      '"sort_order":0,"is_active":true,'
      '"image":${retrait ? 'null' : '"https://cdn.test/categories/g.webp"'}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  ManagedCatalogRepository depot(_Serveur serveur) => ManagedCatalogRepository(
        apiClient: ApiClient(
          baseUrl: 'http://test.local/api/v1',
          tokenStorage: TokenStorage(),
          testAdapter: serveur,
        ),
      );

  test('la carte publique lit la photo, et le cache la relit', () {
    final categorie = Category.fromJson(_categorie);

    expect(categorie.image, 'https://cdn.test/categories/grillades.webp');
    expect(Category.fromJson(categorie.toJson()).image, categorie.image);
  });

  test('sans photo, ou une chaîne vide, se lit null', () {
    expect(Category.fromJson({..._categorie, 'image': null}).image, isNull);
    expect(Category.fromJson({..._categorie, 'image': ''}).image, isNull);
    expect(ManagedCategory.fromJson({..._categorie, 'image': ''}).image, isNull);
  });

  test('une photo part en multipart sur la fiche de la catégorie', () async {
    final serveur = _Serveur();

    final relue = await depot(serveur).uploadCategoryImage(
      categoryId: 'c1',
      filename: 'g.webp',
      bytes: const [1, 2, 3],
      contentType: 'image/webp',
    );

    final requete = serveur.requetes.single;
    expect(requete.method, 'PATCH');
    expect(requete.path, endsWith('/catalog/manage/categories/c1/'));
    expect(requete.data, isA<FormData>());
    expect((requete.data as FormData).files.single.key, 'image');
    expect(relue.image, isNotNull);
  });

  test('retirer la photo envoie un null explicite, en JSON', () async {
    final serveur = _Serveur();

    final relue = await depot(serveur).clearCategoryImage('c1');

    expect(serveur.requetes.single.data, {'image': null});
    expect(relue.image, isNull);
  });

  test('le journal nomme le changement de photo', () {
    expect(FamilleAudit.libelle('category.image'), isNot('category.image'));
    expect(FamilleAudit.familles.keys, contains('category.'));
  });
}
