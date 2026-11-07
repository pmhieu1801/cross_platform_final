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
  });

  final String id;
  final String name;
  final NoteAttachmentKind kind;
  final String localPath;
  final String mimeType;
  final DateTime? createdAt;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'localPath': localPath,
    'mimeType': mimeType,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'sizeBytes': sizeBytes,
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
        other.sizeBytes == sizeBytes;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, localPath, mimeType, createdAt, sizeBytes);
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
    this.attachments = const <NoteAttachment>[],
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
  final List<NoteAttachment> attachments;

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
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(),
  };

  factory Note.fromJson(Map<String, dynamic> json) {
    final labels =
        (json['labels'] as List?)?.map((label) => label.toString()).toList() ??
        const <String>[];
    final attachments =
        (json['attachments'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(NoteAttachment.fromJson)
            .toList() ??
        const <NoteAttachment>[];
    final statusValue = json['status']?.toString();

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
      attachments: attachments,
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
    List<NoteAttachment>? attachments,
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
      attachments: attachments ?? this.attachments,
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
