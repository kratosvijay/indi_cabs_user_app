import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class CrashReportingService {
  static void showCrashDialog(Object error, StackTrace stack) {
    if (Get.context == null) return;

    // Prevent stacking dialogs if multiple errors originate from the same root cause
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      AlertDialog(
        title: const Text("Oops, something went wrong"),
        content: const Text(
          "An unexpected error occurred. Would you like to send a crash report to the support team so we can fix it?",
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Get.back(); // Close dialog first
              _sendCrashReport(error, stack);
            },
            child: const Text("Send Report"),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> _sendCrashReport(Object error, StackTrace stack) async {
    const String recipientEmail =
        "dillivijay123@gmail.com"; // Replace with actual support email
    const String subject = "App Crash Report - Indi Cabs User App";

    final String body =
        '''
App Version: 1.2.1+1 (Please update if dynamic version checking is implemented)
Platform: ${defaultTargetPlatform.name}
Time: ${DateTime.now().toIso8601String()}

Error Message:
$error

Stack Trace:
$stack
    ''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail,
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        Get.snackbar(
          "Error",
          "Could not open email client.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint("Error launching email client: $e");
    }
  }
}
