import 'dart:async';

import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;

  setUp(() async {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
    );
    container.listen(authSessionProvider, (_, _) {});
    await container.read(authRepositoryProvider.future);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await fake.dispose();
  });

  test('duplicate actions are ignored; network failure clears busy and preserves signed-out session', () async {
    fake.events.add(null);
    await container.read(authSessionProvider.future);
    fake.pending = Completer<void>();
    fake.failure = const AuthFailure('Không kết nối được mạng. Hãy thử lại.');
    final actions = container.read(authActionsProvider.notifier);
    final first = actions.signIn(' a@example.test ', 'test-only');
    await actions.signIn('a@example.test', 'test-only');
    await Future<void>.delayed(Duration.zero);
    expect(fake.signInCalls, 1);
    expect(container.read(authActionsProvider).busy, isTrue);
    fake.pending!.complete();
    await first;
    expect(container.read(authActionsProvider).busy, isFalse);
    expect(container.read(authActionsProvider).error, contains('mạng'));
    expect(container.read(authenticatedUidProvider), isNull);
    expect(fake.receivedEmail, 'a@example.test');
  });

  test(
    'A to B to signed-out closes leases and disposes dependent listeners',
    () async {
      final disposed = <String>[];
      final dependent = Provider<String?>((ref) {
        final session = ref.watch(accountSessionProvider);
        if (session == null) return null;
        ref.onDispose(() => disposed.add(session.uid));
        return session.uid;
      });
      container.listen(dependent, (_, _) {}, fireImmediately: true);
      fake.events.add(userA);
      await container.read(authSessionProvider.future);
      expect(container.read(dependent), userA.uid);
      final leaseA = container.read(accountSessionProvider)!;
      fake.events.add(userB);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dependent), userB.uid);
      final leaseB = container.read(accountSessionProvider)!;
      expect(leaseA.isActive, isFalse);
      expect(disposed, [userA.uid]);
      await container.read(authActionsProvider.notifier).signOut();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(dependent), isNull);
      expect(leaseB.isActive, isFalse);
      expect(disposed, [userA.uid, userB.uid]);
      expect(container.read(authActionsProvider).error, isNull);
    },
  );

  test(
    'stream error removes current account; retry sign-in can recover',
    () async {
      fake.events.add(userA);
      await container.read(authSessionProvider.future);
      final subscription = container.listen(accountSessionProvider, (_, _) {});
      final lease = subscription.read()!;
      fake.events.addError(StateError('listener error'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authenticatedUidProvider), isNull);
      expect(container.read(accountSessionProvider), isNull);
      expect(lease.isActive, isFalse);
      fake.events.add(userB);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authenticatedUidProvider), userB.uid);
    },
  );
}
