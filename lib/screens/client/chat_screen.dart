import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/chat_service.dart';
import 'package:elcora_fast/models/chat_message.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:intl/intl.dart';

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

  ChatRoom? _chatRoom;
  bool _isLoading = true;
  String? _currentUserId;

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
    final appService = Provider.of<AppService>(context, listen: false);
    _currentUserId = appService.currentUser?.id;

    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Ensure socket is connected
    if (!_chatService.isConnected) {
      await _chatService.initialize(
        userId: _currentUserId,
        // token: appService.currentUser?.token, // Add token if available
      );
    }

    await _loadChatRoom();
  }

  Future<void> _loadChatRoom() async {
    try {
      final room = await _chatService.getChatRoom(widget.orderId);
      if (mounted) {
        setState(() {
          _chatRoom = room;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chat room: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatRoom == null) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    final success = await _chatService.sendMessage(
      roomId: _chatRoom!.id,
      message: content,
    );

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi du message')),
        );
      }
    } else {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.driverName ?? 'Livreur',
                style: const TextStyle(fontSize: 16)),
            Text(
              'Commande #${widget.orderId.substring(0, 8)}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatRoom == null
              ? _buildNoChatRoom()
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<ChatMessage>>(
                        stream: _chatService.getMessageStream(_chatRoom!.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Erreur: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final messages = snapshot.data!;

                          if (messages.isEmpty) {
                            return const Center(
                                child: Text(
                                    'Aucun message. Commencez la discussion !'));
                          }

                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => _scrollToBottom());

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMe = message.senderId == _currentUserId;
                              return _buildMessageBubble(message, isMe);
                            },
                          );
                        },
                      ),
                    ),
                    _buildMessageInput(),
                  ],
                ),
    );
  }

  Widget _buildNoChatRoom() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Discussion non disponible'),
          const SizedBox(height: 8),
          const Text('La discussion sera activée une fois le livreur assigné.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadChatRoom,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: () {
                // TODO: Implement image sending
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

