class FormValidator {
  // Regular expressions for validation
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
  );

  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");

  static final RegExp _phoneRegex = RegExp(r"^\d{10}$");

  /// Validates an email address.
  /// Returns true if the email is valid.
  static bool isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates a password.
  /// Rules:
  /// - At least 8 characters long
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one digit
  /// - At least one special character (!@#$&*~)
  static bool isValidPassword(String password) {
    return _passwordRegex.hasMatch(password);
  }

  /// Validates a name.
  /// Rules:
  /// - Must be at least [minLength] characters long.
  /// - Must contain only letters, spaces, hyphens, or apostrophes.
  static bool isValidName(String name, {int minLength = 2}) {
    final trimmedName = name.trim();
    if (trimmedName.length < minLength) return false;
    return _nameRegex.hasMatch(trimmedName);
  }

  /// Validates a 10-digit phone number.
  static bool isValidPhoneNumber(String phone) {
    return _phoneRegex.hasMatch(phone.trim());
  }

  // --- Helper Methods for FormFieldValidator ---

  /// Returns an error message if the email is invalid, otherwise null.
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Returns an error message if the password is invalid, otherwise null.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!isValidPassword(value)) {
      return 'Password must be 8+ chars with Upper, Lower, Digit & Special char';
    }
    return null;
  }

  /// Returns an error message if the name is invalid, otherwise null.
  static String? validateName(String? value, {String label = 'Name'}) {
    if (value == null || value.isEmpty) {
      return '$label is required';
    }
    if (!isValidName(value)) {
      return 'Please enter a valid $label';
    }
    return null;
  }

  /// Returns an error message if the phone number is invalid, otherwise null.
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!isValidPhoneNumber(value)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }
}
