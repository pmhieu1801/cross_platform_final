import 'dart:convert';
import 'dart:math';

import '../domain/note_repository.dart';

/// Pure-Dart salted iterative password hashing and verification utility for
/// individual note password protection (R23, R24).
///
/// Note passwords are never stored in plain text. Each protected note stores a
/// unique random [salt] and an iterative 1000-round FNV-1a/SHA-like 256-bit
/// hex digest.
abstract final class NotePasswordSecurity {
  static const int minPasswordLength = 4;
  static const int _iterations = 1000;

  /// Generates a 16-byte random salt encoded as base64Url.
  static String generateSalt({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Validates a candidate note password and confirmation pair.
  ///
  /// Throws [NoteFailure] if invalid.
  static String validateNewPassword({
    required String password,
    required String confirmPassword,
  }) {
    final trimmed = password.trim();
    final trimmedConfirm = confirmPassword.trim();
    if (trimmed.isEmpty) {
      throw const NoteFailure('Note password cannot be empty.');
    }
    if (trimmed.length < minPasswordLength) {
      throw const NoteFailure(
        'Note password must be at least $minPasswordLength characters.',
      );
    }
    if (trimmed != trimmedConfirm) {
      throw const NoteFailure('Note passwords do not match.');
    }
    return trimmed;
  }

  /// Computes a deterministic, non-reversible salted hash for [password] and [salt].
  static String hashPassword({required String password, required String salt}) {
    final normalized = password.trim();
    List<int> state = utf8.encode('noteflow-v1:$salt:$normalized');
    for (var round = 0; round < _iterations; round++) {
      state = _mix256(state, round, salt);
    }
    final buffer = StringBuffer();
    for (final byte in state) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Constant-time comparison of [password] against [expectedHash] and [salt].
  static bool verifyPassword({
    required String password,
    required String? salt,
    required String? expectedHash,
  }) {
    if (salt == null ||
        salt.isEmpty ||
        expectedHash == null ||
        expectedHash.isEmpty) {
      return false;
    }
    final actualHash = hashPassword(password: password, salt: salt);
    if (actualHash.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actualHash.length; i++) {
      diff |= actualHash.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  static List<int> _mix256(List<int> input, int round, String salt) {
    final out = List<int>.filled(32, 0);
    final saltUnits = salt.codeUnits;
    var acc1 = (0x811C9DC5 ^ round) & 0xFFFFFFFF;
    var acc2 = (0x9E3779B9 ^ (round * 31)) & 0xFFFFFFFF;

    for (var i = 0; i < input.length; i++) {
      final b = input[i];
      final s = saltUnits[i % saltUnits.length];
      acc1 = ((acc1 ^ b ^ s) * 0x01000193) & 0xFFFFFFFF;
      acc2 = ((acc2 + ((b << 5) | (b >> 3)) + s + i) * 0x85EBCA6B) & 0xFFFFFFFF;
      final slot = (i + round) & 31;
      out[slot] = (out[slot] ^ (acc1 & 0xFF) ^ ((acc2 >> 8) & 0xFF)) & 0xFF;
    }

    for (var slot = 0; slot < 32; slot++) {
      acc1 = ((acc1 ^ out[slot] ^ slot) * 0x01000193) & 0xFFFFFFFF;
      acc2 = ((acc2 ^ (acc1 >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF;
      out[slot] =
          (out[slot] ^ ((acc1 >> (slot % 24)) & 0xFF) ^ (acc2 & 0xFF)) & 0xFF;
    }
    return out;
  }
}
