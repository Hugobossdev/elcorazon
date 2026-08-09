import 'package:elcora_fast/services/social_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Fil d'un groupe — `/social/posts/`, `/social/posts/{id}/like/`,
/// `/social/posts/{id}/comments/`.
///
/// Trois décisions du serveur sont respectées ici plutôt que recalculées :
///
/// * **la visibilité découle du groupe.** L'écran n'envoie pas de drapeau
///   « public » : publier dans un groupe, c'est s'adresser à ses membres ;
/// * **le compteur de j'aime est celui du serveur.** Un compteur incrémenté
///   localement afficherait deux chiffres différents à deux personnes qui
///   aiment au même instant ;
/// * **l'auteur vient du jeton.** L'écran ne le transmet jamais — sinon on
///   publierait au nom d'un autre membre du groupe.
class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key, this.group});

  /// Groupe dont on lit le fil. `null` pour le fil public.
  final eccore.SocialGroup? group;

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recharger();
    });
  }

  Future<void> _recharger() =>
      context.read<SocialService>().refreshFeed(groupId: widget.group?.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group?.name ?? 'Fil public'),
        bottom: widget.group == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${widget.group!.memberCount} membres · '
                    'code ${widget.group!.inviteCode}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _publier,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Publier'),
      ),
      body: Consumer<SocialService>(
        builder: (context, service, child) {
          if (service.isLoading && service.feed.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.feed.isEmpty) {
            return _Vide(
              texte: service.error ??
                  'Rien n’a encore été publié ici.\nOuvrez le fil.',
              action: _recharger,
            );
          }

          return RefreshIndicator(
            onRefresh: _recharger,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: service.feed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _Publication(post: service.feed[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _publier() async {
    final texte = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.group == null
              ? 'Publier sur le fil public'
              : 'Publier dans ${widget.group!.name}',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: texte,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Ce que vous voulez partager…',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Le message est vide' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (valide != true || !mounted) return;

    final service = context.read<SocialService>();
    final messager = ScaffoldMessenger.of(context);
    final publication = await service.publish(
      content: texte.text.trim(),
      kind: eccore.PostKind.text,
      groupId: widget.group?.id,
    );
    texte.dispose();

    if (!mounted || publication != null) return;
    messager.showSnackBar(
      SnackBar(content: Text(service.error ?? 'Publication refusée')),
    );
  }
}

class _Publication extends StatelessWidget {
  const _Publication({required this.post});

  final eccore.Post post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final service = context.read<SocialService>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.secondaryContainer,
                  child: Text(
                    post.author.fullName.isEmpty
                        ? '?'
                        : post.author.fullName.characters.first.toUpperCase(),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _quand(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.content),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe ? scheme.error : null,
                  ),
                  onPressed: () => service.toggleLike(post.id),
                ),
                Text('${post.likesCount}'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined),
                  onPressed: () => _ouvrirCommentaires(context, service),
                ),
                Text('${post.commentsCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirCommentaires(BuildContext context, SocialService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Commentaires(post: post, service: service),
    );
  }

  static String _quand(DateTime moment) {
    final ecart = DateTime.now().difference(moment);
    if (ecart.inMinutes < 1) return 'à l’instant';
    if (ecart.inHours < 1) return 'il y a ${ecart.inMinutes} min';
    if (ecart.inDays < 1) return 'il y a ${ecart.inHours} h';
    if (ecart.inDays < 7) return 'il y a ${ecart.inDays} j';
    return '${moment.day}/${moment.month}/${moment.year}';
  }
}

class _Commentaires extends StatefulWidget {
  const _Commentaires({required this.post, required this.service});

  final eccore.Post post;
  final SocialService service;

  @override
  State<_Commentaires> createState() => _CommentairesState();
}

class _CommentairesState extends State<_Commentaires> {
  final _saisie = TextEditingController();
  List<eccore.PostComment> _commentaires = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final liste = await widget.service.comments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _commentaires = liste;
      _chargement = false;
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();
    if (texte.isEmpty) return;

    final ajoute = await widget.service.comment(
      postId: widget.post.id,
      content: texte,
    );
    if (!mounted) return;

    if (ajoute != null) {
      _saisie.clear();
      setState(() => _commentaires = [..._commentaires, ajoute]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Commentaires',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : _commentaires.isEmpty
                  ? const Center(child: Text('Aucun commentaire'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _commentaires.length,
                      itemBuilder: (context, index) {
                        final commentaire = _commentaires[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            commentaire.author.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(commentaire.content),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _saisie,
                      decoration: const InputDecoration(
                        hintText: 'Écrire un commentaire…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _envoyer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.texte, required this.action});

  final String texte;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(texte, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => action(),
              child: const Text('Recharger'),
            ),
          ],
        ),
      ),
    );
  }
}
