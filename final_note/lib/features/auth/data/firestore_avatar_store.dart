import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../application/avatar_image_validator.dart';
import '../domain/avatar_repository.dart';

/// Stores one private, bounded thumbnail per account on Firestore.
class FirestoreAvatarStore implements SyncedAvatarStore {
  FirestoreAvatarStore(this._firestore, this._auth);

  static const maxDimension = 256;
  static const _maxBytes = 400 * 1024;
  static const _validator = AvatarImageValidator(
    policy: AvatarValidationPolicy(
      maxBytes: _maxBytes,
      maxDimension: maxDimension,
    ),
  );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _ownedAvatar(String uid) {
    if (uid.isEmpty || _auth.currentUser?.uid != uid) {
      throw StateError('The avatar account is no longer signed in.');
    }
    return _firestore.collection('accountAvatars').doc(uid);
  }

  @override
  Future<({bool initialized, AvatarImage? image})> load(String uid) async {
    final snapshot = await _ownedAvatar(uid)
        .get(const GetOptions(source: Source.server));
    final record = snapshot.data();
    if (record == null) return (initialized: false, image: null);
    if (record['active'] == false) return (initialized: true, image: null);
    final bytes = record['png'];
    if (record['active'] != true || bytes is! Blob) {
      throw const AvatarValidationFailure('Ảnh đại diện đã lưu không hợp lệ.');
    }
    final image = await _validator.validate(
      bytes.bytes,
      declaredMimeType: 'image/png',
    );
    return (initialized: true, image: image);
  }

  @override
  Future<AvatarImage> save(String uid, AvatarImage image) async {
    if (image.contentType != 'image/png' ||
        image.width > maxDimension ||
        image.height > maxDimension ||
        image.bytes.lengthInBytes > _maxBytes) {
      throw const AvatarValidationFailure(
        'Không thể chuẩn bị ảnh đại diện để tải lên.',
      );
    }
    final avatar = _ownedAvatar(uid);
    // The Web SDK needs a native byte buffer for the JavaScript Blob bridge.
    final png = Blob(Uint8List.fromList(image.bytes));
    // Transactions fail offline instead of queuing a write that could apply
    // after the UI has already reported a failure or switched account.
    await _firestore.runTransaction<void>((transaction) async {
      transaction.set(avatar, {'active': true, 'png': png});
    });
    return image;
  }

  @override
  Future<void> reset(String uid) async {
    final avatar = _ownedAvatar(uid);
    await _firestore.runTransaction<void>((transaction) async {
      transaction.set(avatar, {'active': false});
    });
  }
}
