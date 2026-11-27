import 'package:flutter/material.dart';

import '../features/notes/application/note_ai_service.dart';
import '../features/notes/domain/note_repository.dart';
import '../models/note.dart';
import '../theme/theme.dart';

/// Opens the AI Question Answering dialog allowing users to ask natural-language
/// questions about their authorized, unlocked notes and open referenced source
/// notes directly (R28).
Future<void> showNoteAiQaDialog(
  BuildContext context, {
  required Iterable<Note> candidateNotes,
  required String? viewerUid,
  required String? viewerEmail,
  required bool Function(Note note) isNoteUnlocked,
  required void Function(Note note) onOpenSourceNote,
  NoteAiService aiService = const NoteAiService(),
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _NoteAiQaDialog(
      candidateNotes: candidateNotes.toList(),
      viewerUid: viewerUid,
      viewerEmail: viewerEmail,
      isNoteUnlocked: isNoteUnlocked,
      onOpenSourceNote: onOpenSourceNote,
      aiService: aiService,
    ),
  );
}

class _NoteAiQaDialog extends StatefulWidget {
  const _NoteAiQaDialog({
    required this.candidateNotes,
    required this.viewerUid,
    required this.viewerEmail,
    required this.isNoteUnlocked,
    required this.onOpenSourceNote,
    required this.aiService,
  });

  final List<Note> candidateNotes;
  final String? viewerUid;
  final String? viewerEmail;
  final bool Function(Note note) isNoteUnlocked;
  final void Function(Note note) onOpenSourceNote;
  final NoteAiService aiService;

  @override
  State<_NoteAiQaDialog> createState() => _NoteAiQaDialogState();
}

class _NoteAiQaDialogState extends State<_NoteAiQaDialog> {
  final _questionController = TextEditingController();
  bool _busy = false;
  String? _error;
  NoteAiAnswerResult? _result;

  static const List<String> _suggestedPrompts = <String>[
    'What are my plans for the weekend?',
    'What items are on my grocery list?',
    'What books are on my reading list?',
    'What do we need for the project kickoff?',
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion([String? preset]) async {
    if (_busy) return;
    if (preset != null) {
      _questionController.text = preset;
    }
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Enter a question about your notes.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await widget.aiService.answerQuestion(
        question: question,
        candidateNotes: widget.candidateNotes,
        viewerUid: widget.viewerUid,
        viewerEmail: widget.viewerEmail,
        isNoteUnlocked: widget.isNoteUnlocked,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } on NoteFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not generate an AI answer right now.';
      });
    }
  }

  void _handleOpenSource(String noteId) {
    final index = widget.candidateNotes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;
    final target = widget.candidateNotes[index];
    Navigator.of(context).pop();
    widget.onOpenSourceNote(target);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;

    return AlertDialog(
      key: const Key('note-ai-qa-dialog'),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 22),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Ask AI about your notes')),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask a natural-language question. Answers are synthesized exclusively from notes you are authorized to access and have unlocked.',
                style: text.bodySmall?.copyWith(color: tokens.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _suggestedPrompts.map((prompt) {
                  return ActionChip(
                    label: Text(prompt, style: text.labelSmall),
                    onPressed: _busy ? null : () => _submitQuestion(prompt),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai-qa-question-input'),
                      controller: _questionController,
                      enabled: !_busy,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _submitQuestion(),
                      decoration: const InputDecoration(
                        labelText: 'Your question',
                        hintText:
                            'e.g. What should I buy at the grocery store?',
                        prefixIcon: Icon(Icons.psychology_outlined),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const Key('ai-qa-submit-button'),
                    onPressed: _busy ? null : () => _submitQuestion(),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const Text('Ask'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('ai-qa-error-text'),
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  key: Key(
                    _result!.hasSufficientInfo
                        ? 'ai-qa-answer-card'
                        : 'ai-qa-insufficient-info',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _result!.hasSufficientInfo
                        ? colors.surfaceContainer
                        : tokens.warning.withValues(alpha: 0.10),
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: _result!.hasSufficientInfo
                          ? tokens.glassBorder
                          : tokens.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _result!.hasSufficientInfo
                                ? Icons.auto_awesome_outlined
                                : Icons.info_outline_rounded,
                            size: 16,
                            color: _result!.hasSufficientInfo
                                ? colors.primary
                                : tokens.warning,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _result!.hasSufficientInfo
                                ? 'Synthesized Answer'
                                : 'Insufficient Relevant Information',
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _result!.answer,
                        key: const Key('ai-qa-answer-text'),
                        style: text.bodySmall?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
                if (_result!.sources.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'SOURCE NOTE REFERENCES (TAP TO OPEN)',
                    style: text.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final source in _result!.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Material(
                        color: colors.surfaceContainer,
                        borderRadius: AppRadius.mdAll,
                        child: InkWell(
                          key: Key('ai-qa-source-${source.noteId}'),
                          onTap: () => _handleOpenSource(source.noteId),
                          borderRadius: AppRadius.mdAll,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm + 2),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(color: tokens.glassBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source.title,
                                        style: text.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (source.snippet.isNotEmpty)
                                        Text(
                                          source.snippet,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.bodySmall?.copyWith(
                                            color: tokens.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.open_in_new_rounded, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('ai-qa-close-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
