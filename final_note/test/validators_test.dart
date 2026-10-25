import 'package:final_note/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email validation accepts valid and rejects invalid emails', () {
      expect(Validators.email(''), 'Enter your email address.');
      expect(Validators.email('   '), 'Enter your email address.');
      expect(Validators.email('invalid'), 'Enter a valid email address.');
      expect(Validators.email('user@'), 'Enter a valid email address.');
      expect(Validators.email('user@domain'), 'Enter a valid email address.');
      expect(Validators.email('user@domain.com'), isNull);
    });

    test('required password validation checks for presence', () {
      expect(Validators.requiredPassword(null), 'Enter your password.');
      expect(Validators.requiredPassword(''), 'Enter your password.');
      expect(Validators.requiredPassword('secret'), isNull);
    });

    test('new password validation checks minimum length', () {
      expect(Validators.newPassword(''), 'Create a password.');
      expect(Validators.newPassword('1234567'), 'Use at least 8 characters.');
      expect(Validators.newPassword('12345678'), isNull);
    });

    test('confirm password validator compares values', () {
      var base = 'mypassword';
      final validator = Validators.confirmPassword(() => base);

      expect(validator(''), 'Confirm your password.');
      expect(validator('wrongpassword'), 'Passwords do not match.');
      expect(validator('mypassword'), isNull);
    });

    test('display name validator requires non-whitespace content', () {
      expect(Validators.displayName(''), 'Enter your display name.');
      expect(Validators.displayName('   '), 'Enter your display name.');
      expect(Validators.displayName('Hieu Nguyen'), isNull);
    });

    test('password strength evaluation returns expected levels', () {
      expect(evaluatePasswordStrength(''), PasswordStrength.empty);
      expect(evaluatePasswordStrength('short'), PasswordStrength.weak);
      expect(evaluatePasswordStrength('password1'), PasswordStrength.fair);
      expect(evaluatePasswordStrength('Pass123456'), PasswordStrength.good);
      expect(
        evaluatePasswordStrength('P@ssw0rd!2026#Secure'),
        PasswordStrength.strong,
      );
    });
  });
}
