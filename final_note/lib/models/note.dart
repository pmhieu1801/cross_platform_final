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
  });

  final String id;
  final String title;
  final String content;
  final List<String> labels;
  final int colorIndex;
  final DateTime updatedAt;
  final bool isPinned;
  final DateTime? pinnedAt;

  Note copyWith({
    String? title,
    String? content,
    List<String>? labels,
    int? colorIndex,
    DateTime? updatedAt,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      labels: labels ?? this.labels,
      colorIndex: colorIndex ?? this.colorIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : pinnedAt ?? this.pinnedAt,
    );
  }
}

List<Note> createDemoNotes() {
  final now = DateTime.now();

  return [
    Note(
      id: 'note-1',
      title: 'Ideas for the weekend',
      content:
          'A few things I want to make time for: take the long trail by the lake, try that new coffee place, and finally start the book on my desk.',
      labels: const ['Personal', 'Ideas'],
      colorIndex: 0,
      updatedAt: now.subtract(const Duration(minutes: 18)),
      isPinned: true,
      pinnedAt: now.subtract(const Duration(days: 1)),
    ),
    Note(
      id: 'note-2',
      title: 'Project kickoff',
      content:
          'Align on the first milestone, share the design references, and leave space for questions before we wrap up.',
      labels: const ['Work'],
      colorIndex: 1,
      updatedAt: now.subtract(const Duration(hours: 2)),
      isPinned: true,
      pinnedAt: now.subtract(const Duration(hours: 10)),
    ),
    Note(
      id: 'note-3',
      title: 'A little reminder',
      content:
          'Small progress is still progress. Keep showing up, even when the plan needs to change.',
      labels: const ['Personal'],
      colorIndex: 2,
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    Note(
      id: 'note-4',
      title: 'Reading list',
      content:
          'Designing Data-Intensive Applications\nThe Creative Act\nWays of Being',
      labels: const ['Ideas', 'Learning'],
      colorIndex: 3,
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Note(
      id: 'note-5',
      title: 'Grocery list',
      content:
          'Oat milk, lemons, cherry tomatoes, fresh basil, pasta, and something sweet for later.',
      labels: const ['Personal'],
      colorIndex: 4,
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    Note(
      id: 'note-6',
      title: 'Things to explore',
      content:
          'Try a morning without notifications. Find a new walking route. Make something just for fun.',
      labels: const ['Ideas'],
      colorIndex: 5,
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
  ];
}
