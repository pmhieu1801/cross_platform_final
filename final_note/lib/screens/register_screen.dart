import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/validators.dart';
import '../widgets/widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onSubmit,
    this.onSignIn,
    this.isLoading = false,
    this.error,
  });

  final Future<void> Function(String email, String name, String password)?
  onSubmit;
  final VoidCallback? onSignIn;
  final bool isLoading;
  final String? error;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  PasswordStrength _strength = PasswordStrength.empty;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _strength = evaluatePasswordStrength(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.isLoading || !_formKey.currentState!.validate()) return;
    final submit = widget.onSubmit;
    if (submit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication is not configured.')),
      );
      return;
    }
    await submit(
      _emailController.text,
      _nameController.text,
      _passwordController.text,
    );
    // Account creation signs in through Firebase; the router observes the session.
  }

  void _returnToLogin() {
    if (widget.isLoading) return;
    if (widget.onSignIn != null) {
      widget.onSignIn!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to sign in',
          onPressed: widget.isLoading ? null : _returnToLogin,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 860;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? AppSpacing.xxl : AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 960 : 440,
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildHeroShowcase(context),
                              ),
                              const SizedBox(width: AppSpacing.xxl),
                              Expanded(flex: 6, child: _buildFormCard(context)),
                            ],
                          )
                        : _buildFormCard(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroShowcase(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandBadge(size: 52),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Make room for\nyour thoughts.',
            style: text.displaySmall?.copyWith(
              fontFamily: AppTypography.display,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Join NoteFlow today. Organize your knowledge, collaborate in real time, and let AI summarize your ideas.',
            style: text.bodyLarge?.copyWith(color: tokens.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _HighlightItem(
            icon: Icons.sync_rounded,
            title: 'Always synchronized',
            description: 'Notes update instantly across all your devices.',
          ),
          const SizedBox(height: AppSpacing.md),
          _HighlightItem(
            icon: Icons.shield_outlined,
            title: 'Privacy focused',
            description: 'Individual password locks for your private journals.',
          ),
          const SizedBox(height: AppSpacing.md),
          _HighlightItem(
            icon: Icons.palette_outlined,
            title: 'Beautiful experience',
            description: 'Midnight Glow theme designed for focus and clarity.',
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final text = context.text;
    final tokens = context.tokens;
    final colors = context.colors;

    return GlassPanel(
      glowColor: colors.secondary,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: BrandBadge()),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Make room for your thoughts',
              style: text.headlineMedium?.copyWith(
                fontFamily: AppTypography.display,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create an account and keep all your notes together.',
              style: text.bodyMedium?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Display name
            Text(
              'Display name',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('register-name'),
              enabled: !widget.isLoading,
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                hintText: 'How should we call you?',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: Validators.displayName,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Email address
            Text(
              'Email address',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('register-email'),
              enabled: !widget.isLoading,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Password
            Text(
              'Password',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('register-password'),
              enabled: !widget.isLoading,
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                hintText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: widget.isLoading
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: Validators.newPassword,
            ),
            PasswordStrengthBar(strength: _strength),
            const SizedBox(height: AppSpacing.md),

            // Confirm Password
            Text(
              'Confirm password',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('register-confirm-password'),
              enabled: !widget.isLoading,
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmation,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter your password again',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation
                      ? 'Show confirmation password'
                      : 'Hide confirmation password',
                  onPressed: widget.isLoading
                      ? null
                      : () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Confirm your password.';
                }
                if (val != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            if (widget.error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.error!,
                  style: TextStyle(color: colors.error),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            GradientButton(
              key: const Key('register-submit'),
              label: 'Create account',
              loading: widget.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: text.bodyMedium?.copyWith(color: tokens.textMuted),
                ),
                TextButton(
                  onPressed: widget.isLoading ? null : _returnToLogin,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Sign in',
                    style: text.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your notes are yours. We’ll always treat them that way.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  const _HighlightItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tokens = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.secondary.withValues(alpha: 0.14),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: colors.secondary.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 20, color: colors.secondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                description,
                style: text.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
