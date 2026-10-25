import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../utils/validators.dart';
import '../widgets/widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onSubmit,
    this.onCreateAccount,
    this.isLoading = false,
    this.error,
  });

  final Future<void> Function(String email, String password)? onSubmit;
  final VoidCallback? onCreateAccount;
  final bool isLoading;
  final String? error;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    await submit(_emailController.text, _passwordController.text);
    // Session stream and router own navigation after authentication.
  }

  void _openRegistration() {
    if (widget.isLoading) return;
    if (widget.onCreateAccount != null) {
      widget.onCreateAccount!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const RegisterScreen()),
    );
  }

  void _showResetNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password recovery will be available when authentication is set up.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            'Capture thoughts.\nIlluminate ideas.',
            style: text.displaySmall?.copyWith(
              fontFamily: AppTypography.display,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A modern, beautiful, and secure workspace for all your notes, ideas, and real-time collaboration.',
            style: text.bodyLarge?.copyWith(color: tokens.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _HeroFeatureItem(
            icon: Icons.bolt_rounded,
            title: 'Real-time & Offline Ready',
            subtitle:
                'Access and edit seamlessly everywhere, even without internet.',
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroFeatureItem(
            icon: Icons.auto_awesome_rounded,
            title: 'AI Smart Summary',
            subtitle:
                'Condense long thoughts and ask questions with source notes.',
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroFeatureItem(
            icon: Icons.lock_outline_rounded,
            title: 'Protected & Private',
            subtitle: 'End-to-end password locks on your most sensitive notes.',
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
      glowColor: colors.primary,
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
              'Welcome back',
              style: text.headlineMedium?.copyWith(
                fontFamily: AppTypography.display,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign in to pick up where your thoughts left off.',
              style: text.bodyMedium?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Email address',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('login-email'),
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
            Row(
              children: [
                Text(
                  'Password',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.isLoading ? null : _showResetNotice,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: text.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              key: const Key('login-password'),
              enabled: !widget.isLoading,
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter your password',
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
              validator: Validators.requiredPassword,
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
              key: const Key('login-submit'),
              label: 'Sign in',
              loading: widget.isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: Divider(color: colors.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'NEW TO NOTEFLOW?',
                    style: text.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: colors.outlineVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: widget.isLoading ? null : _openRegistration,
              child: const Text('Create an account'),
            ),
            const SizedBox(height: AppSpacing.lg),
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

class _HeroFeatureItem extends StatelessWidget {
  const _HeroFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
            color: colors.primary.withValues(alpha: 0.14),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
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
                subtitle,
                style: text.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
