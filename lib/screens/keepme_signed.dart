import 'package:flutter/material.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthController will handle navigation once it initializes.
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
