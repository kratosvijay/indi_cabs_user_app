import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with CodeAutoFill {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingOtp = true;
  String? _verificationId;
  int? _resendToken;
  
  // Timer logic
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOtp();
    _startTimer();
    listenForCode(); // Start listening for SMS
  }

  @override
  void codeUpdated() {
    setState(() {
      _otpController.text = code ?? "";
    });
    if (code != null && code!.length == 6) {
      _verifyOtp();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    unregisterListener();
    super.dispose();
  }

  void _startTimer() {
    _canResend = false;
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _isLoading = false;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (common on Android)
          _otpController.text = credential.smsCode ?? "";
          await _verifyOtp(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            Get.snackbar(
              "error".tr,
              e.message ?? "Failed to send OTP",
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.red.withValues(alpha: 0.1),
            );
            setState(() {
              _isSendingOtp = false;
              _isLoading = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isSendingOtp = false;
            });
            Get.snackbar(
              "success".tr,
              "otpSentSuccess".tr,
              snackPosition: SnackPosition.TOP,
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isSendingOtp = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        Get.snackbar("Error", e.toString());
      }
    }
  }

  Future<void> _verifyOtp([PhoneAuthCredential? credential]) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    try {
      final otpCredential = credential ??
          PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: _otpController.text.trim(),
          );

      // Flag this as a phone login attempt
      AuthController.instance.isPhoneLoginAttempt = true;

      await FirebaseAuth.instance.signInWithCredential(otpCredential);
      // AuthController handles navigation via authStateChanges
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Get.snackbar(
          "error".tr,
          e.message ?? "Invalid OTP or verification failed.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red.withValues(alpha: 0.1),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar("Error", e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.getAppBarGradient(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ProAppBar(
          titleText: 'verifyOtp'.tr,
        ),
        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'enterCode'.tr,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${"otpSentTo".tr} ${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // 6-Digit PIN UI
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 50,
                  fieldWidth: 45,
                  activeFillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  inactiveFillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  selectedFillColor: isDark ? Colors.grey[800] : Colors.white,
                  activeColor: Theme.of(context).primaryColor,
                  inactiveColor: Colors.grey.withValues(alpha: 0.3),
                  selectedColor: Theme.of(context).primaryColor,
                ),
                cursorColor: Theme.of(context).primaryColor,
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                onCompleted: (v) => _verifyOtp(),
                onChanged: (value) {},
                beforeTextPaste: (text) => true,
              ),
              
              const SizedBox(height: 30),
              
              _isSendingOtp 
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Sending OTP..."),
                    ],
                  )
                : ProButton(
                    text: "verifyAndSignIn".tr,
                    isLoading: _isLoading,
                    onPressed: _otpController.text.length == 6 ? () => _verifyOtp() : null,
                  ),
              
              const SizedBox(height: 30),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _canResend ? "didNotReceive".tr : "${"resendIn".tr} ${_secondsRemaining}s",
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  if (_canResend)
                    TextButton(
                      onPressed: () {
                        _startTimer();
                        _sendOtp();
                      },
                      child: Text(
                        'resendOtp'.tr,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
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
    );
  }
}
