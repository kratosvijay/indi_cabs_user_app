import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/screens/signup_screen.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phoneNumber = "+91${_phoneController.text.trim()}";
    if (!FormValidator.isValidPhoneNumber(_phoneController.text.trim())) {
      Get.snackbar(
        "Error",
        "Please enter a valid 10-digit phone number",
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _verifyOtp(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          Get.snackbar(
            "Error",
            e.message ?? "Failed to send OTP",
            snackPosition: SnackPosition.TOP,
          );
          setState(() => _isLoading = false);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpSent = true;
            _isLoading = false;
          });
          Get.snackbar(
            "Success",
            "OTP sent successfully!",
            snackPosition: SnackPosition.TOP,
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) {
          debugPrint("OTP auto-retrieval timed out.");
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _verifyOtp([PhoneAuthCredential? credential]) async {
    setState(() => _isLoading = true);

    try {
      final otpCredential =
          credential ??
          PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: _otpController.text.trim(),
          );

      // Flag this as a phone login attempt so AuthController handles no user doc correctly
      AuthController.instance.isPhoneLoginAttempt = true;

      await FirebaseAuth.instance.signInWithCredential(otpCredential);
      
      // authStateChanges will trigger AuthController._setInitialScreen which handles navigation.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Get.snackbar(
          "Error",
          e.message ?? "Invalid OTP or verification failed.",
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          "Error",
          "An unexpected error occurred: $e",
          snackPosition: SnackPosition.TOP,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.instance;

    return Scaffold(
      appBar: ProAppBar(
        titleText: 'Sign In',
        leading: _otpSent
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _otpSent = false;
                  });
                },
              )
            : null,
      ),
      body: PopScope(
        canPop: !_otpSent,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_otpSent) {
            setState(() {
              _otpSent = false;
            });
          }
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
                      _otpSent ? 'Verify OTP' : 'Welcome Back!',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpSent ? 'Enter the code sent to your phone' : 'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    if (!_otpSent)
                      ProTextField(
                        controller: _phoneController,
                        hintText: '10-digit mobile number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      )
                    else
                      ProTextField(
                        controller: _otpController,
                        hintText: 'Enter 6-digit code',
                        icon: Icons.password,
                        keyboardType: TextInputType.number,
                      ),
                      
                    const SizedBox(height: 30),
                    ProButton(
                      text: _otpSent ? "Verify & Sign In" : "Request OTP",
                      isLoading: _isLoading || controller.isLoading.value,
                      onPressed: _isLoading
                          ? null
                          : (_otpSent ? () => _verifyOtp() : _sendOtp),
                    ),
                    
                    if (_otpSent) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
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
                            'Sign Up',
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
                    
                    if (!_otpSent) ...[
                      const SizedBox(height: 20),
                      // --- OR Divider ---
                      const Row(
                        children: [
                          Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('OR'),
                          ),
                          Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // --- Social Login Buttons ---
                      ProButton(
                        text: 'Continue with Google',
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
                        text: 'Continue with Apple',
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
                    ],
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
