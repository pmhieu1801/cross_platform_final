import 'dart:typed_data';

/// Encoded image and decoded dimensions, prepared by AvatarImageValidator.
/// A backend must independently validate uploads; this model is not authority.
class AvatarImage {
  AvatarImage({
    required Uint8List bytes,
    required this.contentType,
    required this.width,
    required this.height,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final String contentType;
  final int width;
  final int height;
}

/// Opaque backend receipt. Never derive a deletion target from an old photo URL.
class AvatarUploadReceipt {
  AvatarUploadReceipt({
    required this.ownerUid,
    required this.storageKey,
    required this.photoUrl,
  }) {
    if (ownerUid.isEmpty ||
        storageKey.isEmpty ||
        photoUrl.scheme != 'https' ||
        photoUrl.host.isEmpty ||
        photoUrl.userInfo.isNotEmpty) {
      throw ArgumentError('Avatar upload receipt is incomplete or invalid.');
    }
  }

  final String ownerUid;
  final String storageKey;
  // A URL may contain a private access token. Do not log receipts/URLs.
  final Uri photoUrl;
}

/// Backend contract only: storage and access policy are not selected on Spark.
/// No production implementation/provider is installed until owners approve it.
abstract interface class AvatarRepository {
  /// Must enforce authenticated ownership, type and size on the server.
  /// Upload alone must not change Auth.photoURL or replace the displayed avatar.
  Future<AvatarUploadReceipt> upload({
    required String expectedUid,
    required AvatarImage image,
  });

  /// Deletes only this backend-issued object belonging to expectedUid.
  /// Use for rollback if metadata fails; never delete another user's object or
  /// retry A's cleanup under B's credentials after an account switch.
  Future<void> deleteUploaded({
    required String expectedUid,
    required AvatarUploadReceipt receipt,
  });
}
