import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../../../theme/theme.dart';
import '../../../utils/validators.dart';
import '../../../widgets/widgets.dart';
import '../application/auth_providers.dart';
import '../application/profile_controller.dart';
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
                            key: ValueKey('${user.uid}:${user.photoUrl}'),
                            photoUrl: user.photoUrl,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
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
