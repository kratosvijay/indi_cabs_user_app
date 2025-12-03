// ignore_for_file: camel_case_types

import 'package:flutter/material.dart';



class Social_LoginButton extends StatelessWidget {
  final String logoPath;
  final String text;
  final VoidCallback onPressed;

  const Social_LoginButton({
    super.key,
    required this.logoPath,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor:
            const Color(0xFF424242), // Dark grey button background
        foregroundColor: Colors.white, // With white text
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            logoPath,
            height: 24.0, // Standard icon size
            width: 24.0,
            // Error handling for when the image asset is not found
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, color: Colors.red);
            },
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}