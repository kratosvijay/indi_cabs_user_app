import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/auth_controller.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/widgets/form_validator.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AuthController.instance;
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return Scaffold(
      appBar: const ProAppBar(titleText: 'Sign Up'),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(height: 40),
                    ProTextField(
                      controller: firstNameController,
                      hintText: 'Enter your first name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: lastNameController,
                      hintText: 'Enter your last name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: emailController,
                      hintText: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: passwordController,
                      hintText: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),
                    ProTextField(
                      controller: confirmPasswordController,
                      hintText: 'Confirm your password',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 30),
                    ProButton(
                      text: "Sign Up",
                      isLoading: controller.isLoading.value,
                      // backgroundColor: Colors.blueAccent, // Removed to use default gradient
                      onPressed: () {
                        final firstName = firstNameController.text.trim();
                        final lastName = lastNameController.text.trim();
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();
                        final confirmPassword = confirmPasswordController.text
                            .trim();

                        if (firstName.isEmpty ||
                            lastName.isEmpty ||
                            email.isEmpty ||
                            password.isEmpty ||
                            confirmPassword.isEmpty) {
                          Get.snackbar(
                            "Error",
                            "All fields are required",
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

                        if (password != confirmPassword) {
                          Get.snackbar(
                            "Error",
                            "Passwords do not match",
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }

                        if (!FormValidator.isValidPassword(password)) {
                          Get.snackbar(
                            "Error",
                            "Password must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one number, and one special character",
                            snackPosition: SnackPosition.TOP,
                          );
                          return;
                        }

                        controller.register(
                          email,
                          password,
                          firstName,
                          lastName,
                        );
                      },
                    ),
                    const SizedBox(height: 15),
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
      ),
    );
  }
}
