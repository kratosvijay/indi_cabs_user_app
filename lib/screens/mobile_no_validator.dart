import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';
import 'home_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class PhoneAuthScreen extends StatefulWidget {
  final User user;
  final String? firstName;
  final String? lastName;

  const PhoneAuthScreen({
    super.key,
    required this.user,
    this.firstName,
    this.lastName,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _verificationId;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

  Future<void> _setupPermissions(User user) async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted push notification permission');
      String? token = await _messaging.getToken();
      if (token != null) {
        _saveTokenToFirestore(token, user.uid);
      }
    } else {
      debugPrint('User declined notification permission');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions are denied.");
        Get.snackbar(
          "Permission Denied",
          "Location permission is needed to find rides.",
          snackPosition: SnackPosition.TOP,
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions are permanently denied.");
      Get.snackbar(
        "Permission Denied",
        "Location permission is permanently denied. Please enable it in your phone settings.",
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> _saveTokenToFirestore(String? token, String uid) async {
    if (token == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("FCM Token saved to Firestore.");
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
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

      if (credential != null) {
        await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        if (_verificationId == null || _otpController.text.trim().isEmpty) {
          throw FirebaseAuthException(
            code: 'invalid-otp',
            message: 'Please enter the OTP.',
          );
        }
        await widget.user.updatePhoneNumber(otpCredential);
      }

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid);

      String firstName = widget.firstName ?? '';
      String lastName = widget.lastName ?? '';
      if (firstName.isEmpty && widget.user.displayName != null) {
        final nameParts = widget.user.displayName!.split(' ');
        firstName = nameParts.first;
        if (nameParts.length > 1) {
          lastName = nameParts.sublist(1).join(' ');
        }
      }

      final userData = {
        'firstName': firstName,
        'lastName': lastName,
        'email': widget.user.email,
        'phoneNumber': "+91${_phoneController.text.trim()}",
        'createdAt': FieldValue.serverTimestamp(),
        'photoURL': widget.user.photoURL ?? '',
        'uid': widget.user.uid,
        'wallet_balance': 0,
      };

      await userDoc.set(userData, SetOptions(merge: true));

      await _setupPermissions(widget.user);

      if (mounted) {
        Get.snackbar(
          "Success",
          "Phone number verified!",
          snackPosition: SnackPosition.TOP,
        );
        Get.offAll(() => HomePage(user: widget.user));
      }
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
    return Scaffold(
      appBar: const ProAppBar(titleText: 'Verify Mobile Number'),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                !_otpSent ? 'Enter your mobile number' : 'Enter the OTP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
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
                text: _otpSent ? 'Verify OTP' : 'Send OTP',
                onPressed: _isLoading
                    ? null
                    : (_otpSent ? () => _verifyOtp() : _sendOtp),
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
