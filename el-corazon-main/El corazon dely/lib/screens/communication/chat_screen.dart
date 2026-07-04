import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_service.dart';
import '../../services/chat_service.dart';
import '../../services/agora_call_service.dart';
import '../../models/order.dart';
import '../../models/message.dart';
import '../../widgets/loading_widget.dart';
import '../delivery/driver_profile_screen.dart';
import '../delivery/settings_screen.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final Order order;
  final String chatType; // 'customer' or 'support'

  const ChatScreen({
    super.key,
    required this.order,
    this.chatType = 'customer',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  final bool _isTyping = false;
  bool _isConnected = false;
  bool _isSending = false;

  final ChatService _chatService = ChatService();
  StreamSubscription<List<Message>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _chatService.unsubscribeFromMessages(widget.order.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      // Initialiser le service de chat
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser != null) {
        await _chatService.initialize(userId: currentUser.id);
      }

      // Charger les messages existants
      setState(() => _isLoading = true);
      final messages = await _chatService.loadMessages(widget.order.id);

      setState(() {
        _messages = messages;
        _isLoading = false;
        _isConnected = _chatService.isConnected(widget.order.id);
      });

      _scrollToBottom();

      // S'abonner aux nouveaux messages en temps réel
      _subscribeToMessages();
    } catch (e) {
      debugPrint('Erreur initialisation chat: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription =
        _chatService.subscribeToMessages(widget.order.id).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isConnected = _chatService.isConnected(widget.order.id);
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        debugPrint('Erreur stream messages: $error');
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de connexion: $error'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Réessayer',
                onPressed: () {
                  _subscribeToMessages();
                },
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Envoyer le message via ChatService
      final success = await _chatService.sendMessage(
        orderId: widget.order.id,
        senderId: currentUser.id,
        senderName: currentUser.name,
        content: content,
        isFromDriver: true,
      );

      if (!success) {
        throw Exception('Échec de l\'envoi du message');
      }

      // Le message sera automatiquement ajouté via Realtime
      // Scroll après un court délai
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'envoi: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              onPressed: () {
                _messageController.text = content;
                _sendMessage();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makeCall({bool isVideo = false}) async {
    try {
      // Initialiser Agora si nécessaire
      final agoraService = AgoraCallService();
      if (!agoraService.isInitialized) {
        final initialized = await agoraService.initialize();
        if (!initialized) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible d\'initialiser l\'appel'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Envoyer une notification d'appel via le chat
      final appService = Provider.of<AppService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser != null) {
        // Envoyer un message système pour notifier l'appel
        await _chatService.sendMessage(
          orderId: widget.order.id,
          senderId: currentUser.id,
          senderName: currentUser.name,
          content: isVideo
              ? '📹 Appel vidéo en cours...'
              : '📞 Appel vocal en cours...',
          isFromDriver: true,
          type: MessageType.system,
        );
      }

      // Ouvrir l'écran d'appel
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              order: widget.order,
              callType: isVideo ? CallType.video : CallType.voice,
              isIncoming: false,
              callerName: widget.chatType == 'customer' ? 'Client' : 'Support',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur démarrage appel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    try {
      // Récupérer le numéro de téléphone depuis le profil utilisateur
      final userProfile = await _getUserProfile(widget.order.userId);
      final phoneNumber = userProfile?['phone'] as String?;
      
      if (phoneNumber == null || phoneNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Numéro de téléphone non disponible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Nettoyer le numéro (enlever les espaces, tirets, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Ouvrir WhatsApp avec un message pré-rempli
      final message = 'Bonjour, je suis votre livreur pour la commande #${widget.order.id}.';
      final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      final canLaunch = await canLaunchUrl(uri);
      
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: ouvrir SMS
        final smsUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
        await launchUrl(smsUri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.chatType == 'customer' ? 'Client' : 'Support',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                // Indicateur de connexion
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            Text(
              'Commande #${widget.order.id.substring(0, 8)}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _makeCall,
            icon: const Icon(Icons.call),
            tooltip: 'Appeler',
          ),
          IconButton(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat),
            tooltip: 'WhatsApp',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Chargement des messages...')
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                ),

                // Typing indicator
                if (_isTyping)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Text(
                          '${widget.chatType == 'customer' ? 'Client' : 'Support'} est en train d\'écrire...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Message input
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Tapez votre message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        onPressed: _isSending ? null : _sendMessage,
                        backgroundColor: _isSending
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun message',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez la conversation',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isFromDriver = message.isFromDriver;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isFromDriver ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isFromDriver) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                message.senderName.substring(0, 1).toUpperCase(),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromDriver
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isFromDriver
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isFromDriver
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isFromDriver ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isFromDriver
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isFromDriver) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.delivery_dining,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Maintenant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}j';
    }
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      return await appService.getUserProfile(userId);
    } catch (e) {
      debugPrint('Erreur récupération profil utilisateur: $e');
      return null;
    }
  }
}
