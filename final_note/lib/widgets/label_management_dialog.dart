import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Dialog for listing, adding, renaming, and deleting account labels (R20).
class LabelManagementDialog extends StatefulWidget {
  const LabelManagementDialog({
    super.key,
    required this.initialLabels,
    required this.onAddLabel,
    required this.onRenameLabel,
    required this.onDeleteLabel,
  });

  final List<String> initialLabels;
  final Future<String?> Function(String name) onAddLabel;
  final Future<String?> Function(String oldName, String newName) onRenameLabel;
  final Future<String?> Function(String name) onDeleteLabel;

  @override
  State<LabelManagementDialog> createState() => _LabelManagementDialogState();
}

class _LabelManagementDialogState extends State<LabelManagementDialog> {
  late List<String> _labels;
  final _newLabelController = TextEditingController();
  final _renameController = TextEditingController();
  String? _editingLabel;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _labels = List<String>.of(widget.initialLabels);
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final name = _newLabelController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Enter a label name.');
      return;
    }
    if (_labels.any(
      (existing) => existing.toLowerCase() == name.toLowerCase(),
    )) {
      setState(() => _errorMessage = 'Label already exists.');
      return;
    }
    final error = await widget.onAddLabel(name);
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _labels = [..._labels, name]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _newLabelController.clear();
      _errorMessage = null;
    });
  }

  void _startRename(String label) {
    setState(() {
      _editingLabel = label;
      _renameController.text = label;
      _errorMessage = null;
    });
  }

  Future<void> _handleSaveRename(String oldName) async {
    final newName = _renameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _errorMessage = 'Enter a label name.');
      return;
    }
    if (newName == oldName) {
      setState(() {
        _editingLabel = null;
        _errorMessage = null;
      });
      return;
    }
    if (_labels.any(
      (existing) =>
          existing != oldName &&
          existing.toLowerCase() == newName.toLowerCase(),
    )) {
      setState(() => _errorMessage = 'Label already exists.');
      return;
    }

    final error = await widget.onRenameLabel(oldName, newName);
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _labels = _labels.map((item) => item == oldName ? newName : item).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _editingLabel = null;
      _errorMessage = null;
    });
  }

  Future<void> _handleDelete(String label) async {
    final error = await widget.onDeleteLabel(label);
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _labels = _labels.where((item) => item != label).toList();
      if (_editingLabel == label) {
        _editingLabel = null;
      }
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;

    return AlertDialog(
      title: const Text('Manage labels'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('new-label-input'),
                      controller: _newLabelController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleAdd(),
                      decoration: const InputDecoration(
                        hintText: 'Create new label...',
                        prefixIcon: Icon(Icons.new_label_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    key: const Key('add-label-button'),
                    tooltip: 'Add label',
                    onPressed: _handleAdd,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage!,
                  key: const Key('label-error-text'),
                  style: text.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'No labels yet. Add your first label above.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: tokens.textMuted),
                  ),
                )
              else
                for (var i = 0; i < _labels.length; i++)
                  _buildLabelRow(context, _labels[i], index: i),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('close-manage-labels'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildLabelRow(
    BuildContext context,
    String label, {
    required int index,
  }) {
    final tokens = context.tokens;
    final colors = context.colors;
    final text = context.text;
    final accent = tokens.noteAccent(index);
    final isEditing = _editingLabel == label;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: isEditing
                ? TextField(
                    key: Key('rename-label-input-$label'),
                    controller: _renameController,
                    autofocus: true,
                    onSubmitted: (_) => _handleSaveRename(label),
                    decoration: const InputDecoration(isDense: true),
                  )
                : Text(
                    label,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          if (isEditing) ...[
            IconButton(
              key: Key('save-rename-label-$label'),
              tooltip: 'Save label name',
              onPressed: () => _handleSaveRename(label),
              icon: Icon(Icons.check_rounded, color: tokens.success),
            ),
            IconButton(
              key: Key('cancel-rename-label-$label'),
              tooltip: 'Cancel rename',
              onPressed: () => setState(() {
                _editingLabel = null;
                _errorMessage = null;
              }),
              icon: const Icon(Icons.close_rounded),
            ),
          ] else ...[
            IconButton(
              key: Key('rename-label-$label'),
              tooltip: 'Rename $label',
              onPressed: () => _startRename(label),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              key: Key('delete-label-$label'),
              tooltip: 'Delete $label',
              onPressed: () => _handleDelete(label),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
