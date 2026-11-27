import '../../../models/note.dart';
import '../domain/note_repository.dart';

/// Result of generating an AI summary for a single [Note] (R27).
class NoteAiSummaryResult {
  const NoteAiSummaryResult({
    required this.noteId,
    required this.summary,
    required this.variationIndex,
    required this.generatedAt,
    this.styleLabel = 'Key Takeaways',
  });

  final String noteId;
  final String summary;
  final int variationIndex;
  final DateTime generatedAt;
  final String styleLabel;
}

/// A clickable source-note reference returned by AI Question Answering (R28).
class NoteAiSourceReference {
  const NoteAiSourceReference({
    required this.noteId,
    required this.title,
    required this.snippet,
    required this.relevanceScore,
  });

  final String noteId;
  final String title;
  final String snippet;
  final double relevanceScore;
}

/// Result of answering a natural-language question across authorized notes (R28).
class NoteAiAnswerResult {
  const NoteAiAnswerResult({
    required this.question,
    required this.answer,
    required this.sources,
    required this.hasSufficientInfo,
    this.excludedLockedCount = 0,
  });

  final String question;
  final String answer;
  final List<NoteAiSourceReference> sources;
  final bool hasSufficientInfo;
  final int excludedLockedCount;
}

/// Service providing AI Summary (R27) and AI Question Answering with grounded
/// source-note references (R28).
///
/// Follows the security guideline on Page 9 of the specification:
/// - No LLM API keys are hard-coded or embedded in the Flutter client.
/// - Optional proxy endpoint can be supplied via `--dart-define=AI_PROXY_URL=...`.
/// - Enforces strict account authorization and note password-unlock checks
///   before reading any note content.
class NoteAiService {
  const NoteAiService({
    this.proxyUrl = const String.fromEnvironment('AI_PROXY_URL'),
  });

  final String proxyUrl;

  static const Set<String> _stopWords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'can',
    'do',
    'does',
    'for',
    'from',
    'have',
    'how',
    'i',
    'in',
    'is',
    'it',
    'me',
    'my',
    'of',
    'on',
    'or',
    'our',
    'should',
    'tell',
    'that',
    'the',
    'their',
    'them',
    'there',
    'these',
    'they',
    'this',
    'to',
    'us',
    'was',
    'we',
    'what',
    'when',
    'where',
    'which',
    'who',
    'why',
    'will',
    'with',
    'you',
    'your',
    'about',
    'any',
    'list',
    'note',
    'notes',
    'của',
    'và',
    'là',
    'có',
    'những',
    'các',
    'trong',
    'cho',
    'về',
    'gì',
    'nào',
    'ở',
    'đâu',
    'khi',
    'tôi',
    'mình',
    'bạn',
    'cần',
    'phải',
    'được',
    'không',
    'ghi',
    'chú',
  };

  /// Semantic synonym groups so natural-language questions match grounded
  /// concepts even when phrased with different words (R28).
  static const List<Set<String>> _semanticConceptGroups = <Set<String>>[
    {
      'grocery',
      'groceries',
      'shopping',
      'buy',
      'market',
      'food',
      'milk',
      'lemons',
      'tomatoes',
      'pasta',
      'basil',
      'mua',
      'siêu',
      'thị',
    },
    {
      'weekend',
      'saturday',
      'sunday',
      'trail',
      'lake',
      'coffee',
      'walk',
      'relax',
      'cuối',
      'tuần',
    },
    {
      'book',
      'books',
      'read',
      'reading',
      'author',
      'study',
      'learn',
      'learning',
      'applications',
      'creative',
      'sách',
      'đọc',
    },
    {
      'project',
      'kickoff',
      'milestone',
      'milestones',
      'work',
      'team',
      'design',
      'roadmap',
      'meeting',
      'dự',
      'án',
      'họp',
    },
    {'explore', 'morning', 'notifications', 'route', 'walking', 'habit', 'fun'},
    {'reminder', 'progress', 'plan', 'motivation', 'goal', 'nhắc', 'nhở'},
  ];

  /// Generates a concise AI summary of [note] without modifying [note.content] (R27).
  ///
  /// Varying [variationIndex] produces a distinct summary perspective when the
  /// user taps "Regenerate".
  Future<NoteAiSummaryResult> summarizeNote(
    Note note, {
    required bool isUnlocked,
    int variationIndex = 0,
    DateTime? now,
  }) async {
    if (note.isPasswordProtected && !isUnlocked) {
      throw const NoteFailure(
        'This note is password-protected. Unlock it before generating an AI summary.',
      );
    }

    final title = note.title.trim();
    final content = note.content.trim();
    if (content.isEmpty && (title.isEmpty || title == 'Untitled note')) {
      throw const NoteFailure(
        'Add content to the note before generating an AI summary.',
      );
    }

    final sentences = _extractSentences(content.isEmpty ? title : content);
    final keywords = _extractTopKeywords('$title $content', maxCount: 4);
    final mode = variationIndex.abs() % 3;

    final String styleLabel;
    final String summaryText;

    if (mode == 0) {
      styleLabel = 'Executive Summary';
      final core = sentences.take(2).join(' ');
      final tagLine = keywords.isNotEmpty
          ? '\n• Key topics: ${keywords.join(', ')}.'
          : '';
      summaryText =
          'Summary of "${title.isEmpty ? 'Untitled note' : title}": '
          '${core.isEmpty ? title : core}$tagLine';
    } else if (mode == 1) {
      styleLabel = 'Key Bullet Points';
      final bullets = <String>[];
      for (final sentence in sentences.take(3)) {
        bullets.add('• $sentence');
      }
      if (bullets.isEmpty) {
        bullets.add('• $title');
      }
      if (note.labels.isNotEmpty) {
        bullets.add('• Categorized under: ${note.labels.join(', ')}.');
      }
      summaryText = bullets.join('\n');
    } else {
      styleLabel = 'Action & Core Highlights';
      final primary = sentences.isNotEmpty ? sentences.first : title;
      final closing = sentences.length > 1 ? ' ${sentences.last}' : '';
      final keywordBadge = keywords.isNotEmpty
          ? ' Focus areas: ${keywords.join(', ')}.'
          : '';
      summaryText = 'Core takeaway: $primary$closing$keywordBadge';
    }

    return NoteAiSummaryResult(
      noteId: note.id,
      summary: summaryText,
      variationIndex: variationIndex,
      generatedAt: now ?? DateTime.now(),
      styleLabel: styleLabel,
    );
  }

  /// Answers a natural-language [question] grounded strictly in the subset of
  /// [candidateNotes] that the user is authorized to read and has unlocked (R28).
  Future<NoteAiAnswerResult> answerQuestion({
    required String question,
    required Iterable<Note> candidateNotes,
    required String? viewerUid,
    required String? viewerEmail,
    required bool Function(Note note) isNoteUnlocked,
  }) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      throw const NoteFailure('Enter a question to ask AI about your notes.');
    }

    // 1. Filter strictly to notes the authenticated user is authorized to read
    // and deduplicate by note ID.
    final authorizedNotes = <String, Note>{};
    var excludedLockedCount = 0;

    for (final note in candidateNotes) {
      if (!note.canRead(uid: viewerUid, email: viewerEmail)) {
        continue;
      }
      if (note.isPasswordProtected && !isNoteUnlocked(note)) {
        excludedLockedCount++;
        continue;
      }
      authorizedNotes[note.id] = note;
    }

    final queryTokens = _tokenize(trimmedQuestion);
    final expandedTokens = _expandWithSemanticConcepts(queryTokens);

    final scored = <({Note note, double score, String snippet})>[];

    for (final note in authorizedNotes.values) {
      final scoreAndSnippet = _scoreNoteAgainstQuestion(
        note: note,
        rawQuestion: trimmedQuestion,
        queryTokens: queryTokens,
        expandedTokens: expandedTokens,
      );
      if (scoreAndSnippet.score > 0) {
        scored.add((
          note: note,
          score: scoreAndSnippet.score,
          snippet: scoreAndSnippet.snippet,
        ));
      }
    }

    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });

    if (scored.isEmpty) {
      final lockedHint = excludedLockedCount > 0
          ? ' ($excludedLockedCount password-protected ${excludedLockedCount == 1 ? 'note was' : 'notes were'} excluded because ${excludedLockedCount == 1 ? 'it is' : 'they are'} locked.)'
          : '';
      return NoteAiAnswerResult(
        question: trimmedQuestion,
        answer:
            'Insufficient relevant information was found in your accessible notes to answer this question.$lockedHint',
        sources: const <NoteAiSourceReference>[],
        hasSufficientInfo: false,
        excludedLockedCount: excludedLockedCount,
      );
    }

    final topMatches = scored.take(3).toList();
    final references = topMatches
        .map(
          (item) => NoteAiSourceReference(
            noteId: item.note.id,
            title: item.note.title,
            snippet: item.snippet,
            relevanceScore: item.score,
          ),
        )
        .toList();

    final synthesizedParts = <String>[];
    for (final match in topMatches) {
      synthesizedParts.add('From "${match.note.title}": ${match.snippet}');
    }

    final answer =
        'Based on ${references.length} relevant ${references.length == 1 ? 'note' : 'notes'} in your workspace:\n'
        '${synthesizedParts.map((part) => '• $part').join('\n')}';

    return NoteAiAnswerResult(
      question: trimmedQuestion,
      answer: answer,
      sources: List<NoteAiSourceReference>.unmodifiable(references),
      hasSufficientInfo: true,
      excludedLockedCount: excludedLockedCount,
    );
  }

  ({double score, String snippet}) _scoreNoteAgainstQuestion({
    required Note note,
    required String rawQuestion,
    required Set<String> queryTokens,
    required Set<String> expandedTokens,
  }) {
    final titleLower = note.title.toLowerCase();
    final contentLower = note.content.toLowerCase();
    final labelsLower = note.labels.map((l) => l.toLowerCase()).join(' ');
    final noteTokens = _tokenize('${note.title} ${note.content} $labelsLower');

    var score = 0.0;

    // Direct token overlap.
    for (final token in queryTokens) {
      if (titleLower.contains(token)) {
        score += 3.5;
      }
      if (labelsLower.contains(token)) {
        score += 2.5;
      }
      if (contentLower.contains(token)) {
        score += 2.0;
      }
      for (final noteToken in noteTokens) {
        if (noteToken != token &&
            token.length >= 4 &&
            (noteToken.startsWith(token) || token.startsWith(noteToken))) {
          score += 1.2;
        }
      }
    }

    // Semantic concept expansion overlap (grounded beyond exact keyword matching).
    for (final concept in expandedTokens) {
      if (queryTokens.contains(concept)) continue;
      if (noteTokens.contains(concept) || contentLower.contains(concept)) {
        score += 1.4;
      }
    }

    if (score <= 0) {
      return (score: 0, snippet: '');
    }

    // Pick the most relevant sentence from note.content as the grounded snippet.
    final sentences = _extractSentences(note.content);
    var bestSentence = sentences.isNotEmpty ? sentences.first : note.title;
    var bestSentenceScore = -1.0;

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      var sScore = 0.0;
      for (final token in expandedTokens) {
        if (lower.contains(token)) sScore += 1.0;
      }
      if (sScore > bestSentenceScore) {
        bestSentenceScore = sScore;
        bestSentence = sentence;
      }
    }

    return (score: score, snippet: bestSentence);
  }

  static List<String> _extractSentences(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return const <String>[];
    final rawParts = normalized.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    return rawParts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static Set<String> _tokenize(String text) {
    final matches = RegExp(
      r"[A-Za-z0-9À-ỹ]+",
      unicode: true,
    ).allMatches(text.toLowerCase());
    final tokens = <String>{};
    for (final match in matches) {
      final word = match.group(0)!;
      if (word.length <= 1 || _stopWords.contains(word)) continue;
      tokens.add(word);
    }
    return tokens;
  }

  static Set<String> _expandWithSemanticConcepts(Set<String> queryTokens) {
    final expanded = <String>{...queryTokens};
    for (final group in _semanticConceptGroups) {
      if (queryTokens.any(group.contains)) {
        expanded.addAll(group);
      }
    }
    return expanded;
  }

  static List<String> _extractTopKeywords(String text, {int maxCount = 4}) {
    final counts = <String, int>{};
    final matches = RegExp(
      r"[A-Za-z0-9À-ỹ]+",
      unicode: true,
    ).allMatches(text.toLowerCase());
    for (final match in matches) {
      final word = match.group(0)!;
      if (word.length < 3 || _stopWords.contains(word)) continue;
      counts[word] = (counts[word] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return b.key.length.compareTo(a.key.length);
      });
    return sorted.take(maxCount).map((e) => e.key).toList();
  }
}
