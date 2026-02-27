import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const ProAppBar(titleText: "About Us"),
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
                        "Version 1.2.1",
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
                      "About IndiCabs",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "IndiCabs is a smart ride-hailing platform designed to make everyday travel simple, reliable, and affordable. Operated by Indiverse Enterprises Pvt Ltd, IndiCabs connects riders with verified drivers through a seamless and secure mobile experience.",
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
                      "Our mission is to transform local transportation by combining technology, safety, and convenience into one powerful platform.",
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
                "🚗 What We Do",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildSimpleListItem(
                context,
                "Book instant rides within the city",
              ),
              _buildSimpleListItem(context, "Track drivers in real time"),
              _buildSimpleListItem(context, "Make secure in-app payments"),
              _buildSimpleListItem(context, "Experience transparent pricing"),
              _buildSimpleListItem(
                context,
                "Travel safely with verified drivers",
              ),

              const SizedBox(height: 24),
              Text(
                "For Drivers:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "Flexible earning opportunities"),
              _buildSimpleListItem(context, "Smart ride matching"),
              _buildSimpleListItem(context, "Real-time navigation"),
              _buildSimpleListItem(context, "Transparent ride details"),
              _buildSimpleListItem(context, "Secure digital settlements"),

              const SizedBox(height: 40),

              // Safety & Trust
              Text(
                "🔒 Safety & Trust",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We prioritize rider and driver safety through:",
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "Real-time trip tracking"),
              _buildSimpleListItem(context, "Verified driver onboarding"),
              _buildSimpleListItem(context, "Secure payment processing"),
              _buildSimpleListItem(context, "In-app support"),
              _buildSimpleListItem(context, "Account verification mechanisms"),
              const SizedBox(height: 12),
              Text(
                "Your data privacy and ride security are at the core of our platform.",
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              // Smart Technology
              Text(
                "📍 Smart Technology",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "IndiCabs uses advanced technology including:",
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildSimpleListItem(context, "Real-time GPS tracking"),
              _buildSimpleListItem(context, "Intelligent ride matching"),
              _buildSimpleListItem(context, "Secure cloud infrastructure"),
              _buildSimpleListItem(context, "Reliable payment integration"),
              const SizedBox(height: 12),
              Text(
                "Our platform ensures smooth communication between riders and drivers while maintaining transparency in every ride.",
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
                      "💡 Our Vision",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "We aim to build a trusted transportation ecosystem that empowers drivers and delivers dependable mobility solutions to communities across India.",
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
                      "IndiCabs is committed to innovation, customer satisfaction, and sustainable growth in urban mobility.",
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
                      "Operated by: Indiverse Enterprises Pvt Ltd",
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Chennai, Tamil Nadu, India",
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
                        "For enquiries: support@indicabs.net",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "© ${DateTime.now().year} Indi Cabs. All rights reserved.",
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
