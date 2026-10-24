import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_guard.dart';
import '../application/auth_providers.dart';

class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key, required this.register});
  final bool register;
  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authActionsProvider).busy || !_form.currentState!.validate()) {
      return;
    }
    final actions = ref.read(authActionsProvider.notifier);
    if (widget.register) {
      await actions.register(_email.text, _name.text, _password.text);
    } else {
      await actions.signIn(_email.text, _password.text);
    }
    // The session stream owns navigation, never a successful Future alone.
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionsProvider);
    final title = widget.register ? 'Tạo tài khoản' : 'Đăng nhập';
    return Scaffold(
      appBar: AppBar(title: const Text('NoteFlow')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('email'),
                      controller: _email,
                      enabled: !action.busy,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Nhập email hợp lệ.',
                    ),
                    if (widget.register) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('displayName'),
                        controller: _name,
                        enabled: !action.busy,
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                        ),
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Nhập tên hiển thị.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('password'),
                      controller: _password,
                      enabled: !action.busy,
                      decoration: const InputDecoration(labelText: 'Mật khẩu'),
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: [
                        widget.register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: widget.register
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nhập mật khẩu.';
                        }
                        if (widget.register && value.length < 6) {
                          return 'Mật khẩu cần ít nhất 6 ký tự.';
                        }
                        return null;
                      },
                    ),
                    if (widget.register) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('confirmation'),
                        controller: _confirmation,
                        enabled: !action.busy,
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu',
                        ),
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value != _password.text
                            ? 'Mật khẩu nhập lại chưa khớp.'
                            : null,
                      ),
                    ],
                    if (action.error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          action.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('submit'),
                      onPressed: action.busy ? null : _submit,
                      child: action.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(title),
                    ),
                    TextButton(
                      onPressed: action.busy
                          ? null
                          : () {
                              ref
                                  .read(authActionsProvider.notifier)
                                  .clearError();
                              context.go(
                                widget.register
                                    ? AppRoutes.login
                                    : AppRoutes.register,
                              );
                            },
                      child: Text(
                        widget.register
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
