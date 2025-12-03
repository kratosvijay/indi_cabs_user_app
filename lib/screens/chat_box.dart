import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

/// Model for a single chat message
class RideChatMessage {
  final String id;
  final String text;
  final String senderId;
  final Timestamp timestamp;
  final bool isRead;

  RideChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
  });

  factory RideChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RideChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String rideCollectionPath; // 'ride_requests' or 'rental_requests'
  final String currentUserId;
  final String recipientId;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.rideCollectionPath,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late CollectionReference _messagesCollection;
  bool _showPredefinedMessages = true; // Expanded by default

  // List of predefined messages
  final List<String> _predefinedMessages = [
    "I'm on my way",
    "I've arrived",
    "I'm at the pickup location",
    "I'll be there in 5 minutes",
    "Where are you?",
  ];

  @override
  void initState() {
    super.initState();
    _messagesCollection = FirebaseFirestore.instance
        .collection(widget.rideCollectionPath)
        .doc(widget.rideId)
        .collection('messages');

    // Messages will be marked as read via the StreamBuilder in build()
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  /// Marks the provided list of messages as read
  Future<void> _markBatchAsRead(List<DocumentSnapshot> unreadDocs) async {
    if (unreadDocs.isEmpty) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    final messageText = text.trim();
    if (messageText.isEmpty) return;

    _controller.clear(); // Clear the text field immediately

    try {
      await _messagesCollection.add({
        'text': messageText,
        'senderId': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        displaySnackBar(context, "Failed to send message.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProAppBar(titleText: widget.recipientName),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesCollection
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                // Identify unread messages from the recipient
                final unreadDocs = snapshot.data!.docs.where((doc) {
                  return doc['senderId'] == widget.recipientId &&
                      doc['isRead'] == false;
                }).toList();

                if (unreadDocs.isNotEmpty) {
                  // Defer the update to avoid build-phase side effects
                  Future.microtask(() => _markBatchAsRead(unreadDocs));
                }

                final messages = snapshot.data!.docs
                    .map((doc) => RideChatMessage.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Start from the bottom
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isUser = message.senderId == widget.currentUserId;
                    return _ChatBubble(message: message, isUser: isUser);
                  },
                );
              },
            ),
          ),
          if (_showPredefinedMessages) _buildPredefinedMessages(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Builds the row of predefined message chips
  Widget _buildPredefinedMessages() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      color: isDark ? Colors.black26 : Colors.grey[100],
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.start,
        children: _predefinedMessages.map((text) {
          return ActionChip(
            label: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
            onPressed: () {
              _sendMessage(text); // Send the predefined message
              setState(
                () => _showPredefinedMessages = false,
              ); // Collapse after sending
            },
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          );
        }).toList(),
      ),
    );
  }

  /// Builds the text input bar
  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: SafeArea(
        child: Row(
          children: [
            // Quick Chat Toggle Button
            IconButton(
              icon: Icon(
                _showPredefinedMessages
                    ? Icons.keyboard_arrow_down
                    : Icons.flash_on,
                color: Colors.amber,
              ),
              onPressed: () {
                setState(() {
                  _showPredefinedMessages = !_showPredefinedMessages;
                });
              },
              tooltip: "Quick Chat",
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.send),
              color: Colors.blueAccent,
              onPressed: () => _sendMessage(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple Chat Bubble Widget
class _ChatBubble extends StatelessWidget {
  final RideChatMessage message;
  final bool isUser;

  const _ChatBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final color = isUser
        ? Colors.blueAccent
        : (isDark ? Colors.grey[800] : Colors.grey[300]);

    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ),
        // **NEW:** Read receipt logic (Double Tick)
        if (isUser)
          Padding(
            padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
            child: Icon(
              Icons.done_all, // Always double tick
              size: 16,
              color: message.isRead
                  ? Colors.blue
                  : Colors.grey, // Blue if read, Grey if sent
            ),
          ),
      ],
    );
  }
}
