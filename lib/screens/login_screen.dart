import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/screens/forgot_password.dart';
import 'package:project_taxi_with_ai/screens/signup_screen.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.instance;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: const ProAppBar(titleText: 'Sign In'),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Obx(
                () => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // --- Email Text Field ---
                    ProTextField(
                      controller: emailController,
                      hintText: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    // --- Password Text Field ---
                    ProTextField(
                      controller: passwordController,
                      hintText: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),
                    ProButton(
                      text: "Sign In",
                      isLoading: controller.isLoading.value,
                      // backgroundColor: Colors.blueAccent, // Removed to use default gradient
                      onPressed: () {
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();

                        if (email.isEmpty || password.isEmpty) {
                          Get.snackbar(
                            "Error",
                            "Please enter both email and password",
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }

                        if (!GetUtils.isEmail(email)) {
                          Get.snackbar(
                            "Error",
                            "Email address is not valid",
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }

                        controller.login(email, password);
                      },
                    ),
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
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () {
                          Get.to(() => const ForgotPasswordScreen());
                        },
                        child: Text(
                          'Forgot your password?',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
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
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
