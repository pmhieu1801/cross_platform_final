import 'package:flutter/material.dart';

/// Auth supplies only a URL. Choosing/uploading an avatar belongs to W2-05.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final uri = photoUrl == null ? null : Uri.tryParse(photoUrl!);
    // Never treat local paths or data URLs as persisted remote avatars.
    final remote = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    final fallback = Semantics(
      label: 'Default avatar',
      child: CircleAvatar(
        key: const Key('profile-default-avatar'),
        radius: 44,
        child: const Icon(Icons.person_rounded, size: 48),
      ),
    );
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
