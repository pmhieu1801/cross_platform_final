import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../theme/theme.dart';
import '../../../utils/validators.dart';
import '../../../widgets/widgets.dart';
import '../application/auth_providers.dart';
import '../application/profile_controller.dart';
import '../data/local_avatar_repository.dart';
import 'profile_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _editing = false;
  String? _avatarFeedback;
  bool _avatarError = false;

  Future<void> _openAvatarPickerDialog() async {
    final base64Controller = TextEditingController();
    final picked =
        await showDialog<({Uint8List? bytes, String? mime, bool remove})>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              key: const Key('profile-avatar-dialog'),
              title: const Text('Update profile avatar'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose an image file from your device (PNG/JPEG <= 5 MB) or select a preset:',
                      style: dialogContext.text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonalIcon(
                      key: const Key('avatar-pick-device-file'),
                      onPressed: () async {
                        try {
                          final files = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['png', 'jpg', 'jpeg'],
                          );
                          if (files.isEmpty) return;
                          final file = files.first;
                          final bytes = await file.readAsBytes();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext)
                                .pop((bytes: bytes, mime: null, remove: false));
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop((
                              bytes: Uint8List(0),
                              mime: null,
                              remove: false,
                            ));
                          }
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Choose image from device'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: LocalAvatarRepository.sampleAvatars.map((
                        sample,
                      ) {
                        return ActionChip(
                          key: Key('avatar-preset-${sample.id}'),
                          avatar: const Icon(Icons.image_outlined, size: 16),
                          label: Text(sample.label),
                          onPressed: () => Navigator.of(dialogContext).pop((
                            bytes: sample.bytes,
                            mime: sample.id == 'crimson'
                                ? 'image/png'
                                : 'image/jpeg',
                            remove: false,
                          )),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('avatar-custom-base64-input'),
                      controller: base64Controller,
                      decoration: const InputDecoration(
                        labelText: 'Custom base64 PNG/JPEG (optional)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('avatar-remove-button'),
                  onPressed: () =>
                      Navigator.of(dialogContext)
                          .pop((bytes: null, mime: null, remove: true)),
                  child: const Text('Reset default'),
                ),
                TextButton(
                  key: const Key('avatar-cancel-button'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('avatar-apply-custom-button'),
                  onPressed: () {
                    final raw = base64Controller.text.trim();
                    Uint8List bytes;
                    try {
                      bytes = raw.isEmpty ? Uint8List(0) : base64Decode(raw);
                    } catch (_) {
                      bytes = Uint8List.fromList(utf8.encode(raw));
                    }
                    Navigator.of(dialogContext)
                        .pop((bytes: bytes, mime: null, remove: false));
                  },
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
    base64Controller.dispose();
    if (picked == null || !mounted) return;

    if (picked.remove) {
      await testerSafeRun(
        () => ref.read(accountCustomAvatarProvider.notifier).removeAvatar(),
      );
      if (!mounted) return;
      setState(() {
        _avatarError = false;
        _avatarFeedback = 'Đã khôi phục ảnh đại diện mặc định.';
      });
      return;
    }

    final error = await testerSafeRun(
      () => ref
          .read(accountCustomAvatarProvider.notifier)
          .pickAndSaveAvatar(
            bytes: picked.bytes ?? Uint8List(0),
            declaredMimeType: picked.mime,
          ),
    );
    if (!mounted) return;
    setState(() {
      _avatarError = error != null;
      _avatarFeedback = error ?? 'Đã cập nhật ảnh đại diện.';
    });
  }

  Future<T> testerSafeRun<T>(Future<T> Function() action) => action();

  @override
  void initState() {
    super.initState();
    // Another device may have changed Auth profile since this session restored.
    // Defer the request until the first build, outside widget initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(authenticatedUidProvider) == widget.uid) {
        unawaited(ref.read(profileActionsProvider.notifier).refresh());
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (ref.read(authenticatedUidProvider) != widget.uid ||
        ref.read(profileActionsProvider).busy ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final saved = await ref
        .read(profileActionsProvider.notifier)
        .saveName(_name.text);
    if (!mounted || ref.read(authenticatedUidProvider) != widget.uid) return;
    if (saved) {
      _name.clear();
      setState(() => _editing = false);
    }
    // A failed save keeps the draft so the user can retry or cancel.
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authenticatedUserProvider);
    if (user == null || user.uid != widget.uid) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final state = ref.watch(profileActionsProvider);
    final actions = ref.read(profileActionsProvider.notifier);
    final customAvatar = ref.watch(accountCustomAvatarProvider).asData?.value;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    glowColor: context.colors.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Profile', style: context.text.headlineMedium),
                        const SizedBox(height: AppSpacing.lg),
                        Center(
                          child: ProfileAvatar(
                            key: ValueKey(
                              '${user.uid}:${user.photoUrl}:${customAvatar?.bytes.length ?? 0}',
                            ),
                            photoUrl: user.photoUrl,
                            imageBytes: customAvatar?.bytes,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton.icon(
                            key: const Key('profile-change-avatar'),
                            onPressed: state.busy
                                ? null
                                : _openAvatarPickerDialog,
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                            ),
                            label: const Text('Change avatar'),
                          ),
                        ),
                        if (_avatarFeedback != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _avatarFeedback!,
                              key: const Key('profile-avatar-feedback'),
                              textAlign: TextAlign.center,
                              style: context.text.bodySmall?.copyWith(
                                color: _avatarError
                                    ? context.colors.error
                                    : context.tokens.success,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const Text('Display name'),
                        SelectableText(
                          user.displayName?.isNotEmpty == true
                              ? user.displayName!
                              : 'No display name',
                          key: const Key('profile-current-name'),
                          style: context.text.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text('Email'),
                        SelectableText(user.email ?? 'No email'),
                        const SizedBox(height: AppSpacing.md),
                        const Text('UID'),
                        SelectableText(user.uid),
                        const SizedBox(height: AppSpacing.lg),
                        if (_editing)
                          Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const Key('profile-name-input'),
                                  controller: _name,
                                  enabled: !state.busy,
                                  validator: Validators.displayName,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _save(),
                                  decoration: const InputDecoration(
                                    labelText: 'New display name',
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GradientButton(
                                  key: const Key('profile-save'),
                                  label: 'Save display name',
                                  loading: state.saving,
                                  onPressed: state.busy ? null : _save,
                                ),
                                TextButton(
                                  key: const Key('profile-cancel'),
                                  onPressed: state.busy
                                      ? null
                                      : () {
                                          _name.clear();
                                          actions.clearFeedback();
                                          setState(() => _editing = false);
                                        },
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          )
                        else
                          GradientButton(
                            key: const Key('profile-edit'),
                            label: 'Edit display name',
                            onPressed: state.busy
                                ? null
                                : () {
                                    _name.text = user.displayName ?? '';
                                    actions.clearFeedback();
                                    setState(() => _editing = true);
                                  },
                          ),
                        if (state.message != null || state.error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            liveRegion: true,
                            child: Text(state.error ?? state.message!),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          key: const Key('profile-refresh'),
                          onPressed: state.busy || _editing
                              ? null
                              : actions.refresh,
                          icon: state.refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh profile'),
                        ),
                        TextButton(
                          key: const Key('profile-back'),
                          onPressed: state.busy
                              ? null
                              : () => context.go(AppRoutes.home),
                          child: const Text('Back to notes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
