import '../network/api_client.dart';
import 'post.dart';
import 'social_group.dart';

/// Accès à `/api/v1/social/*` — voir `backend/apps/social/{serializers,views}.py`.
///
/// La visibilité est un **filtre de requête** côté serveur, jamais une
/// permission d'objet (S2) : [getGroups] ne rend que les groupes dont
/// l'appelant est membre, et [getPosts] que le fil public plus les fils de ses
/// groupes. Aucune méthode ici ne prend d'identifiant d'utilisateur — le
/// serveur le lit dans le jeton.
class SocialRepository {
  SocialRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<SocialGroup>> getGroups() => _collect('/social/groups/', SocialGroup.fromJson);

  /// [kind] : valeur de `GroupKind` (`family`, `friends`, `work`,
  /// `neighborhood`, `custom`). Le code d'invitation est généré par le
  /// serveur, pas fourni ici.
  Future<SocialGroup> createGroup({
    required String name,
    String description = '',
    String kind = 'custom',
    bool isPrivate = false,
    int maxMembers = 50,
  }) async {
    final response = await apiClient.post(
      '/social/groups/',
      data: {
        'name': name,
        'description': description,
        'kind': kind,
        'is_private': isPrivate,
        'max_members': maxMembers,
      },
    );
    return SocialGroup.fromJson(response.data as Map<String, dynamic>);
  }

  /// Rejoint un groupe par son code. La capacité est vérifiée sous verrou
  /// côté serveur : un groupe complet est refusé là-bas, jamais deviné ici
  /// depuis un `member_count` déjà périmé au moment où on le lit.
  Future<SocialGroup> joinGroup(String inviteCode) async {
    final response = await apiClient.post(
      '/social/groups/join/',
      data: {'invite_code': inviteCode},
    );
    return SocialGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String groupId) async {
    await apiClient.post('/social/groups/$groupId/leave/');
  }

  /// Sans [groupId] : le fil visible (public + groupes de l'appelant).
  Future<List<Post>> getPosts({String? groupId}) {
    return _collect(
      '/social/posts/',
      Post.fromJson,
      query: groupId == null ? null : {'group': groupId},
    );
  }

  /// [groupId] non nul rend la publication privée au groupe — le serveur le
  /// déduit lui-même (S4), il n'y a pas de `is_public` à déclarer.
  Future<Post> createPost({
    required String content,
    String kind = 'text',
    String? groupId,
    String? orderId,
    String imageUrl = '',
  }) async {
    final response = await apiClient.post(
      '/social/posts/',
      data: {
        'content': content,
        'kind': kind,
        if (groupId != null) 'group': groupId,
        if (orderId != null) 'order': orderId,
        'image_url': imageUrl,
      },
    );
    return Post.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bascule le j'aime — un seul point d'entrée pour aimer et retirer, comme
  /// côté serveur. Le compteur qui revient fait autorité.
  Future<LikeResult> toggleLike(String postId) async {
    final response = await apiClient.post('/social/posts/$postId/like/');
    return LikeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PostComment>> getComments(String postId) =>
      _collect('/social/posts/$postId/comments/', PostComment.fromJson);

  Future<PostComment> addComment({required String postId, required String content}) async {
    final response = await apiClient.post(
      '/social/posts/$postId/comments/',
      data: {'content': content},
    );
    return PostComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<T>> _collect<T>(
    String firstPage,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    final items = <T>[];
    String? path = firstPage;
    var parameters = query;

    while (path != null) {
      final response = await apiClient.get(path, queryParameters: parameters);
      final body = response.data as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>;
      items.addAll(results.map((json) => fromJson(json as Map<String, dynamic>)));
      path = body['next'] as String?;
      parameters = null;
    }

    return items;
  }
}
