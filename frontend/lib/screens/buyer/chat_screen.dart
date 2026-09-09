import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

/// Real-time chat screen using Firestore listeners directly.
///
/// Works for both buyer↔artisan conversations.
/// Chat room ID is derived from sorted [currentUserId, otherUserId].
class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String otherUserId;
  final String otherUserName;
  final bool isCurrentUserArtisan;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserId,
    required this.otherUserName,
    required this.isCurrentUserArtisan,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  late final String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _chatRoomId = ChatService.chatId(widget.currentUserId, widget.otherUserId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);

    await ChatService.instance.sendMessage(
      chatRoomId:      _chatRoomId,
      senderId:        widget.currentUserId,
      senderName:      widget.currentUserName,
      text:            text,
      isArtisan:       widget.isCurrentUserArtisan,
    );
    if (mounted) setState(() => _sending = false);

    // Scroll to bottom after a short delay
    await Future.delayed(const Duration(milliseconds: 200));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.primaryTerracotta,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.isCurrentUserArtisan ? 'Buyer' : 'Artisan',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages stream
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.instance.messagesStream(_chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return _emptyChat();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == widget.currentUserId;
                    return _MessageBubble(message: msg, isMine: isMine);
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 1,
                    borderRadius: BorderRadius.circular(24),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _sending
                          ? const Color(0xFF9CA3AF)
                          : AppTheme.primaryTerracotta,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTerracotta.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUserName}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryTerracotta.withValues(alpha: 0.15),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTerracotta,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine ? AppTheme.primaryTerracotta : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isMine ? Colors.white : AppTheme.darkIndigo,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              if (message.timestamp != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp!),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
