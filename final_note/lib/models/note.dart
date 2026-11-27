enum NoteStatus {
  normal,
  idea,
  work,
  personal,
  important,
  archived;

  String get label {
    switch (this) {
      case NoteStatus.normal:
        return 'Normal';
      case NoteStatus.idea:
        return 'Idea';
      case NoteStatus.work:
        return 'Work';
      case NoteStatus.personal:
        return 'Personal';
      case NoteStatus.important:
        return 'Important';
      case NoteStatus.archived:
        return 'Archived';
    }
  }
}

enum NoteSyncStatus {
  pending,
  synced,
  failed;

  String get label {
    switch (this) {
      case NoteSyncStatus.pending:
        return 'Pending sync';
      case NoteSyncStatus.synced:
        return 'Synced';
      case NoteSyncStatus.failed:
        return 'Sync failed';
    }
  }
}

enum NoteAttachmentKind {
  image,
  video,
  file;

  String get label {
    switch (this) {
      case NoteAttachmentKind.image:
        return 'Image';
      case NoteAttachmentKind.video:
        return 'Video';
      case NoteAttachmentKind.file:
        return 'File';
    }
  }
}

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.name,
    required this.kind,
    required this.localPath,
    this.mimeType = 'application/octet-stream',
    this.createdAt,
    this.sizeBytes = 0,
    this.ownerUid,
    this.previewBase64,
  });

  final String id;
  final String name;
  final NoteAttachmentKind kind;
  final String localPath;
  final String mimeType;
  final DateTime? createdAt;
  final int sizeBytes;
  final String? ownerUid;
  final String? previewBase64;

  NoteAttachment copyWith({
    String? id,
    String? name,
    NoteAttachmentKind? kind,
    String? localPath,
    String? mimeType,
    DateTime? createdAt,
    int? sizeBytes,
    String? ownerUid,
    String? previewBase64,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      ownerUid: ownerUid ?? this.ownerUid,
      previewBase64: previewBase64 ?? this.previewBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'localPath': localPath,
    'mimeType': mimeType,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'sizeBytes': sizeBytes,
    if (ownerUid != null) 'ownerUid': ownerUid,
    if (previewBase64 != null) 'previewBase64': previewBase64,
  };

  factory NoteAttachment.fromJson(Map<String, dynamic> json) {
    final kindValue = json['kind']?.toString();
    return NoteAttachment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Attachment',
      kind: NoteAttachmentKind.values.firstWhere(
        (value) => value.name == kindValue,
        orElse: () => NoteAttachmentKind.file,
      ),
      localPath: json['localPath']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString()),
      sizeBytes: int.tryParse(json['sizeBytes']?.toString() ?? '0') ?? 0,
      ownerUid: json['ownerUid']?.toString(),
      previewBase64: json['previewBase64']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteAttachment &&
        other.id == id &&
        other.name == name &&
        other.kind == kind &&
        other.localPath == localPath &&
        other.mimeType == mimeType &&
        other.createdAt == createdAt &&
        other.sizeBytes == sizeBytes &&
        other.ownerUid == ownerUid &&
        other.previewBase64 == previewBase64;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    localPath,
    mimeType,
    createdAt,
    sizeBytes,
    ownerUid,
    previewBase64,
  );
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.labels,
    required this.colorIndex,
    required this.updatedAt,
    this.isPinned = false,
    this.pinnedAt,
    this.ownerUid,
    this.status = NoteStatus.normal,
    this.syncStatus = NoteSyncStatus.pending,
    this.attachments = const <NoteAttachment>[],
    this.passwordHash,
    this.passwordSalt,
  });

  final String id;
  final String title;
  final String content;
  final List<String> labels;
  final int colorIndex;
  final DateTime updatedAt;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? ownerUid;
  final NoteStatus status;
  final NoteSyncStatus syncStatus;
  final List<NoteAttachment> attachments;
  final String? passwordHash;
  final String? passwordSalt;

  /// Whether this note is protected by an individual note password (R23).
  bool get isPasswordProtected =>
      passwordHash != null &&
      passwordHash!.isNotEmpty &&
      passwordSalt != null &&
      passwordSalt!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'labels': labels,
    'colorIndex': colorIndex,
    'updatedAt': updatedAt.toIso8601String(),
    'isPinned': isPinned,
    'pinnedAt': pinnedAt?.toIso8601String(),
    'ownerUid': ownerUid,
    'status': status.name,
    'syncStatus': syncStatus.name,
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
    if (passwordHash != null) 'passwordHash': passwordHash,
    if (passwordSalt != null) 'passwordSalt': passwordSalt,
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    final labels =
        (json['labels'] as List?)?.map((label) => label.toString()).toList() ??
        const <String>[];
    final attachments =
        (json['attachments'] as List?)
            ?.whereType<Map>()
            .map(
              (item) =>
                  NoteAttachment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList() ??
        const <NoteAttachment>[];
    final statusValue = json['status']?.toString();
    final syncStatusValue = json['syncStatus']?.toString();

    return Note(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      labels: labels,
      colorIndex: int.tryParse(json['colorIndex']?.toString() ?? '0') ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      isPinned: json['isPinned'] == true,
      pinnedAt: json['pinnedAt'] == null
          ? null
          : DateTime.tryParse(json['pinnedAt'].toString()),
      ownerUid: json['ownerUid']?.toString(),
      status: NoteStatus.values.firstWhere(
        (value) => value.name == statusValue,
        orElse: () => NoteStatus.normal,
      ),
      syncStatus: NoteSyncStatus.values.firstWhere(
        (value) => value.name == syncStatusValue,
        orElse: () => NoteSyncStatus.pending,
      ),
      attachments: attachments,
      passwordHash: json['passwordHash']?.toString(),
      passwordSalt: json['passwordSalt']?.toString(),
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? labels,
    int? colorIndex,
    DateTime? updatedAt,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
    String? ownerUid,
    NoteStatus? status,
    NoteSyncStatus? syncStatus,
    List<NoteAttachment>? attachments,
    String? passwordHash,
    String? passwordSalt,
    bool clearPasswordProtection = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      labels: labels ?? this.labels,
      colorIndex: colorIndex ?? this.colorIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : pinnedAt ?? this.pinnedAt,
      ownerUid: ownerUid ?? this.ownerUid,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      attachments: attachments ?? this.attachments,
      passwordHash: clearPasswordProtection
          ? null
          : (passwordHash ?? this.passwordHash),
      passwordSalt: clearPasswordProtection
          ? null
          : (passwordSalt ?? this.passwordSalt),
    );
  }
}

/// Deterministic note ordering (R17):
/// 1. Pinned notes come before unpinned notes.
/// 2. Among pinned notes, order by [Note.pinnedAt] (falling back to
///    [Note.updatedAt]) descending.
/// 3. Otherwise order by [Note.updatedAt] descending, breaking ties by [Note.id].
List<Note> sortNotes(Iterable<Note> source) {
  final list = List<Note>.of(source);
  list.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    if (a.isPinned && b.isPinned) {
      final pinnedOrder = (b.pinnedAt ?? b.updatedAt).compareTo(
        a.pinnedAt ?? a.updatedAt,
      );
      if (pinnedOrder != 0) return pinnedOrder;
    }
    final updatedOrder = b.updatedAt.compareTo(a.updatedAt);
    if (updatedOrder != 0) return updatedOrder;
    return a.id.compareTo(b.id);
  });
  return list;
}

List<Note> createDemoNotes({String? ownerUid}) {
  final now = DateTime.now();

  return [
    Note(
      id: 'note-1',
      title: 'Ideas for the weekend',
      content: 'A few things I want to make time for: take the long trail by the lake, try that new coffee place, and finally start the book on my desk.',
      labels: const ['Personal', 'Ideas'],
      colorIndex: 0,
      updatedAt: now.subtract(const Duration(minutes: 18)),
      isPinned: true,
      pinnedAt: now.subtract(const Duration(days: 1)),
      ownerUid: ownerUid,
      status: NoteStatus.important,
    ),
    Note(
      id: 'note-2',
      title: 'Project kickoff',
      content: 'Align on the first milestone, share the design references, and leave space for questions before we wrap up.',
      labels: const ['Work'],
      colorIndex: 1,
      updatedAt: now.subtract(const Duration(hours: 2)),
      isPinned: true,
      pinnedAt: now.subtract(const Duration(hours: 10)),
      ownerUid: ownerUid,
      status: NoteStatus.work,
    ),
    Note(
      id: 'note-3',
      title: 'A little reminder',
      content: 'Small progress is still progress. Keep showing up, even when the plan needs to change.',
      labels: const ['Personal'],
      colorIndex: 2,
      updatedAt: now.subtract(const Duration(days: 1)),
      ownerUid: ownerUid,
      status: NoteStatus.personal,
    ),
    Note(
      id: 'note-4',
      title: 'Reading list',
      content: 'Designing Data-Intensive Applications\nThe Creative Act\nWays of Being',
      labels: const ['Ideas', 'Learning'],
      colorIndex: 3,
      updatedAt: now.subtract(const Duration(days: 2)),
      ownerUid: ownerUid,
      status: NoteStatus.idea,
    ),
    Note(
      id: 'note-5',
      title: 'Grocery list',
      content: 'Oat milk, lemons, cherry tomatoes, fresh basil, pasta, and something sweet for later.',
      labels: const ['Personal'],
      colorIndex: 4,
      updatedAt: now.subtract(const Duration(days: 3)),
      ownerUid: ownerUid,
      status: NoteStatus.personal,
    ),
    Note(
      id: 'note-6',
      title: 'Things to explore',
      content: 'Try a morning without notifications. Find a new walking route. Make something just for fun.',
      labels: const ['Ideas'],
      colorIndex: 5,
      updatedAt: now.subtract(const Duration(days: 4)),
      ownerUid: ownerUid,
      status: NoteStatus.idea,
    ),
  ];
}
