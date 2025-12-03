import 'package:flutter/material.dart';


class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  // State variable to toggle password visibility
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      // This is the core logic for hiding/showing the password.
      // It's only true if it's a password field AND the visibility is toggled off.
      obscureText: widget.isPassword && _isObscured,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: Icon(widget.prefixIcon),
        // The suffix icon is only shown for password fields.
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  // Choose the icon based on the visibility state.
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  // This is where the magic happens. Calling setState rebuilds
                  // the widget with the new _isObscured value.
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              )
            : null, // No suffix icon if it's not a password field.
      ),
    );
  }
}

