import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _groupJson({int memberCount = 3}) {
  return {
    'id': 'group-1',
    'name': 'Famille Koffi',
    'description': 'Les commandes du week-end',
    'kind': 'family',
    'invite_code': 'A1B2C3D4E5F6',
    'is_private': true,
    'max_members': 8,
    'member_count': memberCount,
    'created_at': '2026-07-28T12:00:00Z',
  };
}

Map<String, dynamic> _postJson({
  String id = 'post-1',
  String? group,
  bool isPublic = true,
  bool likedByMe = false,
  int likesCount = 2,
}) {
  return {
    'id': id,
    'author': {'id': 'user-1', 'full_name': 'Awa K.', 'avatar': ''},
    'group': group,
    'kind': 'text',
    'content': 'Le tacos du vendredi, toujours au rendez-vous.',
    'order': null,
    'image_url': '',
    'is_public': isPublic,
    'likes_count': likesCount,
    'comments_count': 1,
    'liked_by_me': likedByMe,
    'created_at': '2026-07-28T12:00:00Z',
  };
}

/// Simule `/social/*`.
class _FakeServer implements HttpClientAdapter {
  final List<String> requests = [];
  final List<Object?> bodies = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final query = options.uri.query;
    requests.add('${options.method} $path${query.isEmpty ? '' : '?$query'}');
    if (options.data != null) {
      bodies.add(options.data);
    }

    if (path.endsWith('/social/groups/') && options.method == 'GET') {
      return _json(_page([_groupJson()]), 200);
    }

    if (path.endsWith('/social/groups/') && options.method == 'POST') {
      return _json(_groupJson(memberCount: 1), 201);
    }

    if (path.endsWith('/social/groups/join/')) {
      return _json(_groupJson(memberCount: 4), 200);
    }

    if (path.endsWith('/social/groups/group-1/leave/')) {
      return ResponseBody.fromString('', 204, headers: _jsonHeaders);
    }

    if (path.endsWith('/social/posts/') && options.method == 'GET') {
      final group = options.uri.queryParameters['group'];
      return _json(
        _page([
          if (group == null) _postJson() else _postJson(id: 'post-2', group: group, isPublic: false),
        ]),
        200,
      );
    }

    if (path.endsWith('/social/posts/') && options.method == 'POST') {
      return _json(_postJson(id: 'post-3', group: 'group-1', isPublic: false, likesCount: 0), 201);
    }

    if (path.endsWith('/social/posts/post-1/like/')) {
      return _json({'liked': true, 'likes_count': 3}, 200);
    }

    if (path.endsWith('/social/posts/post-1/comments/') && options.method == 'GET') {
      return _json(_page([_commentJson()]), 200);
    }

    if (path.endsWith('/social/posts/post-1/comments/') && options.method == 'POST') {
      return _json(_commentJson(id: 'comment-2'), 201);
    }

    throw UnimplementedError('Route non simulée : ${options.method} $path');
  }

  Map<String, dynamic> _commentJson({String id = 'comment-1'}) {
    return {
      'id': id,
      'post': 'post-1',
      'author': {'id': 'user-2', 'full_name': 'Kodjo M.', 'avatar': null},
      'content': 'Entièrement d\'accord !',
      'created_at': '2026-07-28T12:05:00Z',
    };
  }

  Map<String, dynamic> _page(List<Map<String, dynamic>> results) {
    return {'count': results.length, 'next': null, 'previous': null, 'results': results};
  }

  ResponseBody _json(Map<String, dynamic> body, int status) {
    return ResponseBody.fromString(jsonEncode(body), status, headers: _jsonHeaders);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeServer server;
  late SocialRepository repository;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);

    server = _FakeServer();
    final apiClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: TokenStorage(),
      testAdapter: server,
    );
    repository = SocialRepository(apiClient: apiClient);
  });

  group('SocialRepository — groupes', () {
    test('getGroups mappe la capacité et le code d\'invitation', () async {
      final groups = await repository.getGroups();

      expect(groups.single.kind, 'family');
      expect(groups.single.inviteCode, 'A1B2C3D4E5F6');
      expect(groups.single.memberCount, 3);
      expect(groups.single.isFull, isFalse);
    });

    test('createGroup n\'envoie ni code d\'invitation ni compteur', () async {
      final group = await repository.createGroup(name: 'Famille Koffi', kind: 'family');

      expect(group.memberCount, 1);
      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body['kind'], 'family');
      expect(body.containsKey('invite_code'), isFalse);
      expect(body.containsKey('member_count'), isFalse);
    });

    test('joinGroup poste le seul code et rend le groupe rejoint', () async {
      final group = await repository.joinGroup('A1B2C3D4E5F6');

      expect(group.memberCount, 4);
      expect(server.bodies.single, {'invite_code': 'A1B2C3D4E5F6'});
    });

    test('leaveGroup accepte une réponse 204 sans corps', () async {
      await repository.leaveGroup('group-1');

      expect(server.requests.single, 'POST /api/v1/social/groups/group-1/leave/');
    });

    test('isFull compare au plafond servi par le serveur', () {
      final full = SocialGroup.fromJson(_groupJson(memberCount: 8));

      expect(full.isFull, isTrue);
    });
  });

  group('SocialRepository — publications', () {
    test('getPosts sans groupe demande le fil visible', () async {
      final posts = await repository.getPosts();

      expect(posts.single.isPublic, isTrue);
      expect(posts.single.groupId, isNull);
      expect(server.requests.single, 'GET /api/v1/social/posts/');
    });

    test('getPosts filtre par groupe côté serveur', () async {
      final posts = await repository.getPosts(groupId: 'group-1');

      expect(posts.single.groupId, 'group-1');
      expect(posts.single.isPublic, isFalse);
      expect(server.requests.single, 'GET /api/v1/social/posts/?group=group-1');
    });

    test('createPost ne déclare jamais is_public ni les compteurs', () async {
      final post = await repository.createPost(content: 'Miam', groupId: 'group-1');

      // Rattachée à un groupe : le serveur la rend privée de lui-même (S4).
      expect(post.isPublic, isFalse);
      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body['group'], 'group-1');
      expect(body.containsKey('is_public'), isFalse);
      expect(body.containsKey('likes_count'), isFalse);
    });

    test('createPost omet group et order quand ils sont nuls', () async {
      await repository.createPost(content: 'Bonjour');

      final body = server.bodies.single! as Map<String, dynamic>;
      expect(body.containsKey('group'), isFalse);
      expect(body.containsKey('order'), isFalse);
    });

    test('toggleLike applique le compteur du serveur, sans incrément local', () async {
      final before = Post.fromJson(_postJson(likesCount: 2));
      final result = await repository.toggleLike('post-1');
      final after = before.withLike(liked: result.liked, likesCount: result.likesCount);

      expect(result.liked, isTrue);
      expect(after.likesCount, 3);
      expect(after.likedByMe, isTrue);
    });

    test('withCommentAdded avance le compteur d\'exactement un', () {
      final avant = Post.fromJson(_postJson());
      final apres = avant.withCommentAdded();

      expect(apres.commentsCount, avant.commentsCount + 1);
      // Le reste ne bouge pas : une publication ne s'édite pas.
      expect(apres.content, avant.content);
      expect(apres.likesCount, avant.likesCount);
      expect(apres.likedByMe, avant.likedByMe);
    });

    test('getComments mappe l\'auteur, avatar vide compris', () async {
      final comments = await repository.getComments('post-1');

      expect(comments.single.author.fullName, 'Kodjo M.');
      expect(comments.single.author.avatarUrl, isNull);
    });

    test('addComment poste le seul contenu', () async {
      final comment = await repository.addComment(postId: 'post-1', content: 'Bien vu');

      expect(comment.id, 'comment-2');
      expect(server.bodies.single, {'content': 'Bien vu'});
    });
  });
}
