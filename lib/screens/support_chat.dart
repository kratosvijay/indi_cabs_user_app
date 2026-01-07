// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:project_taxi_with_ai/widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/app_colors.dart';

// A simple model for a chat message
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});

  // For sending to the Cloud Function
  Map<String, dynamic> toJson() {
    return {
      'role': isUser ? 'user' : 'model',
      'parts': [
        {'text': text},
      ],
    };
  }
}

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final HttpsCallable _chatbotCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('getChatbotResponse');
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hello! How can I assist you with your ride today?",
      isUser: false,
    ),
  ];
  bool _isLoading = false; // To show typing indicator

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Add a small delay to ensure the list has rebuilt
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

    // Add user message to UI
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Prepare history for the function
    // (Send all messages except the initial greeting)
    final history = _messages.length > 1
        ? _messages
              .sublist(1, _messages.length - 1)
              .map((m) => m.toJson())
              .toList()
        : [];

    try {
      // Call the cloud function
      final result = await _chatbotCallable.call<Map<dynamic, dynamic>>({
        'prompt': text,
        'history': history,
      });

      final botResponse =
          result.data['response'] as String? ??
          "Sorry, I had trouble connecting.";

      // Add bot response to UI
      setState(() {
        _messages.add(ChatMessage(text: botResponse, isUser: false));
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        displaySnackBar(
          context,
          "Error: ${e.message ?? 'Failed to get response'}",
        );
      }
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Sorry, I'm having trouble connecting.",
            isUser: false,
          ),
        );
      });
      if (kDebugMode) print("Functions Error: ${e.message}");
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "An unexpected error occurred.");
      }
      setState(() {
        _messages.add(
          ChatMessage(text: "An unexpected error occurred.", isUser: false),
        );
      });
      if (kDebugMode) print("Generic Error: $e");
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const ProAppBar(titleText: "Support Chat"),
      body: Column(
        children: [
          // Chat message list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return FadeInSlide(
                    delay: 0.1,
                    child: _ChatBubble(
                      message: ChatMessage(text: "...", isUser: false),
                      isTyping: true,
                    ),
                  );
                }
                final message = _messages[index];
                return FadeInSlide(
                  delay: 0.05, // Small delay for effect
                  child: _ChatBubble(message: message),
                );
              },
            ),
          ),
          // Input area
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, size: 22),
                color: Colors.white,
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Chat Bubble Widget
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isTyping;

  const _ChatBubble({required this.message, this.isTyping = false});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    // User Bubble Gradient
    final userGradient = AppColors.getAppBarGradient(context);

    // Bot Bubble Color
    final botColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent,
                size: 16,
                color: isDark ? Colors.white70 : Colors.blue,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                gradient: message.isUser ? userGradient : null,
                color: message.isUser ? null : botColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: message.isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
              ),
              child: isTyping
                  ? SizedBox(
                      width: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDot(0, isDark),
                          const SizedBox(width: 4),
                          _buildDot(1, isDark),
                          const SizedBox(width: 4),
                          _buildDot(2, isDark),
                        ],
                      ),
                    )
                  : Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isDark ? Colors.white70 : Colors.grey.shade600,
        shape: BoxShape.circle,
      ),
    );
  }
}
