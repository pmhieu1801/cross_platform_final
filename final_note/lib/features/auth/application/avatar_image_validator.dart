import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/avatar_repository.dart';

/// Implementation limits for review, not numbers required by the project PDF.
class AvatarValidationPolicy {
  const AvatarValidationPolicy({
    this.maxBytes = 2 * 1024 * 1024,
    this.maxDimension = 4096,
  }) : assert(maxBytes > 0),
       assert(maxDimension > 0);

  final int maxBytes;
  final int maxDimension;
}

class AvatarValidationFailure implements Exception {
  const AvatarValidationFailure(this.message);
  final String message;
}

/// No picker, file path, storage, Auth mutation or network access is involved.
class AvatarImageValidator {
  const AvatarImageValidator({this.policy = const AvatarValidationPolicy()});
  final AvatarValidationPolicy policy;

  Future<AvatarImage> validate(
    Uint8List bytes, {
    String? declaredMimeType,
  }) async {
    if (bytes.isEmpty) {
      throw const AvatarValidationFailure('Ảnh không có dữ liệu.');
    }
    if (bytes.lengthInBytes > policy.maxBytes) {
      throw const AvatarValidationFailure('Ảnh vượt quá dung lượng cho phép.');
    }
    // Own a stable copy before the first await: the picker/caller may reuse its
    // buffer. Later mutation must not change bytes that passed validation.
    final stableBytes = Uint8List.fromList(bytes);
    final contentType = _contentType(stableBytes);
    var declared = declaredMimeType?.split(';').first.trim().toLowerCase();
    if (declared == 'image/jpg') declared = 'image/jpeg';
    if (declared != null && declared.isNotEmpty && declared != contentType) {
      throw const AvatarValidationFailure(
        'Loại ảnh không khớp dữ liệu JPEG/PNG.',
      );
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(stableBytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Inspect encoded dimensions before allocating the decoded pixel image.
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > policy.maxDimension ||
          descriptor.height > policy.maxDimension) {
        throw const AvatarValidationFailure(
          'Kích thước ảnh vượt giới hạn cho phép.',
        );
      }
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      return AvatarImage(
        bytes: stableBytes,
        contentType: contentType,
        width: descriptor.width,
        height: descriptor.height,
      );
    } on AvatarValidationFailure {
      rethrow;
    } catch (_) {
      // Codec errors can include input details; expose only a fixed safe message.
      throw const AvatarValidationFailure(
        'Ảnh bị lỗi hoặc không giải mã được.',
      );
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Validates signature/size, then decodes with a capped target size (safe for
  /// large 4K/8K photos on Flutter Web) and re-encodes a compact square-ish PNG
  /// avatar so it always fits local storage quotas.
  Future<AvatarImage> normalizeForAvatar(
    Uint8List bytes, {
    String? declaredMimeType,
    int targetWidth = 384,
  }) async {
    if (bytes.isEmpty) {
      throw const AvatarValidationFailure('Ảnh không có dữ liệu.');
    }
    if (bytes.lengthInBytes > policy.maxBytes) {
      throw const AvatarValidationFailure('Ảnh vượt quá dung lượng cho phép.');
    }
    final stableBytes = Uint8List.fromList(bytes);
    // Throws for anything that is not a real PNG/JPEG signature.
    _contentType(stableBytes);

    ui.Codec? codec;
    ui.Image? decoded;
    try {
      codec = await ui.instantiateImageCodec(
        stableBytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const AvatarValidationFailure(
          'Ảnh bị lỗi hoặc không giải mã được.',
        );
      }
      return AvatarImage(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        contentType: 'image/png',
        width: decoded.width,
        height: decoded.height,
      );
    } on AvatarValidationFailure {
      rethrow;
    } catch (_) {
      throw const AvatarValidationFailure(
        'Ảnh bị lỗi hoặc không giải mã được.',
      );
    } finally {
      decoded?.dispose();
      codec?.dispose();
    }
  }

  String _contentType(Uint8List bytes) {
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= png.length &&
        Iterable<int>.generate(png.length).every((i) => bytes[i] == png[i])) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    throw const AvatarValidationFailure('Chỉ hỗ trợ ảnh JPEG hoặc PNG.');
  }
}
