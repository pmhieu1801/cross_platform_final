import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Displays the user's profile avatar from validated local bytes, an HTTPS
/// `photoUrl`, or a safe default fallback (R05, R06).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photoUrl, this.imageBytes});
  final String? photoUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final fallback = Semantics(
      label: 'Default avatar',
      child: CircleAvatar(
        key: const Key('profile-default-avatar'),
        radius: 44,
        child: const Icon(Icons.person_rounded, size: 48),
      ),
    );
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          imageBytes!,
          key: const Key('profile-custom-avatar'),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          semanticLabel: 'Profile avatar',
          errorBuilder: (context, error, stack) => fallback,
        ),
      );
    }
    final uri = photoUrl == null ? null : Uri.tryParse(photoUrl!);
    // Never treat local paths or data URLs as persisted remote avatars.
    final remote = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    if (!remote) return fallback;
    return ClipOval(
      child: Image.network(
        photoUrl!,
        key: ValueKey(photoUrl),
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        semanticLabel: 'Profile avatar',
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}
