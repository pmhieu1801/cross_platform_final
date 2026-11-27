import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/auth_providers.dart';
import '../application/avatar_image_validator.dart';
import '../domain/avatar_repository.dart';

/// Account-scoped local avatar store and [AvatarRepository] implementation (R06).
///
/// Validates uploaded image bytes using [AvatarImageValidator] (PNG/JPEG,
/// <= 5 MiB, <= 8192x8192) and stores the encoded bytes per authenticated UID
/// in [SharedPreferences], issuing an [AvatarUploadReceipt] with a safe HTTPS
/// identifier (`https://avatar.noteflow.local/<uid>/<storageKey>`).
class LocalAvatarRepository implements AvatarRepository {
  LocalAvatarRepository({
    this.validator = const AvatarImageValidator(
      policy: AvatarValidationPolicy(
        maxBytes: 5 * 1024 * 1024,
        maxDimension: 8192,
      ),
    ),
  });

  final AvatarImageValidator validator;
  static const _storagePrefix = 'noteflow_account_avatar_v1_';

  static String storageKeyFor(String uid) =>
      '$_storagePrefix${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';

  // Built-in valid 16x16 PNG presets so users can pick/upload a validated
  // avatar across Web and Native without requiring external file permissions.
  static final List<({String id, String label, Uint8List bytes})>
  sampleAvatars = <({String id, String label, Uint8List bytes})>[
    (
      id: 'crimson',
      label: 'Crimson Red (PNG)',
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAdSURBVDhPY0iZ+vY/JZgBXYBUPGrAqAGjBgwWAwBvsOUfyEymUQAAAABJRU5ErkJggg==',
      ),
    ),
    (
      id: 'emerald',
      label: 'Emerald Mint (JPEG)',
      bytes: base64Decode(
        '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAQABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDq6KKK/os/Kj//2Q==',
      ),
    ),
  ];

  final Map<String, AvatarImage> _memoryCache = <String, AvatarImage>{};

  Future<AvatarImage?> loadAvatar(String uid) async {
    if (uid.trim().isEmpty) return null;
    if (_memoryCache.containsKey(uid)) return _memoryCache[uid];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKeyFor(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final base64Bytes = decoded['bytesBase64'] as String?;
      final contentType = decoded['contentType'] as String?;
      if (base64Bytes == null || contentType == null) return null;
      final bytes = base64Decode(base64Bytes);
      final validated = await validator.validate(
        bytes,
        declaredMimeType: contentType,
      );
      _memoryCache[uid] = validated;
      return validated;
    } catch (_) {
      return null;
    }
  }

  /// Validates [rawBytes] and persists the avatar for [expectedUid].
  Future<({AvatarImage image, AvatarUploadReceipt receipt})>
  validateAndSaveAvatar({
    required String expectedUid,
    required Uint8List rawBytes,
    String? declaredMimeType,
  }) async {
    if (expectedUid.trim().isEmpty) {
      throw const AvatarValidationFailure('Phiên đăng nhập không hợp lệ.');
    }
    final validated = await validator.normalizeForAvatar(
      rawBytes,
      declaredMimeType: declaredMimeType,
    );
    final receipt = await upload(expectedUid: expectedUid, image: validated);
    return (image: validated, receipt: receipt);
  }

  @override
  Future<AvatarUploadReceipt> upload({
    required String expectedUid,
    required AvatarImage image,
  }) async {
    if (expectedUid.trim().isEmpty) {
      throw ArgumentError('expectedUid must not be empty.');
    }
    final storageKey = 'avatar_${DateTime.now().microsecondsSinceEpoch}';
    final receipt = AvatarUploadReceipt(
      ownerUid: expectedUid,
      storageKey: storageKey,
      photoUrl: Uri.parse(
        'https://avatar.noteflow.local/${Uri.encodeComponent(expectedUid)}/$storageKey',
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'ownerUid': expectedUid,
      'storageKey': storageKey,
      'contentType': image.contentType,
      'width': image.width,
      'height': image.height,
      'bytesBase64': base64Encode(image.bytes),
    });
    await prefs.setString(storageKeyFor(expectedUid), payload);
    _memoryCache[expectedUid] = image;
    return receipt;
  }

  @override
  Future<void> deleteUploaded({
    required String expectedUid,
    required AvatarUploadReceipt receipt,
  }) async {
    if (expectedUid.trim().isEmpty || receipt.ownerUid != expectedUid) {
      throw ArgumentError('Cannot delete avatar belonging to another account.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKeyFor(expectedUid));
    _memoryCache.remove(expectedUid);
  }

  Future<void> clearAvatar(String expectedUid) async {
    if (expectedUid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKeyFor(expectedUid));
    _memoryCache.remove(expectedUid);
  }
}

final avatarRepositoryProvider = Provider<LocalAvatarRepository>((ref) {
  return LocalAvatarRepository();
});

/// Holds the active account's locally persisted custom [AvatarImage] (R06).
final accountCustomAvatarProvider =
    AsyncNotifierProvider.autoDispose<
      AccountCustomAvatarNotifier,
      AvatarImage?
    >(AccountCustomAvatarNotifier.new);

class AccountCustomAvatarNotifier extends AsyncNotifier<AvatarImage?> {
  @override
  Future<AvatarImage?> build() async {
    final session = ref.watch(accountSessionProvider);
    if (session == null || !session.isActive) return null;
    final repo = ref.watch(avatarRepositoryProvider);
    return repo.loadAvatar(session.uid);
  }

  Future<String?> pickAndSaveAvatar({
    required Uint8List bytes,
    String? declaredMimeType,
  }) async {
    final session = ref.read(accountSessionProvider);
    if (session == null || !session.isActive) {
      return 'Phiên đăng nhập không hợp lệ.';
    }
    try {
      final repo = ref.read(avatarRepositoryProvider);
      final saved = await repo.validateAndSaveAvatar(
        expectedUid: session.uid,
        rawBytes: bytes,
        declaredMimeType: declaredMimeType,
      );
      if (!session.isActive) return null;
      state = AsyncData(saved.image);
      return null;
    } on AvatarValidationFailure catch (error) {
      return error.message;
    } catch (_) {
      return 'Không thể cập nhật ảnh đại diện. Hãy thử lại.';
    }
  }

  Future<void> removeAvatar() async {
    final session = ref.read(accountSessionProvider);
    if (session == null || !session.isActive) return;
    final repo = ref.read(avatarRepositoryProvider);
    await repo.clearAvatar(session.uid);
    if (!session.isActive) return;
    state = const AsyncData(null);
  }
}
