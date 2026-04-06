import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/screens/signup_screen.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';
import 'package:project_taxi_with_ai/screens/otp_verification_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setHasSeenOnboarding();
  }

  Future<void> _setHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _navigateToOtp() {
    final phoneNumber = "+91${_phoneController.text.trim()}";
    if (!FormValidator.isValidPhoneNumber(_phoneController.text.trim())) {
      Get.snackbar(
        "error".tr,
        "invalidPhone".tr,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withValues(alpha: 0.1),
      );
      return;
    }

    // Instant Navigation
    Get.to(() => OtpVerificationScreen(phoneNumber: phoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.instance;

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'signIn'.tr,
      ),
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: FadeInSlide(
          child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Obx(
                () => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'welcomeBack'.tr,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'signInToContinue'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    ProTextField(
                      controller: _phoneController,
                      hintText: 'mobileHint'.tr,
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 30),
                    ProButton(
                      text: "requestOtp".tr,
                      isLoading: _isLoading || controller.isLoading.value,
                      onPressed: _isLoading ? null : _navigateToOtp,
                    ),
                    

                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "noAccount".tr,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Get.to(() => const SignUpScreen());
                          },
                          child: Text(
                            'signUp'.tr,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    // --- OR Divider ---
                    Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('or'.tr),
                        ),
                        const Expanded(child: Divider(thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- Social Login Buttons ---
                    ProButton(
                      text: 'continueWithGoogle'.tr,
                      backgroundColor: Colors.white,
                      textColor: Colors.black87,
                      icon: Image.asset(
                        'assets/logos/google_logo.png',
                        height: 24,
                        width: 24,
                      ),
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.signInWithGoogle,
                    ),
                    const SizedBox(height: 15),
                    // --- Apple Sign In ---
                    ProButton(
                      text: 'continueWithApple'.tr,
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      icon: Image.asset(
                        'assets/logos/apple_logo.png',
                        height: 24,
                        width: 24,
                        color: Colors
                            .white, // Ensure logo is white on black button
                      ),
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.signInWithApple,
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
