import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/screens/ticket_chat_screen.dart';

class EmailSupportScreen extends StatefulWidget {
  const EmailSupportScreen({super.key});

  @override
  State<EmailSupportScreen> createState() => _EmailSupportScreenState();
}

class _EmailSupportScreenState extends State<EmailSupportScreen> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final HttpsCallable _sendEmailCallable = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable('sendSupportEmail');
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_subjectController.text.isEmpty || _bodyController.text.isEmpty) {
      if (mounted) {
        displaySnackBar(context, "Please fill out both fields.");
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint("DEBUG: Sending support email. User ID: ${user?.uid}");
      debugPrint("DEBUG: User is anonymous: ${user?.isAnonymous}");
      debugPrint("DEBUG: User Email: ${user?.email}");

      if (user == null) {
        if (mounted) displaySnackBar(context, "Error: You must be logged in to send support emails.");
        return;
      }

      final result = await _sendEmailCallable.call({
        'subject': _subjectController.text,
        'body': _bodyController.text,
      });

      if (mounted) {
        final ticketId = result.data['ticketId'] as String?;
        _subjectController.clear();
        _bodyController.clear();
        
        displaySnackBar(
          context,
          "Ticket #$ticketId opened successfully!",
          isError: false,
        );

        // Fetch the ticket from Firestore to navigate
        final ticketDoc = await FirebaseFirestore.instance
            .collection('support_tickets')
            .doc(ticketId)
            .get();
        
        if (mounted && ticketDoc.exists) {
          final ticket = SupportTicket.fromFirestore(ticketDoc);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TicketChatScreen(ticket: ticket),
            ),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        displaySnackBar(
          context,
          "Error: ${e.message ?? 'Failed to send email'}",
        );
      }
    } catch (e) {
      if (mounted) {
        displaySnackBar(context, "An unexpected error occurred.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const ProAppBar(titleText: "Email Support"),
      body: FadeInSlide(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                        : [Colors.blue.shade50, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 48,
                      color: isDark ? Colors.blue.shade300 : Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "We're here to help!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please describe your issue in detail so we can assist you better.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Subject Field
              Text(
                "Subject",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ProTextField(
                controller: _subjectController,
                hintText: "e.g., Issue with my last ride",
                icon: Icons.title,
              ),
              const SizedBox(height: 20),

              // Message Field (Custom styled since ProTextField is single line by default usually, but checking implementation it seems to wrap TextField so might be ok, but let's check maxLines. ProTextField implementation doesn't expose maxLines. I will create a custom container for the body to support maxLines)
              Text(
                "Message",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: const Offset(2, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                  ],
                ),
                child: TextField(
                  controller: _bodyController,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "Describe your issue here...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Send Button
              ProButton(
                text: _isLoading ? "Sending..." : "Send Email",
                isLoading: _isLoading,
                onPressed: _sendEmail,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
