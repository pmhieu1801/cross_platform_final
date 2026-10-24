import 'package:flutter/material.dart';

import '../models/note.dart';

const _pageColor = Color(0xFFFAF9F6);
const _inkColor = Color(0xFF202A26);
const _mutedColor = Color(0xFF77817C);
const _accentColor = Color(0xFF315C4C);
const _noteColors = [
  Color(0xFFF7E7D5),
  Color(0xFFE3EEE7),
  Color(0xFFEAE7F4),
  Color(0xFFF4E5E5),
  Color(0xFFE5EDF4),
  Color(0xFFF1EFD9),
];

enum _NotesSection { all, pinned }

enum _NotesLayout { grid, list }

class NotesHomeScreen extends StatefulWidget {
  const NotesHomeScreen({super.key, this.initialNotes});

  final List<Note>? initialNotes;

  @override
  State<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends State<NotesHomeScreen> {
  late final List<Note> _notes;
  final _searchController = TextEditingController();
  _NotesSection _section = _NotesSection.all;
  _NotesLayout _layout = _NotesLayout.grid;
  String? _selectedLabel;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.initialNotes ?? createDemoNotes());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _labels {
    final labels = _notes.expand((note) => note.labels).toSet().toList()
      ..sort();
    return labels;
  }

  List<Note> get _visibleNotes {
    final query = _query.trim().toLowerCase();
    final visible = _notes.where((note) {
      final matchesSection =
          _section == _NotesSection.all || note.isPinned;
      final matchesLabel =
          _selectedLabel == null || note.labels.contains(_selectedLabel);
      final matchesQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.labels.any((label) => label.toLowerCase().contains(query));
      return matchesSection && matchesLabel && matchesQuery;
    }).toList();

    visible.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isPinned && b.isPinned) {
        final pinnedOrder = (b.pinnedAt ?? b.updatedAt).compareTo(
          a.pinnedAt ?? a.updatedAt,
        );
        if (pinnedOrder != 0) return pinnedOrder;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return visible;
  }

  void _togglePin(Note note) {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;

    final pinning = !note.isPinned;
    setState(() {
      _notes[index] = note.copyWith(
        isPinned: pinning,
        pinnedAt: pinning ? DateTime.now() : null,
        clearPinnedAt: !pinning,
      );
    });
  }

  void _showPreview(Note note) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _noteColors[note.colorIndex % _noteColors.length],
        title: Text(note.title),
        content: SingleChildScrollView(child: Text(note.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final isCompact = constraints.maxWidth < 600;
        final notes = _visibleNotes;

        return Scaffold(
          backgroundColor: _pageColor,
          body: SafeArea(
            bottom: !isCompact,
            child: Row(
              children: [
                if (isWide) _buildSidebar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: _buildContent(
                        notes: notes,
                        isCompact: isCompact,
                        isWide: isWide,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  Widget _buildSidebar() {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFECEEEA))),
      ),
      padding: const EdgeInsets.fromLTRB(22, 28, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'NoteFlow',
                style: TextStyle(
                  color: _inkColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _SidebarItem(
            icon: Icons.notes_rounded,
            label: 'All notes',
            selected: _section == _NotesSection.all && _selectedLabel == null,
            onTap: () => setState(() {
              _section = _NotesSection.all;
              _selectedLabel = null;
            }),
          ),
          const SizedBox(height: 6),
          _SidebarItem(
            icon: Icons.push_pin_outlined,
            label: 'Pinned',
            selected: _section == _NotesSection.pinned,
            onTap: () => setState(() {
              _section = _NotesSection.pinned;
              _selectedLabel = null;
            }),
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'YOUR LABELS',
              style: TextStyle(
                color: _mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ..._labels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SidebarItem(
                icon: Icons.sell_outlined,
                label: label,
                selected: _selectedLabel == label,
                onTap: () => setState(() {
                  _section = _NotesSection.all;
                  _selectedLabel = _selectedLabel == label ? null : label;
                }),
              ),
            ),
          ),
          const Spacer(),
          const Divider(color: Color(0xFFECEEEA)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFE5EEE8),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _accentColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal space',
                    style: TextStyle(
                      color: _inkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your notes',
                    style: TextStyle(color: _mutedColor, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required List<Note> notes,
    required bool isCompact,
    required bool isWide,
  }) {
    final title = _selectedLabel ??
        (_section == _NotesSection.pinned ? 'Pinned notes' : 'Your notes');
    final subtitle = _section == _NotesSection.pinned && _selectedLabel == null
        ? 'Your most important thoughts, close at hand.'
        : 'A calm place for everything on your mind.';

    return Column(
      children: [
        if (!isWide) _buildCompactBrand(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 20 : 42,
              isCompact ? 16 : 40,
              isCompact ? 20 : 42,
              32,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: isCompact ? 28 : 34),
                        ),
                        const SizedBox(height: 7),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 24),
                    _buildDateBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 28),
              _buildSearchAndLayout(),
              const SizedBox(height: 24),
              _buildSectionHeading(notes.length),
              const SizedBox(height: 14),
              if (_labels.isNotEmpty) ...[
                _buildLabelFilters(),
                const SizedBox(height: 20),
              ],
              if (notes.isEmpty)
                _buildEmptyState()
              else if (_layout == _NotesLayout.grid)
                _buildGrid(notes, isCompact)
              else
                _buildList(notes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBrand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'NoteFlow',
            style: TextStyle(
              color: _inkColor,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE5EEE8),
            child: Icon(
              Icons.person_outline_rounded,
              color: _accentColor,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECEEEA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$weekday, ${now.day} $month',
        style: const TextStyle(
          color: _mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchAndLayout() {
    return Row(
      children: [
        Expanded(
          child: TextField(
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
        const SizedBox(width: 8),
        _LayoutToggle(
          layout: _layout,
          onChanged: (layout) => setState(() => _layout = layout),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(int count) {
    return Row(
      children: [
        const Text(
          'All notes',
          style: TextStyle(
            color: _inkColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEFEB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        if (_selectedLabel != null)
          TextButton.icon(
            onPressed: () => setState(() => _selectedLabel = null),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear filter'),
          ),
      ],
    );
  }

  Widget _buildLabelFilters() {
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
              padding: const EdgeInsets.only(left: 8),
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

  Widget _buildGrid(List<Note> notes, bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 880
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: isCompact ? 228 : 246,
          ),
          itemBuilder: (context, index) => _NoteCard(
            note: notes[index],
            onTap: () => _showPreview(notes[index]),
            onTogglePin: () => _togglePin(notes[index]),
          ),
        );
      },
    );
  }

  Widget _buildList(List<Note> notes) {
    return Column(
      children: [
        for (final note in notes) ...[
          _NoteListTile(
            note: note,
            onTap: () => _showPreview(note),
            onTogglePin: () => _togglePin(note),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    final searching = _query.trim().isNotEmpty || _selectedLabel != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECEEEA)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F3EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.push_pin_outlined,
              color: _accentColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? 'No notes found' : 'Nothing pinned yet',
            style: const TextStyle(
              color: _inkColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            searching
                ? 'Try another search or clear your label filter.'
                : 'Pin a note to keep it close at hand.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _mutedColor),
          ),
        ],
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF0EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? _accentColor : _mutedColor,
              ),
              const SizedBox(width: 11),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _accentColor : const Color(0xFF59635E),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7E9E5)),
        borderRadius: BorderRadius.circular(13),
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
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? const Color(0xFFEAF0EB)
            : Colors.transparent,
        foregroundColor: selected ? _accentColor : _mutedColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEAF0EB),
      side: BorderSide(
        color: selected ? const Color(0xFFCAD8CE) : const Color(0xFFE7E9E5),
      ),
      labelStyle: TextStyle(
        color: selected ? _accentColor : const Color(0xFF59635E),
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _noteColors[note.colorIndex % _noteColors.length],
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(note.updatedAt),
                      style: const TextStyle(
                        color: Color(0xFF707972),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (note.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: _accentColor,
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 130),
                    iconSize: 19,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF707972),
                    ),
                    onSelected: (value) {
                      if (value == 'pin') onTogglePin();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(
                          note.isPinned ? 'Unpin note' : 'Pin note',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _inkColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF59635E),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),
              if (note.labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.labels.take(3).map(_NoteLabelBadge.new).toList(),
                ),
              ],
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
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _noteColors[note.colorIndex % _noteColors.length],
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
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
                            style: const TextStyle(
                              color: _inkColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (note.isPinned) ...[
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.push_pin_rounded,
                            color: _accentColor,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      note.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF59635E),
                        fontSize: 12,
                      ),
                    ),
                    if (note.labels.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: note.labels.take(3).map(_NoteLabelBadge.new).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDate(note.updatedAt),
                style: const TextStyle(color: _mutedColor, fontSize: 11),
              ),
              PopupMenuButton<String>(
                tooltip: 'Note actions',
                onSelected: (value) {
                  if (value == 'pin') onTogglePin();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded, color: _mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteLabelBadge extends StatelessWidget {
  const _NoteLabelBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5B665F),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
