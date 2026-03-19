import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_taxi_with_ai/screens/home_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;
  int? _resendToken;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty) {
      Get.snackbar("Error", "All fields are required", snackPosition: SnackPosition.TOP);
      return;
    }

    if (!GetUtils.isEmail(email)) {
      Get.snackbar("Error", "Email address is not valid", snackPosition: SnackPosition.TOP);
      return;
    }

    if (!FormValidator.isValidPhoneNumber(phone)) {
      Get.snackbar("Error", "Please enter a valid 10-digit phone number", snackPosition: SnackPosition.TOP);
      return;
    }

    final phoneNumber = "+91$phone";

    setState(() => _isLoading = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _verifyOtp(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          Get.snackbar("Error", e.message ?? "Failed to send OTP", snackPosition: SnackPosition.TOP);
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
          Get.snackbar("Success", "OTP sent successfully!", snackPosition: SnackPosition.TOP);
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

  Future<void> _setupPermissions(User user) async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
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

      // Block _setInitialScreen to manually create Firestore user doc
      AuthController.instance.pauseAutoNavigation = true;

      final userCredential = await FirebaseAuth.instance.signInWithCredential(otpCredential);
      final user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName("${_firstNameController.text.trim()} ${_lastNameController.text.trim()}");

        // Write to Firestore
        final userData = {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': "+91${_phoneController.text.trim()}",
          'createdAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL ?? '',
          'uid': user.uid,
          'wallet_balance': 0,
        };

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));

        await _setupPermissions(user);

        if (mounted) {
          Get.snackbar("Success", "Account created successfully!", snackPosition: SnackPosition.TOP);
          AuthController.instance.pauseAutoNavigation = false;
          
          // Re-initialize RideController explicitly or it might be missing
          Get.offAll(() => HomePage(user: user));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Get.snackbar("Error", e.message ?? "Invalid OTP or verification failed.", snackPosition: SnackPosition.TOP);
      }
      AuthController.instance.pauseAutoNavigation = false;
    } catch (e) {
      if (mounted) {
        Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.TOP);
      }
      AuthController.instance.pauseAutoNavigation = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProAppBar(
        titleText: 'Sign Up',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.offAll(() => const SignInScreen());
          },
        ),
      ),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _otpSent ? 'Verify OTP' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  
                  if (!_otpSent) ...[
                    ProTextField(
                      controller: _firstNameController,
                      hintText: 'Enter your first name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: _lastNameController,
                      hintText: 'Enter your last name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: _phoneController,
                      hintText: '10-digit mobile number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ] else ...[
                    ProTextField(
                      controller: _otpController,
                      hintText: 'Enter 6-digit code',
                      icon: Icons.password,
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  const SizedBox(height: 30),
                  ProButton(
                    text: _otpSent ? "Verify & Sign Up" : "Next",
                    isLoading: _isLoading,
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

                  const SizedBox(height: 15),
                  if (!_otpSent)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Get.back();
                          },
                          child: Text(
                            'Sign In',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
