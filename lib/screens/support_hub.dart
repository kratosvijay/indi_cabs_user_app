import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/email_support.dart';
import 'package:project_taxi_with_ai/screens/support_chat.dart';
import 'package:project_taxi_with_ai/screens/support_tickets_list.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class SupportHubScreen extends StatelessWidget {
  const SupportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProAppBar(titleText: "support".tr),
      body: FadeInSlide(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "howCanWeHelp".tr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              _SupportOptionCard(
                title: "chatWithAi".tr,
                description: "chatWithAiDesc".tr,
                icon: Icons.smart_toy_outlined,
                onTap: () {
                  Get.to(() => const SupportChatScreen());
                },
              ),
              const SizedBox(height: 20),
              _SupportOptionCard(
                title: "emailSupport".tr,
                description: "emailSupportDesc".tr,
                icon: Icons.email_outlined,
                onTap: () {
                  Get.to(() => const EmailSupportScreen());
                },
              ),
              const SizedBox(height: 20),
              _SupportOptionCard(
                title: "My Support Tickets", // Or translate if needed
                description: "View and track your previous requests",
                icon: Icons.history_edu_outlined,
                onTap: () {
                  Get.to(() => const SupportTicketsList());
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
