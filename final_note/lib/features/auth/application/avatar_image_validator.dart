import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as image;

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
  static const localAvatarDimension = 384;

  final AvatarValidationPolicy policy;

  Future<AvatarImage> validate(Uint8List bytes, {String? declaredMimeType}) =>
      _decode(bytes, declaredMimeType: declaredMimeType);

  /// Keeps the original aspect ratio and bounds both thumbnail dimensions.
  Future<AvatarImage> normalizeForAvatar(
    Uint8List bytes, {
    String? declaredMimeType,
    int maxDimension = localAvatarDimension,
  }) => _decode(
    bytes,
    declaredMimeType: declaredMimeType,
    thumbnailDimension: maxDimension,
  );

  Future<AvatarImage> _decode(
    Uint8List bytes, {
    String? declaredMimeType,
    int? thumbnailDimension,
  }) async {
    if (thumbnailDimension != null && thumbnailDimension <= 0) {
      throw ArgumentError.value(thumbnailDimension, 'maxDimension');
    }
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

    ui.Codec? codec;
    ui.Image? decoded;
    try {
      // Flutter Web does not expose encoded ImageDescriptor dimensions.
      // Inspect the headers before asking Flutter to allocate a decoded frame.
      final decoder = contentType == 'image/png'
          ? image.PngDecoder(maxPixels: 0)
          : image.JpegDecoder(maxPixels: 0);
      final dimensions = decoder.startDecode(stableBytes);
      if (dimensions == null) {
        throw const AvatarValidationFailure(
          'Ảnh bị lỗi hoặc không giải mã được.',
        );
      }
      if (dimensions.width <= 0 ||
          dimensions.height <= 0 ||
          dimensions.width > policy.maxDimension ||
          dimensions.height > policy.maxDimension) {
        throw const AvatarValidationFailure(
          'Kích thước ảnh vượt giới hạn cho phép.',
        );
      }
      if (thumbnailDimension != null &&
          (dimensions.width > thumbnailDimension ||
              dimensions.height > thumbnailDimension)) {
        codec = await ui.instantiateImageCodecWithSize(
          await ui.ImmutableBuffer.fromUint8List(stableBytes),
          getTargetSize: (width, height) {
            final largestSide = width >= height ? width : height;
            if (largestSide <= thumbnailDimension) {
              return const ui.TargetImageSize();
            }
            return ui.TargetImageSize(
              width: (width * thumbnailDimension / largestSide).ceil(),
              height: (height * thumbnailDimension / largestSide).ceil(),
            );
          },
        );
      } else {
        codec = await ui.instantiateImageCodec(stableBytes);
      }
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      if (thumbnailDimension != null) {
        final png = await decoded.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw const AvatarValidationFailure(
            'Không thể chuẩn bị ảnh đại diện để tải lên.',
          );
        }
        return AvatarImage(
          bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          contentType: 'image/png',
          width: decoded.width,
          height: decoded.height,
        );
      }
      return AvatarImage(
        bytes: stableBytes,
        contentType: contentType,
        width: decoded.width,
        height: decoded.height,
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
