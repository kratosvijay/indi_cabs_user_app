import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Helper widget for building a feature item
  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const ProAppBar(titleText: "About Us"),
      body: FadeInSlide(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // App Logo
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

              // App Name
              Text(
                "Indi Cabs",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // App Version
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
                  "Version 1.2.1",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Mission Card
              Container(
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
                  children: [
                    Text(
                      "Our Mission",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "To redefine urban mobility in India by providing a safe, reliable, and premium ride-hailing experience. We connect you with professional drivers and smart technology to ensure every journey is seamless.",
                      textAlign: TextAlign.center,
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

              // Key Features Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Why Choose Us",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Features List
              _buildFeatureItem(
                context,
                Icons.bolt_rounded,
                "Instant Booking",
                "Get a ride in seconds with our smart dispatch system. Just set your destination and go.",
              ),
              _buildFeatureItem(
                context,
                Icons.payments_outlined,
                "Transparent Pricing",
                "Know your fare upfront. No hidden charges, no surprises—just fair and transparent pricing.",
              ),
              _buildFeatureItem(
                context,
                Icons.shield_outlined,
                "Safety First",
                "Your safety is our priority. Enjoy verified drivers, ride tracking, and 24/7 support.",
              ),
              _buildFeatureItem(
                context,
                Icons.support_agent_rounded,
                "24/7 Support",
                "We're always here for you. Chat with our AI assistant or contact our support team anytime.",
              ),

              const SizedBox(height: 40),

              // Copyright
              Text(
                "© 2025 Indi Cabs. All rights reserved.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
