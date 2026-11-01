import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_providers.dart';
import '../auth/presentation/verification_banner.dart';

/// W1 destination only. Notes UI/repositories belong to M2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authenticatedUserProvider);
    // Also block the frame before the router processes a redirect.
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final action = ref.watch(authActionsProvider);
    final account = ref.watch(accountSessionProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('NoteFlow')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            key: ValueKey(account.uid),
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (!user.emailVerified) ...[
                VerificationBanner(key: ValueKey(user.uid), uid: user.uid),
                const SizedBox(height: 24),
              ],
              Text(
                'Xin chào, ${user.displayName ?? user.email ?? 'bạn'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SelectableText('Firebase UID: ${user.uid}'),
              const SizedBox(height: 24),
              const Text('Chào mừng đến với NoteFlow.'),
              if (action.error != null) ...[
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: Text(action.error!)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('logout'),
                onPressed: action.busy
                    ? null
                    : ref.read(authActionsProvider.notifier).signOut,
                icon: const Icon(Icons.logout),
                label: Text(action.busy ? 'Đang xử lý…' : 'Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
