import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/verification_providers.dart';

/// Lives in the private shell; verification is advisory and never blocks access.
class VerificationBanner extends ConsumerStatefulWidget {
  const VerificationBanner({super.key, required this.uid});
  final String uid;

  @override
  ConsumerState<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends ConsumerState<VerificationBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(verificationActionsProvider(widget.uid).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authenticatedUserProvider);
    if (user == null || user.uid != widget.uid || user.emailVerified) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(verificationActionsProvider(widget.uid));
    final actions = ref.read(verificationActionsProvider(widget.uid).notifier);
    final busy = state.busy || ref.watch(authActionsProvider).busy;
    return Card(
      key: const Key('verification-banner'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email chưa được xác minh. Vui lòng hoàn tất xác minh email. '
              'Bạn vẫn có thể sử dụng ứng dụng.',
            ),
            const SizedBox(height: 8),
            if (user.email != null) ...[
              Text('Địa chỉ nhận: ${user.email}'),
              const SizedBox(height: 8),
            ],
            const Text(
              'Mở link trong email bằng trình duyệt, sau đó quay lại ứng dụng '
              'và chọn “Kiểm tra xác minh”.',
            ),
            if (state.message != null || state.error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(state.error ?? state.message!),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('verification-resend'),
                  onPressed: busy || state.coolingDown ? null : actions.resend,
                  child: Text(
                    state.sending
                        ? 'Đang gửi…'
                        : state.coolingDown
                        ? 'Vui lòng đợi trước khi gửi lại'
                        : 'Gửi lại email',
                  ),
                ),
                TextButton(
                  key: const Key('verification-refresh'),
                  onPressed: busy ? null : actions.refresh,
                  child: Text(
                    state.refreshing ? 'Đang kiểm tra…' : 'Kiểm tra xác minh',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
