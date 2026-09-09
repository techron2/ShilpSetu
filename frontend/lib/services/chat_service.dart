import 'package:cloud_firestore/cloud_firestore.dart';

/// Real-time chat service using Firestore directly (no Flask backend needed).
///
/// Chat document path:  chats/{chatId}
/// Messages subcollection: chats/{chatId}/messages/{messageId}
///
/// chatId convention:  "{buyerId}_{artisanId}"  (sorted lexicographically)
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Derives a stable chat ID from two user IDs (order-independent).
  static String chatId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Stream of messages for a chat, ordered by timestamp ascending.
  Stream<List<ChatMessage>> messagesStream(String chatRoomId) {
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Send a message to a chat room.
  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String text,
    bool isArtisan = false,
  }) async {
    final now = FieldValue.serverTimestamp();

    // Create/update the chat room metadata document
    await _db.collection('chats').doc(chatRoomId).set({
      'last_message':    text,
      'last_updated':    now,
      'participant_ids': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    // Add the message
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'sender_id':   senderId,
      'sender_name': senderName,
      'text':        text,
      'is_artisan':  isArtisan,
      'timestamp':   now,
    });
  }

  /// Get all chat rooms a user participates in.
  Stream<List<ChatRoom>> chatRoomsStream(String userId) {
    return _db
        .collection('chats')
        .where('participant_ids', arrayContains: userId)
        .orderBy('last_updated', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatRoom.fromFirestore(d.id, d.data()))
            .toList());
  }
}

/// A single chat message.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool isArtisan;
  final DateTime? timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.isArtisan,
    this.timestamp,
  });

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? ts;
    final raw = data['timestamp'];
    if (raw is Timestamp) ts = raw.toDate();
    return ChatMessage(
      id:         id,
      senderId:   data['sender_id']?.toString() ?? '',
      senderName: data['sender_name']?.toString() ?? 'Unknown',
      text:       data['text']?.toString() ?? '',
      isArtisan:  data['is_artisan'] == true,
      timestamp:  ts,
    );
  }
}

/// Metadata about a chat room (for list view).
class ChatRoom {
  final String id;
  final String lastMessage;
  final List<String> participantIds;

  const ChatRoom({
    required this.id,
    required this.lastMessage,
    required this.participantIds,
  });

  factory ChatRoom.fromFirestore(String id, Map<String, dynamic> data) {
    return ChatRoom(
      id:             id,
      lastMessage:    data['last_message']?.toString() ?? '',
      participantIds: List<String>.from(data['participant_ids'] ?? []),
    );
  }
}
