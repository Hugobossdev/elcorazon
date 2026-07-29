/// Auteur d'une publication ou d'un commentaire — miroir de
/// `apps.social.serializers.AuthorSerializer` (`id`, `full_name`, `avatar`).
class PostAuthor {
  const PostAuthor({required this.id, required this.fullName, this.avatarUrl});

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as String?;
    return PostAuthor(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
    );
  }

  final String id;
  final String fullName;
  final String? avatarUrl;
}

/// Publication — miroir de `PostSerializer`.
///
/// Les compteurs et [isPublic] sont **calculés par le serveur** : une
/// publication rattachée à un groupe ne peut pas être publique (contrainte
/// `group_post_not_public`, S4), et rien dans l'écriture ne permet de le
/// déclarer. [likedByMe] est propre à l'appelant.
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.kind,
    required this.content,
    required this.isPublic,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.createdAt,
    this.groupId,
    this.orderId,
    this.imageUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final image = json['image_url'] as String?;
    return Post(
      id: json['id'] as String,
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      groupId: json['group'] as String?,
      kind: json['kind'] as String,
      content: json['content'] as String,
      orderId: json['order'] as String?,
      imageUrl: image == null || image.isEmpty ? null : image,
      isPublic: json['is_public'] as bool,
      likesCount: json['likes_count'] as int,
      commentsCount: json['comments_count'] as int,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final PostAuthor author;
  final String? groupId;

  /// `order_share` | `photo` | `text` | `event` (`PostKind`).
  final String kind;
  final String content;
  final String? orderId;
  final String? imageUrl;
  final bool isPublic;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final DateTime createdAt;

  /// Copie avec le résultat d'un `like` — le serveur renvoie l'état résultant
  /// et le nouveau compteur, qu'on applique au lieu de les incrémenter à
  /// l'aveugle.
  Post withLike({required bool liked, required int likesCount}) {
    return Post(
      id: id,
      author: author,
      groupId: groupId,
      kind: kind,
      content: content,
      orderId: orderId,
      imageUrl: imageUrl,
      isPublic: isPublic,
      likesCount: likesCount,
      commentsCount: commentsCount,
      likedByMe: liked,
      createdAt: createdAt,
    );
  }
}

/// Commentaire — miroir de `PostCommentSerializer`.
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id'] as String,
      postId: json['post'] as String,
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String postId;
  final PostAuthor author;
  final String content;
  final DateTime createdAt;
}

/// Résultat d'un `POST /social/posts/{id}/like/`.
class LikeResult {
  const LikeResult({required this.liked, required this.likesCount});

  factory LikeResult.fromJson(Map<String, dynamic> json) {
    return LikeResult(liked: json['liked'] as bool, likesCount: json['likes_count'] as int);
  }

  final bool liked;
  final int likesCount;
}
