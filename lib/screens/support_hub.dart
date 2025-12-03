import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/email_support.dart';
import 'package:project_taxi_with_ai/screens/support_chat.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class SupportHubScreen extends StatelessWidget {
  const SupportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProAppBar(titleText: "Support"),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "How can we help you?",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _SupportOptionCard(
                title: "Chat with our AI Bot",
                description: "Get instant answers to common questions.",
                icon: Icons.smart_toy_outlined,
                onTap: () {
                  Get.to(() => const SupportChatScreen());
                },
              ),
              const SizedBox(height: 20),
              _SupportOptionCard(
                title: "Email Support Team",
                description: "Contact a human agent for complex issues.",
                icon: Icons.email_outlined,
                onTap: () {
                  Get.to(() => const EmailSupportScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _SupportOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blueAccent),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
