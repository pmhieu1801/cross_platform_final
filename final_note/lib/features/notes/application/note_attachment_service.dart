import 'dart:convert';
import 'dart:typed_data';

import '../../../models/note.dart';

/// Maximum allowed size for image and general document attachments (5 MiB).
const int kMaxImageOrFileAttachmentBytes = 5 * 1024 * 1024;

/// Maximum allowed size for video attachments (15 MiB).
const int kMaxVideoAttachmentBytes = 15 * 1024 * 1024;

/// Maximum inline base64 preview payload stored directly in local metadata (512 KiB).
const int kMaxInlinePreviewBytes = 512 * 1024;

/// Raw file candidate returned by a platform picker or attachment dialog.
class PickedAttachmentCandidate {
  const PickedAttachmentCandidate({
    required this.name,
    required this.kind,
    required this.sizeBytes,
    this.localPath = '',
    this.mimeType,
    this.bytes,
  });

  final String name;
  final NoteAttachmentKind kind;
  final int sizeBytes;
  final String localPath;
  final String? mimeType;
  final Uint8List? bytes;
}

/// Outcome of an attachment picker invocation, covering selection, cancellation,
/// and permission-denied states (R15, R16).
class AttachmentPickOutcome {
  const AttachmentPickOutcome._({
    this.candidates = const <PickedAttachmentCandidate>[],
    this.cancelled = false,
    this.permissionDenied = false,
    this.errorMessage,
  });

  const AttachmentPickOutcome.picked(List<PickedAttachmentCandidate> candidates)
    : this._(candidates: candidates);

  const AttachmentPickOutcome.cancelled() : this._(cancelled: true);

  const AttachmentPickOutcome.permissionDenied([String? message])
    : this._(
        permissionDenied: true,
        errorMessage: message ?? 'Permission to access files or media was denied. Please grant access and try again.',
      );

  const AttachmentPickOutcome.failure(String message)
    : this._(errorMessage: message);

  final List<PickedAttachmentCandidate> candidates;
  final bool cancelled;
  final bool permissionDenied;
  final String? errorMessage;
}

/// Validation result for a [PickedAttachmentCandidate].
class AttachmentValidationResult {
  const AttachmentValidationResult._({this.attachment, this.error});

  const AttachmentValidationResult.valid(NoteAttachment attachment)
    : this._(attachment: attachment);

  const AttachmentValidationResult.invalid(String error) : this._(error: error);

  final NoteAttachment? attachment;
  final String? error;
  bool get isValid => attachment != null && error == null;
}

/// Validates attachment file types, extensions, sizes, and account authorization
/// for R15 (images/videos) and R16 (general files).
abstract final class NoteAttachmentValidator {
  static const Set<String> allowedImageExtensions = <String>{
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  };

  static const Set<String> allowedVideoExtensions = <String>{
    'mp4',
    'webm',
    'mov',
    'm4v',
    'avi',
    'mkv',
  };

  static const Set<String> allowedFileExtensions = <String>{
    'pdf',
    'txt',
    'md',
    'csv',
    'json',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'zip',
    'rtf',
  };

  static const Set<String> blockedExecutableExtensions = <String>{
    'exe',
    'bat',
    'cmd',
    'sh',
    'msi',
    'apk',
    'app',
    'dmg',
    'com',
    'scr',
  };

  static String extractExtension(String fileName) {
    final trimmed = fileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == trimmed.length - 1) return '';
    return trimmed.substring(dotIndex + 1).toLowerCase();
  }

  static String inferMimeType(NoteAttachmentKind kind, String extension) {
    switch (kind) {
      case NoteAttachmentKind.image:
        return switch (extension) {
          'png' => 'image/png',
          'jpg' || 'jpeg' => 'image/jpeg',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          'bmp' => 'image/bmp',
          _ => 'image/*',
        };
      case NoteAttachmentKind.video:
        return switch (extension) {
          'mp4' || 'm4v' => 'video/mp4',
          'webm' => 'video/webm',
          'mov' => 'video/quicktime',
          'avi' => 'video/x-msvideo',
          'mkv' => 'video/x-matroska',
          _ => 'video/*',
        };
      case NoteAttachmentKind.file:
        return switch (extension) {
          'pdf' => 'application/pdf',
          'txt' => 'text/plain',
          'md' => 'text/markdown',
          'csv' => 'text/csv',
          'json' => 'application/json',
          'doc' => 'application/msword',
          'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'xls' => 'application/vnd.ms-excel',
          'xlsx' =>
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'ppt' => 'application/vnd.ms-powerpoint',
          'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'zip' => 'application/zip',
          'rtf' => 'application/rtf',
          _ => 'application/octet-stream',
        };
    }
  }

  /// Validates [candidate] and builds an account-scoped [NoteAttachment].
  static AttachmentValidationResult validate(
    PickedAttachmentCandidate candidate, {
    String? ownerUid,
    DateTime? now,
  }) {
    final cleanName = candidate.name.trim();
    if (cleanName.isEmpty) {
      return const AttachmentValidationResult.invalid(
        'File name cannot be empty.',
      );
    }

    final ext = extractExtension(cleanName);
    if (ext.isEmpty) {
      return const AttachmentValidationResult.invalid(
        'File must include a valid extension (e.g. .png, .mp4, .pdf).',
      );
    }

    if (blockedExecutableExtensions.contains(ext)) {
      return AttachmentValidationResult.invalid(
        'Executable files (.$ext) are not permitted for security reasons.',
      );
    }

    final effectiveSize = candidate.bytes?.length ?? candidate.sizeBytes;
    if (effectiveSize <= 0) {
      return const AttachmentValidationResult.invalid(
        'Selected file is empty (0 bytes).',
      );
    }

    switch (candidate.kind) {
      case NoteAttachmentKind.image:
        if (!allowedImageExtensions.contains(ext)) {
          return AttachmentValidationResult.invalid(
            'Unsupported image format (.$ext). Allowed: PNG, JPG, GIF, WEBP, BMP.',
          );
        }
        final declaredMime = candidate.mimeType?.trim().toLowerCase() ?? '';
        if (declaredMime.isNotEmpty && !declaredMime.startsWith('image/')) {
          return AttachmentValidationResult.invalid(
            'MIME type "$declaredMime" does not match an image attachment.',
          );
        }
        if (effectiveSize > kMaxImageOrFileAttachmentBytes) {
          return AttachmentValidationResult.invalid(
            'Image exceeds the 5 MB size limit (${formatBytes(effectiveSize)}).',
          );
        }
      case NoteAttachmentKind.video:
        if (!allowedVideoExtensions.contains(ext)) {
          return AttachmentValidationResult.invalid(
            'Unsupported video format (.$ext). Allowed: MP4, WEBM, MOV, M4V, AVI.',
          );
        }
        final declaredMime = candidate.mimeType?.trim().toLowerCase() ?? '';
        if (declaredMime.isNotEmpty && !declaredMime.startsWith('video/')) {
          return AttachmentValidationResult.invalid(
            'MIME type "$declaredMime" does not match a video attachment.',
          );
        }
        if (effectiveSize > kMaxVideoAttachmentBytes) {
          return AttachmentValidationResult.invalid(
            'Video exceeds the 15 MB size limit (${formatBytes(effectiveSize)}).',
          );
        }
      case NoteAttachmentKind.file:
        if (!allowedFileExtensions.contains(ext) &&
            !allowedImageExtensions.contains(ext) &&
            !allowedVideoExtensions.contains(ext)) {
          return AttachmentValidationResult.invalid(
            'Unsupported file format (.$ext). Allowed: PDF, TXT, MD, CSV, JSON, Office docs, ZIP.',
          );
        }
        if (effectiveSize > kMaxImageOrFileAttachmentBytes) {
          return AttachmentValidationResult.invalid(
            'File exceeds the 5 MB size limit (${formatBytes(effectiveSize)}).',
          );
        }
    }

    final timestamp = now ?? DateTime.now();
    final resolvedMime =
        (candidate.mimeType != null && candidate.mimeType!.trim().isNotEmpty)
        ? candidate.mimeType!.trim()
        : inferMimeType(candidate.kind, ext);
    final rawBytes = candidate.bytes;
    final inlineBase64 =
        (rawBytes != null &&
            rawBytes.isNotEmpty &&
            rawBytes.length <= kMaxInlinePreviewBytes)
        ? base64Encode(rawBytes)
        : null;
    final resolvedPath = candidate.localPath.trim().isNotEmpty
        ? candidate.localPath.trim()
        : 'local://${candidate.kind.name}/${timestamp.microsecondsSinceEpoch}/$cleanName';

    return AttachmentValidationResult.valid(
      NoteAttachment(
        id: 'attachment-${timestamp.microsecondsSinceEpoch}-${cleanName.hashCode.abs()}',
        name: cleanName,
        kind: candidate.kind,
        localPath: resolvedPath,
        mimeType: resolvedMime,
        createdAt: timestamp,
        sizeBytes: effectiveSize,
        ownerUid: ownerUid,
        previewBase64: inlineBase64,
      ),
    );
  }

  /// Checks whether [viewerUid] is authorized to access [attachment] on [note].
  static bool canAccessAttachment({
    required Note note,
    required NoteAttachment attachment,
    required String? viewerUid,
  }) {
    final noteOwner = note.ownerUid;
    final attachmentOwner = attachment.ownerUid ?? noteOwner;
    if (noteOwner == null && attachmentOwner == null) {
      // Standalone demo mode without authenticated UID.
      return true;
    }
    if (viewerUid == null || viewerUid.trim().isEmpty) {
      return false;
    }
    if (noteOwner != null && noteOwner != viewerUid) {
      return false;
    }
    if (attachmentOwner != null && attachmentOwner != viewerUid) {
      return false;
    }
    return true;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
