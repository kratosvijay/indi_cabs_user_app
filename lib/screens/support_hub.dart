import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/email_support.dart';
import 'package:project_taxi_with_ai/screens/policy_screen.dart';
import 'package:project_taxi_with_ai/screens/support_chat.dart';
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
                title: "termsAndConditions".tr,
                description: "termsDesc".tr,
                icon: Icons.description_outlined,
                onTap: () {
                  Get.to(
                    () => PolicyScreen(
                      title: "termsAndConditions".tr,
                      content:
                          "Welcome to IndiCabs. By using our services, you agree to comply with and be bound by the following terms and conditions of use, which together with our privacy policy govern IndiCabs's relationship with you in relation to this app and website. The term 'IndiCabs' or 'us' or 'we' refers to the owner of the website and app, Indiverse Enterprises Pvt Ltd, whose registered office is in Chennai, Tamil Nadu, India. The term 'you' refers to the user or viewer of our app.\n\n"
                          "1. Use of Service: You must be at least 18 years of age to use this service.\n"
                          "2. User Accounts: You are responsible for maintaining the confidentiality of your account and password.\n"
                          "3. Payments: All payments must be made through the app's integrated payment systems or in cash as specified.\n"
                          "4. Liability: IndiCabs is not liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use the service.\n"
                          "5. Changes to Terms: We reserve the right to modify these terms at any time.",
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _SupportOptionCard(
                title: "refundsAndCancellations".tr,
                description: "refundsDesc".tr,
                icon: Icons.assignment_return_outlined,
                onTap: () {
                  Get.to(
                    () => PolicyScreen(
                      title: "refundsAndCancellations".tr,
                      content:
                          "At IndiCabs, we strive to ensure a smooth experience. Our refund and cancellation policy is as follows:\n\n"
                          "1. Cancellation by User: You may cancel your ride request at any time. However, a cancellation fee may be charged if the driver has already accepted and reached the pickup point or is nearby.\n"
                          "2. Cancellation by Driver: If a driver cancels the ride, no fee will be charged to the user, and we will attempt to find another driver immediately.\n"
                          "3. Refunds: Any excess amount charged or technical failure during digital payments will be refunded to the original payment source within 5-7 working days after verification.\n"
                          "4. Disputes: For any payment-related disputes, please contact us at support@indicabs.net with your ride ID.",
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              _SupportOptionCard(
                title: "privacyPolicy".tr,
                description: "dataPrivacy".tr,
                icon: Icons.privacy_tip_outlined,
                onTap: () {
                  Get.to(
                    () => PolicyScreen(
                      title: "privacyPolicy".tr,
                      content:
                          "At IndiCabs, we take your privacy seriously. This policy explains how we collect and use your data:\n\n"
                          "1. Data Collection: We collect information you provide (name, email, phone) and location data to facilitate rides.\n"
                          "2. Data Usage: Your data is used to process bookings, ensure safety, and improve our services.\n"
                          "3. Data Sharing: We share necessary details with drivers to complete your ride. We do not sell your personal data to third parties.\n"
                          "4. Security: We implement industry-standard security measures to protect your information.\n"
                          "5. Your Rights: You can request access or deletion of your data through the app settings.",
                    ),
                  );
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
