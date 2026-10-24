/// Form validators shared by authentication and profile screens.
///
/// Each function follows the [FormFieldValidator] signature and returns
/// `null` when the value is valid, or a user-facing message otherwise.
abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const minPasswordLength = 8;

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  static String? requiredPassword(String? value) =>
      value == null || value.isEmpty ? 'Enter your password.' : null;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password.';
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Confirm your password.';
      if (value != original()) return 'Passwords do not match.';
      return null;
    };
  }

  static String? displayName(String? value) =>
      value == null || value.trim().isEmpty ? 'Enter your display name.' : null;
}

/// Password strength levels shown by the strength meter.
enum PasswordStrength { empty, weak, fair, good, strong }

PasswordStrength evaluatePasswordStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  var score = 0;
  if (password.length >= Validators.minPasswordLength) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

  if (password.length < Validators.minPasswordLength || score <= 1) {
    return PasswordStrength.weak;
  }
  if (score == 2) return PasswordStrength.fair;
  if (score == 3) return PasswordStrength.good;
  return PasswordStrength.strong;
}
