import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/chat_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/screens/client/call_screen.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:intl/intl.dart';

/// Conversation avec le livreur d'une commande.
///
/// ## Ce que la maquette montre, et ce que le serveur permet
///
/// `chat_with_driver` dessine un fil déjà garni à l'ouverture, avec une double
/// coche « lu ». Ni l'un ni l'autre n'existe : **le backend ne persiste pas la
/// conversation** (ADR-008, Phase 1 §5) — le consommateur WebSocket relaie, il
/// n'écrit nulle part. `ChatService` le documente depuis sa migration.
///
/// Conséquences, assumées plutôt que masquées :
///
/// * le fil part **vide** à chaque ouverture, et l'écran le dit en toutes
///   lettres au lieu de laisser croire à une conversation effacée ;
/// * il n'y a pas d'accusé de lecture à afficher ;
/// * un message envoyé pendant que l'autre partie n'est pas connectée est
///   perdu. C'est le besoin **BR-004**, en priorité 1 de
///   `docs/STITCH_BACKEND_REQUIREMENTS.md` : sans persistance, la conversation
///   n'est pas une fonctionnalité mais une coïncidence.
///
/// Rien n'est rattrapé par un stockage local : recopier les messages sur le
/// téléphone donnerait au client un historique que le livreur n'a pas, et deux
/// versions d'une même conversation.
class ChatScreen extends StatefulWidget {
  final String orderId;
  final String? driverId;
  final String? driverName;

  const ChatScreen({
    required this.orderId,
    this.driverId,
    this.driverName,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  bool _isLoading = true;
  bool _envoiEnCours = false;

  /// Rôle de l'appelant tel que le serveur l'estampille sur chaque message
  /// (`customer` | `courier`) : c'est ce qui décide du côté de la bulle. Il n'y
  /// a plus d'identifiant d'utilisateur à comparer — le relais n'en diffuse
  /// pas, et n'en a pas besoin.
  static const String _myRole = 'customer';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // Plus de « salon » à charger : le canal est la commande elle-même, et
    // l'autorisation est vérifiée par le serveur à l'ouverture du socket
    // (`OrderChatConsumer`). Une commande livrée ou annulée voit sa connexion
    // refusée — la conversation n'a plus lieu d'être.
    if (!_chatService.isConnected) {
      await _chatService.initialize();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _envoiEnCours) return;

    setState(() => _envoiEnCours = true);

    final success = await _chatService.sendMessage(
      orderId: widget.orderId,
      message: content,
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (success) {
      // Le champ ne se vide qu'**après** l'accusé du canal : effacer d'abord,
      // comme le faisait la version précédente, faisait perdre le texte
      // saisi lorsque l'envoi échouait — et il n'y avait plus qu'à le
      // retaper de mémoire.
      _messageController.clear();
      _scrollToBottom();
    } else {
      context.showErrorMessage(
        'Message non transmis. Vérifiez votre connexion et réessayez.',
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: DesignConstants.animationNormal,
        curve: DesignConstants.curveEaseOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        centerTitle: false,
        titleWidget: _enTete(theme),
        actions: [
          GlassIconButton(
            icon: Icons.phone_outlined,
            tooltip: 'Appeler le livreur',
            filled: false,
            onPressed: _startAudioCall,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _fil(theme)),
                _saisie(theme),
              ],
            ),
    );
  }

  Widget _enTete(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.driverName ?? 'Votre livreur',
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
        ),
        Text(
          // « Online » de la maquette : ici c'est l'état du **canal**, seule
          // chose que l'application sache réellement. Elle ne voit pas si le
          // livreur regarde son écran.
          _chatService.isConnected ? 'Canal ouvert' : 'Reconnexion…',
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd(
            color: _chatService.isConnected
                ? AppColors.success
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _fil(ThemeData theme) {
    return StreamBuilder<List<eccore.ChatMessage>>(
      stream: _chatService.getMessageStream(widget.orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DesignConstants.spacingL),
              child: Text(
                'La conversation n’a pas pu s’ouvrir. '
                'Elle n’est disponible que pendant la livraison.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLg(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!;
        if (messages.isEmpty) return _filVide(theme);

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(DesignConstants.edgeMargin),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _bulle(theme, message, message.sender == _myRole);
          },
        );
      },
    );
  }

  /// Le fil vide, qui dit **pourquoi** il l'est.
  ///
  /// « Aucun message » laissait croire à une conversation effacée. La vérité
  /// est plus simple et plus rassurante : elle n'est pas conservée, et elle
  /// commence maintenant.
  Widget _filVide(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignConstants.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            Text(
              'La conversation commence ici',
              textAlign: TextAlign.center,
              style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: DesignConstants.spacingS),
            Text(
              'Les messages ne sont pas conservés après la livraison : '
              'ce fil ne vaut que pour cette course.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulle(ThemeData theme, eccore.ChatMessage message, bool deMoi) {
    final fond = deMoi
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHigh;
    final encre = deMoi
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: deMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: DesignConstants.spacingS),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignConstants.spacingM,
          vertical: DesignConstants.spacingS + 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: fond,
          // Le coin plein du côté de l'émetteur : c'est ce qui fait lire
          // l'origine d'un message sans avoir à comparer deux teintes.
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(DesignConstants.radiusLarge),
            topRight: const Radius.circular(DesignConstants.radiusLarge),
            bottomLeft: Radius.circular(deMoi ? DesignConstants.radiusLarge : 2),
            bottomRight:
                Radius.circular(deMoi ? 2 : DesignConstants.radiusLarge),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: AppTypography.bodyLg(color: encre)),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(message.sentAt),
              style: AppTypography.bodyMd(
                color: encre.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saisie(ThemeData theme) {
    return GlassBottomBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Le bouton « image » de la maquette n'est pas dessiné : aucune
          // route ne permet à un client de déposer un fichier (BR-011).
          // L'ancienne version l'affichait et répondait « bientôt
          // disponible » — une note de développement montrée au client.
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Écrire un message…',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: DesignConstants.spacingS),
          SizedBox(
            width: DesignConstants.touchTargetSize,
            height: DesignConstants.touchTargetSize,
            child: Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _envoiEnCours ? null : _sendMessage,
                child: _envoiEnCours
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: DesignConstants.iconSizeMedium,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startAudioCall() async {
    if (!mounted) return;

    final appService = Provider.of<AppService>(context, listen: false);
    final currentUser = appService.currentUser;

    if (currentUser == null) {
      context.showErrorMessage('Connectez-vous pour passer un appel.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CallScreen(
          orderId: widget.orderId,
          callerName: currentUser.fullName,
          receiverName: widget.driverName ?? 'Votre livreur',
        ),
      ),
    );
  }
}
