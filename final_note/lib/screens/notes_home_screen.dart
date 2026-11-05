import 'dart:async';

import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'note_editor_sheet.dart';

enum _NotesSection { all, pinned }

enum _NotesLayout { grid, list }

class NotesHomeScreen extends StatefulWidget {
  const NotesHomeScreen({
    super.key,
    this.initialNotes,
    this.notes,
    this.labels,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.user,
    this.verificationBanner,
    this.authBusy = false,
    this.authError,
    this.onLogout,
    this.onSaveNote,
    this.onDeleteNote,
    this.onTogglePin,
    this.onAddLabel,
    this.onRenameLabel,
    this.onDeleteLabel,
    this.editorDebounceDuration = const Duration(milliseconds: 400),
  });

  /// Used when [NotesHomeScreen] is mounted standalone without external state.
  final List<Note>? initialNotes;

  /// Externally managed notes (e.g. from Riverpod [accountNotesStreamProvider]).
  final List<Note>? notes;

  /// Externally managed label catalog (e.g. from [accountLabelsStreamProvider]).
  final List<String>? labels;

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// Authenticated user metadata for `/home` header & verification banner.
  final AuthUser? user;
  final Widget? verificationBanner;
  final bool authBusy;
  final String? authError;
  final VoidCallback? onLogout;

  /// External persistence callbacks. When omitted, mutations update local state.
  final Future<Note?> Function(Note note, {required bool isAutosave})?
  onSaveNote;
  final Future<bool> Function(String noteId)? onDeleteNote;
  final Future<Note?> Function(String noteId)? onTogglePin;
  final Future<String?> Function(String name)? onAddLabel;
  final Future<String?> Function(String oldName, String newName)? onRenameLabel;
  final Future<String?> Function(String name)? onDeleteLabel;

  final Duration editorDebounceDuration;

  @override
  State<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends State<NotesHomeScreen> {
  late final List<Note> _localNotes;
  late final Set<String> _localLabelCatalog;
  final _searchController = TextEditingController();
  _NotesSection _section = _NotesSection.all;
  _NotesLayout _layout = _NotesLayout.grid;
  String? _selectedLabel;
  String _query = '';

  /// Currently open note in the desktop side-by-side editor (`null` if closed).
  Note? _activeEditorNote;
  bool _isCreatingNew = false;
  int _editorSessionCounter = 0;
  String _editorSessionKey = 'editor-session-0';

  @override
  void initState() {
    super.initState();
    _localNotes = List<Note>.of(widget.initialNotes ?? createDemoNotes());
    _localLabelCatalog = _localNotes.expand((note) => note.labels).toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _persistLocalNotes() async {
    await NoteStorage.saveNotes(_localNotes);
  }

  List<Note> get _allNotes => widget.notes ?? _localNotes;

  List<String> get _labels {
    if (widget.labels != null) {
      final merged = {
        ...widget.labels!,
        ..._allNotes.expand((n) => n.labels),
      }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return merged;
    }
    final merged = {
      ..._localLabelCatalog,
      ..._localNotes.expand((note) => note.labels),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return merged;
  }

  List<Note> get _visibleNotes {
    final query = _query.trim().toLowerCase();
    final filtered = _allNotes.where((note) {
      final matchesSection = _section == _NotesSection.all || note.isPinned;
      final matchesLabel =
          _selectedLabel == null || note.labels.contains(_selectedLabel);
      final matchesQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.labels.any((label) => label.toLowerCase().contains(query));
      return matchesSection && matchesLabel && matchesQuery;
    });
    return sortNotes(filtered);
  }

  Future<Note?> _saveNote(Note draft, {required bool isAutosave}) async {
    if (widget.onSaveNote != null) {
      final saved = await widget.onSaveNote!(draft, isAutosave: isAutosave);
      if (saved != null &&
          mounted &&
          (_isCreatingNew || _activeEditorNote != null)) {
        setState(() {
          _activeEditorNote = saved;
          _isCreatingNew = false;
        });
      }
      return saved;
    }

    setState(() {
      _localLabelCatalog.addAll(draft.labels);
      final index = _localNotes.indexWhere((item) => item.id == draft.id);
      if (index == -1) {
        _localNotes.add(draft);
      } else {
        _localNotes[index] = draft;
      }
      if (_isCreatingNew || _activeEditorNote != null) {
        _activeEditorNote = draft;
        _isCreatingNew = false;
      }
    });
    await _persistLocalNotes();
    return draft;
  }

  Future<bool> _deleteNoteWithoutConfirm(String noteId) async {
    if (widget.onDeleteNote != null) {
      final ok = await widget.onDeleteNote!(noteId);
      if (ok && mounted && _activeEditorNote?.id == noteId) {
        setState(() {
          _activeEditorNote = null;
          _isCreatingNew = false;
        });
      }
      return ok;
    }

    setState(() {
      _localNotes.removeWhere((item) => item.id == noteId);
      if (_activeEditorNote?.id == noteId) {
        _activeEditorNote = null;
        _isCreatingNew = false;
      }
    });
    await _persistLocalNotes();
    return true;
  }

  Future<void> _confirmAndDelete(Note note) async {
    final confirmed = await confirmDeleteNote(context, title: note.title);
    if (!confirmed || !mounted) return;
    await _deleteNoteWithoutConfirm(note.id);
  }

  Future<void> _togglePin(Note note) async {
    if (widget.onTogglePin != null) {
      await widget.onTogglePin!(note.id);
      return;
    }

    final index = _localNotes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;

    final pinning = !note.isPinned;
    final now = DateTime.now();
    setState(() {
      _localNotes[index] = note.copyWith(
        isPinned: pinning,
        pinnedAt: pinning ? now : null,
        clearPinnedAt: !pinning,
        updatedAt: now,
      );
    });
    await _persistLocalNotes();
  }

  Future<String?> _handleAddLabel(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a label name.';
    if (widget.onAddLabel != null) {
      return widget.onAddLabel!(trimmed);
    }
    if (_labels.any((item) => item.toLowerCase() == trimmed.toLowerCase())) {
      return 'Label already exists.';
    }
    setState(() => _localLabelCatalog.add(trimmed));
    return null;
  }

  Future<String?> _handleRenameLabel(String oldName, String newName) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty) return 'Enter a label name.';
    if (widget.onRenameLabel != null) {
      final error = await widget.onRenameLabel!(oldName, trimmedNew);
      if (error == null && mounted && _selectedLabel == oldName) {
        setState(() => _selectedLabel = trimmedNew);
      }
      return error;
    }
    if (_labels.any(
      (item) =>
          item != oldName && item.toLowerCase() == trimmedNew.toLowerCase(),
    )) {
      return 'Label already exists.';
    }
    setState(() {
      _localLabelCatalog
        ..remove(oldName)
        ..add(trimmedNew);
      for (var i = 0; i < _localNotes.length; i++) {
        final note = _localNotes[i];
        if (!note.labels.contains(oldName)) continue;
        final updated = <String>[];
        for (final label in note.labels) {
          final next = label == oldName ? trimmedNew : label;
          if (!updated.contains(next)) updated.add(next);
        }
        _localNotes[i] = note.copyWith(
          labels: List<String>.unmodifiable(updated),
        );
      }
      if (_selectedLabel == oldName) {
        _selectedLabel = trimmedNew;
      }
    });
    await _persistLocalNotes();
    return null;
  }

  Future<String?> _handleDeleteLabel(String name) async {
    if (widget.onDeleteLabel != null) {
      final error = await widget.onDeleteLabel!(name);
      if (error == null && mounted && _selectedLabel == name) {
        setState(() => _selectedLabel = null);
      }
      return error;
    }
    setState(() {
      _localLabelCatalog.remove(name);
      for (var i = 0; i < _localNotes.length; i++) {
        final note = _localNotes[i];
        if (!note.labels.contains(name)) continue;
        _localNotes[i] = note.copyWith(
          labels: List<String>.unmodifiable(
            note.labels.where((item) => item != name),
          ),
        );
      }
      if (_selectedLabel == name) {
        _selectedLabel = null;
      }
    });
    await _persistLocalNotes();
    return null;
  }

  void _openManageLabelsDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => LabelManagementDialog(
        initialLabels: _labels,
        onAddLabel: _handleAddLabel,
        onRenameLabel: _handleRenameLabel,
        onDeleteLabel: _handleDeleteLabel,
      ),
    );
  }

  void _openAccountSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AccountSettingsDialog(
        user: widget.user,
        authBusy: widget.authBusy,
        onLogout: widget.onLogout,
      ),
    );
  }

  void _openEditor({Note? note, required bool isWide}) {
    if (isWide) {
      setState(() {
        _editorSessionCounter++;
        _editorSessionKey =
            'editor-session-$_editorSessionCounter-${note?.id ?? 'new'}';
        _activeEditorNote = note;
        _isCreatingNew = note == null;
      });
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SingleChildScrollView(
            child: NoteEditorPanel(
              initialNote: note,
              availableLabels: _labels,
              debounceDuration: widget.editorDebounceDuration,
              onSave: _saveNote,
              onDelete: (target) => _deleteNoteWithoutConfirm(target.id),
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.expanded;
        final isCompact = constraints.maxWidth < AppBreakpoints.medium;
        final notes = _visibleNotes;
        final showSideEditor =
            isWide && (_isCreatingNew || _activeEditorNote != null);

        return Scaffold(
          body: AppBackground(
            child: SafeArea(
              bottom: !isCompact,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isWide) _buildSidebar(context, isWide: isWide),
                  Expanded(
                    flex: 7,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: _buildMainContent(
                          context,
                          notes: notes,
                          isCompact: isCompact,
                          isWide: isWide,
                        ),
                      ),
                    ),
                  ),
                  if (showSideEditor)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppSizes.editorPanelMinWidth,
                        maxWidth: 440,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: SingleChildScrollView(
                          child: NoteEditorPanel(
                            key: ValueKey(_editorSessionKey),
                            initialNote: _activeEditorNote,
                            availableLabels: _labels,
                            embedded: true,
                            debounceDuration: widget.editorDebounceDuration,
                            onSave: _saveNote,
                            onDelete: (target) =>
                                _deleteNoteWithoutConfirm(target.id),
                            onClose: () => setState(() {
                              _activeEditorNote = null;
                              _isCreatingNew = false;
                            }),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('create-note-button'),
            onPressed: () => _openEditor(isWide: isWide),
            backgroundColor: AppColors.charcoal,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New note'),
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _section == _NotesSection.all ? 0 : 1,
                  onDestinationSelected: (index) {
                    setState(() {
                      _section = index == 0
                          ? _NotesSection.all
                          : _NotesSection.pinned;
                      _selectedLabel = null;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.notes_outlined),
                      selectedIcon: Icon(Icons.notes_rounded),
                      label: 'All notes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.push_pin_outlined),
                      selectedIcon: Icon(Icons.push_pin_rounded),
                      label: 'Pinned',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isWide}) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;

    return Container(
      width: AppSizes.sidebarWidth,
      decoration: BoxDecoration(
        color: tokens.glassFill,
        border: Border(right: BorderSide(color: tokens.glassBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BrandBadge(size: 36),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // MINO-style "Add new" button with solid dark icon badge + 3 color dots
          GradientButton(
            key: const Key('sidebar-create-note'),
            label: 'New note',
            icon: Icons.add_rounded,
            height: 44,
            onPressed: () => _openEditor(isWide: isWide),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                for (final dot in const [
                  Color(0xFFD4EDC9),
                  Color(0xFFCCCBE6),
                  AppColors.brandRed,
                ])
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SidebarItem(
            icon: Icons.calendar_today_outlined,
            label: 'All notes',
            selected: _section == _NotesSection.all && _selectedLabel == null,
            onTap: () => setState(() {
              _section = _NotesSection.all;
              _selectedLabel = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xs),
          _SidebarItem(
            icon: Icons.push_pin_outlined,
            label: 'Pinned',
            selected: _section == _NotesSection.pinned,
            onTap: () => setState(() {
              _section = _NotesSection.pinned;
              _selectedLabel = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'FOLDERS & LABELS',
                    style: text.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('sidebar-manage-labels'),
                  tooltip: 'Manage labels',
                  onPressed: _openManageLabelsDialog,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: _SidebarItem(
                      icon: Icons.folder_outlined,
                      dotColor: tokens.noteAccent(i),
                      label: _labels[i],
                      selected: _selectedLabel == _labels[i],
                      onTap: () => setState(() {
                        _section = _NotesSection.all;
                        _selectedLabel = _selectedLabel == _labels[i]
                            ? null
                            : _labels[i];
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: Colors.transparent,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              key: const Key('sidebar-profile-card'),
              onTap: _openAccountSettingsDialog,
              borderRadius: AppRadius.mdAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: colors.onPrimaryContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user?.displayName ??
                                widget.user?.email ??
                                'Personal space',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.user?.email ?? 'Your notes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                          if (widget.user != null)
                            Text(
                              'Firebase UID: ${widget.user!.uid}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: tokens.textMuted,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    if (widget.onLogout != null)
                      IconButton(
                        key: const Key('logout'),
                        tooltip: 'Đăng xuất',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.authBusy ? null : widget.onLogout,
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 17,
                          color: tokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    required List<Note> notes,
    required bool isCompact,
    required bool isWide,
  }) {
    final text = context.text;
    final tokens = context.tokens;
    final title =
        _selectedLabel ??
        (_section == _NotesSection.pinned ? 'Pinned notes' : 'MY NOTES');
    final subtitle = _section == _NotesSection.pinned && _selectedLabel == null
        ? 'Your most important thoughts, close at hand.'
        : 'Organized folders and notes in one clean workspace.';

    return Column(
      children: [
        if (!isWide)
          _buildTopHeader(context, isWide: isWide, isCompact: isCompact),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isCompact ? AppSpacing.lg : AppSpacing.xxl,
              AppSpacing.lg,
              isCompact ? AppSpacing.lg : AppSpacing.xxl,
              96,
            ),
            children: [
              if (widget.user != null && !widget.user!.emailVerified) ...[
                widget.verificationBanner ?? _buildUnverifiedBanner(context),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.authError != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.authError!,
                    style: text.bodySmall?.copyWith(color: tokens.danger),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.headlineMedium?.copyWith(
                            fontSize: isCompact ? 24 : 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          style: text.bodyMedium?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: AppSpacing.lg),
                    _buildDateBadge(context),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSearchAndLayout(context),
              const SizedBox(height: AppSpacing.xl),
              // MINO-style "Recent Folders" pastel cards on desktop layout
              if (isWide && _labels.isNotEmpty) ...[
                _buildRecentFoldersSection(context),
                const SizedBox(height: AppSpacing.xl),
              ],
              _buildSectionHeading(context, notes.length),
              const SizedBox(height: AppSpacing.md),
              _buildLabelFilters(context),
              const SizedBox(height: AppSpacing.lg),
              if (widget.isLoading)
                const LoadingStateView(message: 'Loading your notes...')
              else if (widget.errorMessage != null)
                ErrorStateView(
                  message: widget.errorMessage!,
                  onRetry: widget.onRetry,
                )
              else if (notes.isEmpty)
                _buildEmptyState(isWide: isWide)
              else if (_layout == _NotesLayout.grid)
                _buildGrid(notes, isCompact: isCompact, isWide: isWide)
              else
                _buildList(notes, isWide: isWide),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFoldersSection(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final folderLabels = _labels.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Folders',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 19,
              ),
            ),
            const Spacer(),
            Text(
              '${_labels.length} folders',
              style: text.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < folderLabels.length; i++) ...[
                Expanded(
                  child: _FolderCard(
                    label: folderLabels[i],
                    colorIndex: i,
                    selected: _selectedLabel == folderLabels[i],
                    noteCount: _allNotes
                        .where((n) => n.labels.contains(folderLabels[i]))
                        .length,
                    onTap: () => setState(() {
                      _selectedLabel = _selectedLabel == folderLabels[i]
                          ? null
                          : folderLabels[i];
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              SizedBox(
                width: 136,
                child: _NewFolderActionCard(onTap: _openManageLabelsDialog),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader(
    BuildContext context, {
    required bool isWide,
    required bool isCompact,
  }) {
    final user = widget.user;
    final text = context.text;
    final tokens = context.tokens;

    if (!isWide && user == null) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.glassFill,
          border: Border(bottom: BorderSide(color: tokens.glassBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            const BrandBadge(size: 32),
            const Spacer(),
            CircleAvatar(
              radius: 16,
              backgroundColor: context.colors.primaryContainer,
              child: Icon(
                Icons.person_outline_rounded,
                color: context.colors.onPrimaryContainer,
                size: 18,
              ),
            ),
          ],
        ),
      );
    }

    if (user == null) {
      return const SizedBox(height: AppSpacing.sm);
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.glassFill,
        border: Border(bottom: BorderSide(color: tokens.glassBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        isCompact ? AppSpacing.lg : AppSpacing.xxl,
        AppSpacing.md,
        isCompact ? AppSpacing.lg : AppSpacing.xxl,
        AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            key: const Key('header-profile-card'),
            onTap: _openAccountSettingsDialog,
            borderRadius: AppRadius.smAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isWide) ...[
                    const BrandBadge(size: 30, showText: false),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xin chào, ${user.displayName ?? user.email ?? 'bạn'}',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SelectableText(
                          'Firebase UID: ${user.uid}',
                          style: text.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.onLogout != null)
            OutlinedButton.icon(
              key: const Key('logout'),
              onPressed: widget.authBusy ? null : widget.onLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: Text(widget.authBusy ? 'Đang xử lý…' : 'Đăng xuất'),
            ),
        ],
      ),
    );
  }

  Widget _buildUnverifiedBanner(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: tokens.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: tokens.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Email chưa được xác minh. Vui lòng hoàn tất xác minh email. '
              'Bạn vẫn có thể sử dụng ứng dụng.',
              style: text.bodySmall?.copyWith(color: context.colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge(BuildContext context) {
    final now = DateTime.now();
    final weekday = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];
    final month = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][now.month - 1];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.tokens.glassFill,
        border: Border.all(color: context.tokens.glassBorder),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 16,
            color: context.tokens.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$weekday, ${now.day} $month',
            style: context.text.labelMedium?.copyWith(
              color: context.tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('notes-search-input'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search your notes...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _LayoutToggle(
          layout: _layout,
          onChanged: (layout) => setState(() => _layout = layout),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(BuildContext context, int count) {
    final text = context.text;
    final colors = context.colors;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Notes',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 19,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: AppRadius.pillAll,
              ),
              child: Text(
                '$count',
                style: text.labelSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_selectedLabel != null)
              TextButton.icon(
                onPressed: () => setState(() => _selectedLabel = null),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear filter'),
              ),
            TextButton.icon(
              key: const Key('manage-labels-button'),
              onPressed: _openManageLabelsDialog,
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('Manage labels'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabelFilters(BuildContext context) {
    if (_labels.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LabelFilterChip(
            label: 'All',
            selected: _selectedLabel == null,
            onTap: () => setState(() => _selectedLabel = null),
          ),
          ..._labels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _LabelFilterChip(
                label: label,
                selected: _selectedLabel == label,
                onTap: () => setState(() {
                  _selectedLabel = _selectedLabel == label ? null : label;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    List<Note> notes, {
    required bool isCompact,
    required bool isWide,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisExtent: isCompact ? 236 : 254,
          ),
          itemBuilder: (context, index) {
            final note = notes[index];
            return _NoteCard(
              note: note,
              onTap: () => _openEditor(note: note, isWide: isWide),
              onTogglePin: () => _togglePin(note),
              onDelete: () => _confirmAndDelete(note),
            );
          },
        );
      },
    );
  }

  Widget _buildList(List<Note> notes, {required bool isWide}) {
    return Column(
      children: [
        for (final note in notes) ...[
          _NoteListTile(
            note: note,
            onTap: () => _openEditor(note: note, isWide: isWide),
            onTogglePin: () => _togglePin(note),
            onDelete: () => _confirmAndDelete(note),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
        ],
      ],
    );
  }

  Widget _buildEmptyState({required bool isWide}) {
    final searching = _query.trim().isNotEmpty || _selectedLabel != null;
    if (searching) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No notes found',
        message: 'Try another search or clear your label filter.',
        actionLabel: 'Clear filter',
        onAction: () {
          _searchController.clear();
          setState(() {
            _query = '';
            _selectedLabel = null;
          });
        },
      );
    }

    if (_section == _NotesSection.pinned) {
      return const EmptyStateView(
        icon: Icons.push_pin_outlined,
        title: 'Nothing pinned yet',
        message: 'Pin a note to keep it close at hand.',
      );
    }

    return EmptyStateView(
      icon: Icons.note_add_outlined,
      title: 'Your workspace is empty',
      message: 'Create your first note to capture ideas and thoughts.',
      actionLabel: 'Create note',
      onAction: () => _openEditor(isWide: isWide),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.label,
    required this.colorIndex,
    required this.selected,
    required this.noteCount,
    required this.onTap,
  });

  final String label;
  final int colorIndex;
  final bool selected;
  final int noteCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final fill =
        AppColors.folderPastels[colorIndex % AppColors.folderPastels.length];
    final iconColor = AppColors
        .folderIconColors[colorIndex % AppColors.folderIconColors.length];

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.charcoal : Colors.transparent,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.charcoal.withValues(alpha: 0.65),
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
                style: text.labelSmall?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewFolderActionCard extends StatelessWidget {
  const _NewFolderActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Material(
      color: tokens.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.outline, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.create_new_folder_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New folder',
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tokens = context.tokens;

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.85)
          : Colors.transparent,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 3,
          ),
          child: Row(
            children: [
              if (dotColor != null)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 19,
                  color: selected ? colors.primary : tokens.textMuted,
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.layout, required this.onChanged});

  final _NotesLayout layout;
  final ValueChanged<_NotesLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.glassFill,
        border: Border.all(color: tokens.glassBorder),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          _LayoutButton(
            icon: Icons.grid_view_rounded,
            label: 'Grid view',
            selected: layout == _NotesLayout.grid,
            onTap: () => onChanged(_NotesLayout.grid),
          ),
          _LayoutButton(
            icon: Icons.view_agenda_outlined,
            label: 'List view',
            selected: layout == _NotesLayout.list,
            onTap: () => onChanged(_NotesLayout.list),
          ),
        ],
      ),
    );
  }
}

class _LayoutButton extends StatelessWidget {
  const _LayoutButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return IconButton(
      tooltip: label,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? colors.primaryContainer
            : Colors.transparent,
        foregroundColor: selected
            ? colors.onPrimaryContainer
            : tokens.textMuted,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class _LabelFilterChip extends StatelessWidget {
  const _LabelFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FilterChip(
      key: Key('filter-label-chip-$label'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: context.tokens.glassFill,
      selectedColor: colors.primaryContainer,
      side: BorderSide(
        color: selected ? colors.primary : context.tokens.glassBorder,
      ),
      labelStyle: context.text.labelMedium?.copyWith(
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    );
  }
}

/// MINO-inspired solid pastel Note Card:
/// - Solid pastel fill (`#EBE886` yellow, `#F1ACAC` coral, `#77BFE6` sky blue, etc.)
/// - Top date + pin/more menu
/// - Bold title + dark rounded-square edit icon badge (`#111827`)
/// - Multi-line body text
/// - Bottom clock icon + timestamp and label badges
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final cardFill = tokens.noteCardFill(note.colorIndex);
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.68);

    return Material(
      color: cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: note.isPinned
              ? inkColor.withValues(alpha: 0.45)
              : inkColor.withValues(alpha: 0.06),
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('note-card-${note.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatShortDate(note.updatedAt),
                      style: text.labelSmall?.copyWith(
                        color: subInkColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: inkColor,
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 140),
                    iconSize: 19,
                    icon: Icon(Icons.more_horiz_rounded, color: subInkColor),
                    onSelected: (value) {
                      if (value == 'pin') onTogglePin();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete note'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: inkColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: inkColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: subInkColor,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: subInkColor),
                  const SizedBox(width: 5),
                  Text(
                    _formatDate(note.updatedAt),
                    style: text.labelSmall?.copyWith(
                      color: subInkColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (note.labels.isNotEmpty)
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: note.labels
                            .take(2)
                            .map((label) => _NoteLabelBadge(label: label))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  const _NoteListTile({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = context.text;
    final cardFill = tokens.noteCardFill(note.colorIndex);
    const inkColor = AppColors.charcoal;
    final subInkColor = AppColors.charcoal.withValues(alpha: 0.68);

    return Material(
      color: cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? inkColor.withValues(alpha: 0.45)
              : inkColor.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        key: Key('note-tile-${note.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: inkColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: inkColor,
                            ),
                          ),
                        ),
                        if (note.isPinned) ...[
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.push_pin_rounded,
                            color: inkColor,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: subInkColor),
                    ),
                    if (note.labels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: note.labels
                            .take(3)
                            .map((label) => _NoteLabelBadge(label: label))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(note.updatedAt),
                style: text.labelSmall?.copyWith(color: subInkColor),
              ),
              PopupMenuButton<String>(
                tooltip: 'Note actions',
                onSelected: (value) {
                  if (value == 'pin') onTogglePin();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete note'),
                  ),
                ],
                icon: Icon(Icons.more_horiz_rounded, color: subInkColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteLabelBadge extends StatelessWidget {
  const _NoteLabelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: AppColors.charcoal,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (dateOnly == today) {
    return 'Today';
  }
  if (dateOnly == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
