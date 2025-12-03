import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (!FormValidator.isValidEmail(email)) {
      if (mounted) {
        displaySnackBar(context, "Please enter a valid email address");
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- ActionCodeSettings for Dynamic Links Deprecation ---
      // IMPORTANT: Replace 'YOUR_PROJECT_ID', 'your.android.package.name', and 'your.ios.bundle.id'
      // Ensure 'YOUR_PROJECT_ID.firebaseapp.com' is whitelisted in Firebase Auth settings.
      // You also need to set up Firebase Hosting for the default action URL to work.
      final actionCodeSettings = ActionCodeSettings(
        url:
            'https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/action', // Default Firebase Hosting action URL
        handleCodeInApp: false, // Password reset typically handled on web
        androidPackageName:
            'your.android.package.name', // Replace with your package name
        androidInstallApp: true,
        androidMinimumVersion: '12',
        iOSBundleId: 'your.ios.bundle.id', // Replace with your iOS bundle ID
      );
      // --- End ActionCodeSettings ---

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings, // Pass the settings here
      );

      if (mounted) {
        displaySnackBar(
          context,
          "Password reset link sent! Check your email.",
          isError: false,
        );
        Get.back();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        displaySnackBar(context, e.message ?? "An error occurred");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ProAppBar(titleText: 'Reset Password'),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter your email and we will send you a password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 30),
              ProTextField(
                controller: _emailController,
                hintText: 'Enter your registered email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 30),
              ProButton(
                text: 'Send Reset Link',
                onPressed: _isLoading ? null : _sendResetEmail,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
