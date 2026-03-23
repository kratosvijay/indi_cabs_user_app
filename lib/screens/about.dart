import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/screens/policy_screen.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:get/get.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: ProAppBar(titleText: "aboutUs".tr),
      body: FadeInSlide(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and App Name
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logos/app_logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "IndiCabs",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${'version'.tr} 1.2.1",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // About IndiCabs Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
                        : [Colors.blue.shade50, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.blue.shade100,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "aboutIndiCabs".tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "aboutIndiCabsDesc".tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "mission".tr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // What We Do
              Text(
                "🚗 ${'whatWeDo'.tr}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildSimpleListItem(
                context,
                "bookInstantRides".tr,
              ),
              _buildSimpleListItem(context, "trackDrivers".tr),
              _buildSimpleListItem(context, "securePayments".tr),
              _buildSimpleListItem(context, "transparentPricing".tr),
              _buildSimpleListItem(
                context,
                "travelSafely".tr,
              ),
              const SizedBox(height: 12),
              Text(
                "pricingInInr".tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                ),
              ),

              const SizedBox(height: 24),
              Text(
                "${'forDrivers'.tr}:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "flexibleEarning".tr),
              _buildSimpleListItem(context, "smartMatching".tr),
              _buildSimpleListItem(context, "realTimeNav".tr),
              _buildSimpleListItem(context, "transparentDetails".tr),
              _buildSimpleListItem(context, "secureSettlements".tr),

              const SizedBox(height: 40),

              // Safety & Trust
              Text(
                "🔒 ${'safetyAndTrust'.tr}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "safetyDesc".tr,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "realTimeTracking".tr),
              _buildSimpleListItem(context, "verifiedOnboarding".tr),
              _buildSimpleListItem(context, "securePayments".tr),
              _buildSimpleListItem(context, "support".tr),
              _buildSimpleListItem(context, "dataPrivacy".tr),
              const SizedBox(height: 12),
              Text(
                "dataPrivacy".tr,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              // Smart Technology
              Text(
                "📍 ${'smartTech'.tr}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "smartTechDesc".tr,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "realTimeTracking".tr),
              _buildSimpleListItem(context, "smartMatching".tr),
              _buildSimpleListItem(context, "cloudInfra".tr),
              _buildSimpleListItem(context, "securePayments".tr),
              const SizedBox(height: 12),
              Text(
                "transparency".tr,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // Our Vision
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E2A38), const Color(0xFF161F29)]
                        : [Colors.indigo.shade50, Colors.white],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.indigo.shade900
                        : Colors.indigo.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "💡 ${'vision'.tr}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "visionDesc".tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "commitment".tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Company Information
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 32,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "IndiCabs",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${'operatedBy'.tr}: Indiverse Enterprises Pvt Ltd",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "address".tr,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${'contactUs'.tr}: support@indicabs.net",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        TextButton(
                          onPressed: () {
                            Get.to(() => PolicyScreen(
                                  title: "termsAndConditions".tr,
                                  content:
                                      "Welcome to IndiCabs. By using our services, you agree to comply with and be bound by the following terms and conditions of use, which together with our privacy policy govern IndiCabs's relationship with you in relation to this app and website. The term 'IndiCabs' or 'us' or 'we' refers to the owner of the website and app, Indiverse Enterprises Pvt Ltd, whose registered office is in Chennai, Tamil Nadu, India. The term 'you' refers to the user or viewer of our app.\n\n"
                                      "1. Use of Service: You must be at least 18 years of age to use this service.\n"
                                      "2. User Accounts: You are responsible for maintaining the confidentiality of your account and password.\n"
                                      "3. Payments: All payments must be made through the app's integrated payment systems or in cash as specified.\n"
                                      "4. Liability: IndiCabs is not liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use the service.\n"
                                      "5. Changes to Terms: We reserve the right to modify these terms at any time.",
                                ));
                          },
                          child: Text("terms".tr),
                        ),
                        const Text(" • "),
                        TextButton(
                          onPressed: () {
                            Get.to(() => PolicyScreen(
                                  title: "refundsAndCancellations".tr,
                                  content:
                                      "At IndiCabs, we strive to ensure a smooth experience. Our refund and cancellation policy is as follows:\n\n"
                                      "1. Cancellation by User: You may cancel your ride request at any time. However, a cancellation fee may be charged if the driver has already accepted and reached the pickup point or is nearby.\n"
                                      "2. Cancellation by Driver: If a driver cancels the ride, no fee will be charged to the user, and we will attempt to find another driver immediately.\n"
                                      "3. Refunds: Any excess amount charged or technical failure during digital payments will be refunded to the original payment source within 5-7 working days after verification.\n"
                                      "4. Disputes: For any payment-related disputes, please contact us at support@indicabs.net with your ride ID.",
                                ));
                          },
                          child: Text("refundPolicy".tr),
                        ),
                        const Text(" • "),
                        TextButton(
                          onPressed: () {
                            Get.to(() => PolicyScreen(
                                  title: "privacyPolicy".tr,
                                  content:
                                      "At IndiCabs, we take your privacy seriously. This policy explains how we collect and use your data:\n\n"
                                      "1. Data Collection: We collect information you provide (name, email, phone) and location data to facilitate rides.\n"
                                      "2. Data Usage: Your data is used to process bookings, ensure safety, and improve our services.\n"
                                      "3. Data Sharing: We share necessary details with drivers to complete your ride. We do not sell your personal data to third parties.\n"
                                      "4. Security: We implement industry-standard security measures to protect your information.\n"
                                      "5. Your Rights: You can request access or deletion of your data through the app settings.",
                                ));
                          },
                          child: Text("privacyPolicy".tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "© ${DateTime.now().year} Indi Cabs. ${'rightsReserved'.tr}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New helper widget for simple bullet-style list items
  Widget _buildSimpleListItem(BuildContext context, String text) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
