import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';

class TicketChatScreen extends StatefulWidget {
  final SupportTicket ticket;
  const TicketChatScreen({super.key, required this.ticket});

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.ticket.status == 'closed') {
      displaySnackBar(context, "This ticket is closed and cannot receive messages.");
      return;
    }

    setState(() => _isLoading = true);
    _controller.clear();

    try {
      final ticketRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticket.id);

      // 1. Add Message
      await ticketRef.collection('messages').add({
        'sender': 'user',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update Ticket
      await ticketRef.update({
        'lastMessageAt': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) displaySnackBar(context, "Error sending message.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isClosed = widget.ticket.status == 'closed';

    return Scaffold(
      appBar: ProAppBar(
        titleText: "Ticket: ${widget.ticket.id}",
        actions: [],
      ),
      body: Column(
        children: [
          // Informative Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              widget.ticket.subject,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Chat Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .doc(widget.ticket.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = (snapshot.data?.docs ?? [])
                    .map((d) => TicketMessage.fromFirestore(d))
                    .toList();

                if (messages.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return FadeInSlide(
                      delay: 0.05,
                      child: _ChatBubble(message: messages[index]),
                    );
                  },
                );
              },
            ),
          ),
          // Input Area
          if (!isClosed) _buildMessageInput(isDark),
          if (isClosed)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              width: double.infinity,
              child: const Text(
                "This ticket is closed. No more messages allowed.",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Type your message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.getAppBarGradient(context),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final TicketMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
             CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.support_agent, size: 14, color: Colors.blue),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.getAppBarGradient(context) : null,
                color: isUser ? null : (isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
