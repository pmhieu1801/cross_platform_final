import 'dart:typed_data';

import 'package:final_note/features/auth/application/avatar_image_validator.dart';
import 'package:final_note/features/auth/domain/avatar_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/avatar_test_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const validator = AvatarImageValidator();
  Matcher failsWith(String text) => throwsA(
    isA<AvatarValidationFailure>().having(
      (error) => error.message,
      'message',
      contains(text),
    ),
  );

  test('decodes PNG bytes and accepts normalized declared MIME', () async {
    final image = await validator.validate(
      avatarPng(),
      declaredMimeType: ' IMAGE/PNG; charset=binary ',
    );
    expect(image.contentType, 'image/png');
    expect(image.width, 16);
    expect(image.height, 16);
    expect(image.bytes, avatarPng());
  });

  test('decodes JPEG and normalizes the common image/jpg alias', () async {
    final image = await validator.validate(
      avatarJpeg(),
      declaredMimeType: 'image/jpg',
    );
    expect(image.contentType, 'image/jpeg');
    expect(image.width, 16);
    expect(image.height, 16);
  });

  test('empty data is rejected before decoding', () async {
    await expectLater(
      validator.validate(Uint8List(0)),
      failsWith('không có dữ liệu'),
    );
  });

  test(
    'default 2 MiB ceiling rejects oversized data before decoding',
    () async {
      expect(validator.policy.maxBytes, 2 * 1024 * 1024);
      await expectLater(
        validator.validate(Uint8List(validator.policy.maxBytes + 1)),
        failsWith('dung lượng'),
      );
    },
  );

  test(
    'exact byte boundary is accepted and one byte over is rejected',
    () async {
      final png = avatarPng();
      final exact = AvatarImageValidator(
        policy: AvatarValidationPolicy(maxBytes: png.length),
      );
      expect((await exact.validate(png)).contentType, 'image/png');
      final smaller = AvatarImageValidator(
        policy: AvatarValidationPolicy(maxBytes: png.length - 1),
      );
      await expectLater(smaller.validate(png), failsWith('dung lượng'));
    },
  );

  test('GIF, SVG and arbitrary bytes cannot masquerade as image/png', () async {
    for (final bytes in [
      Uint8List.fromList('GIF89a'.codeUnits),
      Uint8List.fromList('<svg></svg>'.codeUnits),
      Uint8List.fromList([1, 2, 3, 4]),
    ]) {
      await expectLater(
        validator.validate(bytes, declaredMimeType: 'image/png'),
        failsWith('JPEG hoặc PNG'),
      );
    }
  });

  test('declared MIME must match the detected image data', () async {
    await expectLater(
      validator.validate(avatarPng(), declaredMimeType: 'image/jpeg'),
      failsWith('không khớp'),
    );
    await expectLater(
      validator.validate(avatarJpeg(), declaredMimeType: 'application/pdf'),
      failsWith('không khớp'),
    );
  });

  test('valid signatures alone do not accept corrupt encoded images', () async {
    for (final bytes in [
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]),
      Uint8List.fromList([255, 216, 255, 0, 0]),
    ]) {
      await expectLater(
        validator.validate(bytes),
        failsWith('không giải mã được'),
      );
    }
  });

  test(
    'decoded dimension boundary is enforced before frame allocation',
    () async {
      expect(validator.policy.maxDimension, 4096);
      const exact = AvatarImageValidator(
        policy: AvatarValidationPolicy(maxDimension: 16),
      );
      expect((await exact.validate(avatarPng())).width, 16);
      const smaller = AvatarImageValidator(
        policy: AvatarValidationPolicy(maxDimension: 15),
      );
      await expectLater(
        smaller.validate(avatarJpeg()),
        failsWith('Kích thước'),
      );
    },
  );

  test(
    'caller mutation during decode cannot replace the validated payload',
    () async {
      final original = avatarPng();
      final result = validator.validate(original);
      original.fillRange(0, original.length, 0);
      final image = await result;
      expect(image.bytes, avatarPng());
      expect(() => image.bytes[0] = 0, throwsUnsupportedError);
    },
  );

  test(
    'upload receipts require opaque owner/object identity and safe HTTPS URL',
    () {
      final valid = AvatarUploadReceipt(
        ownerUid: 'uid-A',
        storageKey: 'opaque-key',
        photoUrl: Uri.parse('https://storage.example.test/avatar.png'),
      );
      expect(valid.ownerUid, 'uid-A');
      for (final url in [
        'http://storage.example.test/a',
        'local://a',
        'https://user:secret@storage.example.test/a',
      ]) {
        expect(
          () => AvatarUploadReceipt(
            ownerUid: 'uid-A',
            storageKey: 'opaque-key',
            photoUrl: Uri.parse(url),
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => AvatarUploadReceipt(
          ownerUid: '',
          storageKey: 'opaque-key',
          photoUrl: valid.photoUrl,
        ),
        throwsArgumentError,
      );
      expect(
        () => AvatarUploadReceipt(
          ownerUid: 'uid-A',
          storageKey: '',
          photoUrl: valid.photoUrl,
        ),
        throwsArgumentError,
      );
    },
  );
}
