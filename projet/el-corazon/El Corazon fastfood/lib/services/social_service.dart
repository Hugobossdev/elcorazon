import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

/// Groupes et publications — `/social/groups/` et `/social/posts/`.
///
/// Le backend de ce domaine existait depuis la Phase 4, testé et documenté,
/// mais aucune application ne l'appelait : dix-huit routes servies et
/// inatteignables. Ce service, et les écrans qui s'appuient dessus, sont la
/// partie qui manquait.
///
/// Deux choses ne se décident pas ici, et c'est ce qui distingue ce service
/// d'une implémentation naïve :
///
/// * **l'auteur d'une publication** vient du jeton, côté serveur. Le client ne
///   l'envoie pas — sans quoi n'importe quel compte publierait au nom d'un
///   autre ;
/// * **le compteur de mentions « j'aime »** est rendu par le serveur à chaque
///   bascule. L'incrémenter localement afficherait un chiffre qui dérive dès
///   que deux personnes aiment la même publication en même temps.
class SocialService extends ChangeNotifier {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final eccore.SocialRepository _social = eccore.SocialRepository(
    apiClient: apiClient,
  );

  List<eccore.SocialGroup> _groups = [];
  List<eccore.Post> _feed = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<eccore.SocialGroup> get groups => List.unmodifiable(_groups);
  List<eccore.Post> get feed => List.unmodifiable(_feed);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refreshGroups();
  }

  // ------------------------------------------------------------- groupes

  Future<void> refreshGroups() async {
    await _lire(() async => _groups = await _social.getGroups());
  }

  /// Ouvre un groupe. Le code d'invitation est **généré par le serveur** :
  /// le laisser choisir au client permettrait de deviner celui d'un autre.
  Future<eccore.SocialGroup?> createGroup({
    required String name,
    required String kind,
    String description = '',
    bool isPrivate = true,
  }) async {
    try {
      final groupe = await _social.createGroup(
        name: name,
        kind: kind,
        description: description,
        isPrivate: isPrivate,
      );
      _groups = [groupe, ..._groups];
      notifyListeners();
      return groupe;
    } on eccore.ApiException catch (e) {
      _signaler(e, 'création de groupe');
      return null;
    }
  }

  /// Rejoint un groupe par son code d'invitation.
  Future<bool> joinGroup(String inviteCode) async {
    try {
      final groupe = await _social.joinGroup(inviteCode.trim().toUpperCase());
      // Le serveur rend le groupe rejoint : on l'ajoute sans recharger toute
      // la liste, mais sans doublon si l'on y était déjà.
      _groups = [groupe, ..._groups.where((g) => g.id != groupe.id)];
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _error = e.status == 404
          ? 'Aucun groupe ne correspond à ce code.'
          : e.detail;
      eccore.Journal.trace('Social : adhésion refusée — ${e.code}');
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      await _social.leaveGroup(groupId);
      _groups = _groups.where((g) => g.id != groupId).toList();
      _feed = _feed.where((p) => p.groupId != groupId).toList();
      notifyListeners();
      return true;
    } on eccore.ApiException catch (e) {
      _signaler(e, 'sortie de groupe');
      return false;
    }
  }

  // -------------------------------------------------------- publications

  /// Fil d'un groupe, ou fil public si [groupId] est nul.
  Future<void> refreshFeed({String? groupId}) async {
    await _lire(() async => _feed = await _social.getPosts(groupId: groupId));
  }

  /// Publie dans un groupe, ou sur le fil public si [groupId] est nul.
  ///
  /// La visibilité n'est pas un paramètre : elle **découle** du groupe. Une
  /// publication adressée à un groupe est visible de ses membres, une
  /// publication sans groupe est publique. Laisser le client déclarer un
  /// `is_public` permettrait de poster dans un groupe privé un message que
  /// tout le monde lit — le serveur tranche, et c'est pourquoi le champ n'est
  /// pas au contrat.
  Future<eccore.Post?> publish({
    required String content,
    required String kind,
    String? groupId,
    String? orderId,
  }) async {
    try {
      final publication = await _social.createPost(
        content: content,
        kind: kind,
        groupId: groupId,
        orderId: orderId,
      );
      _feed = [publication, ..._feed];
      notifyListeners();
      return publication;
    } on eccore.ApiException catch (e) {
      _signaler(e, 'publication');
      return null;
    }
  }

  /// Bascule la mention « j'aime ».
  ///
  /// Le compte affiché est celui que rend le serveur, pas un compteur local
  /// incrémenté : deux personnes qui aiment au même instant verraient sinon
  /// deux chiffres différents.
  Future<bool> toggleLike(String postId) async {
    try {
      final resultat = await _social.toggleLike(postId);
      final index = _feed.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _feed[index] = _feed[index].withLike(
          liked: resultat.liked,
          likesCount: resultat.likesCount,
        );
        notifyListeners();
      }
      return true;
    } on eccore.ApiException catch (e) {
      _signaler(e, 'mention j’aime');
      return false;
    }
  }

  Future<List<eccore.PostComment>> comments(String postId) async {
    try {
      return await _social.getComments(postId);
    } on eccore.ApiException catch (e) {
      _signaler(e, 'commentaires');
      return const [];
    }
  }

  Future<eccore.PostComment?> comment({
    required String postId,
    required String content,
  }) async {
    try {
      final commentaire = await _social.addComment(
        postId: postId,
        content: content,
      );
      final index = _feed.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _feed[index] = _feed[index].withCommentAdded();
      }
      notifyListeners();
      return commentaire;
    } on eccore.ApiException catch (e) {
      _signaler(e, 'commentaire');
      return null;
    }
  }

  // -------------------------------------------------------------- interne

  Future<void> _lire(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      eccore.Journal.trace('Social : lecture impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _signaler(eccore.ApiException e, String quoi) {
    _error = e.detail;
    eccore.Journal.trace('Social : $quoi refusée — ${e.code}');
    notifyListeners();
  }
}
