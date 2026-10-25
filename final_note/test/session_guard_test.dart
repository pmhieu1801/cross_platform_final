import 'package:final_note/features/auth/application/auth_providers.dart';
import 'package:final_note/features/auth/domain/auth_repository.dart';
import 'package:final_note/routing/session_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

void main() {
  test('unresolved and failed sessions block every route without a loop', () {
    for (final phase in [SessionPhase.checking, SessionPhase.unavailable]) {
      for (final path in [
        '/home',
        '/notes/secret',
        '/login',
        '/register',
        '/',
      ]) {
        expect(sessionRedirect(phase, path), '/session');
      }
      expect(sessionRedirect(phase, '/session'), isNull);
    }
  });

  test(
    'public allowlist; signed-out deep links and unknown routes are blocked',
    () {
      for (final path in [
        '/home',
        '/notes/secret',
        '/unknown',
        '/session',
        '/',
      ]) {
        expect(sessionRedirect(SessionPhase.signedOut, path), '/login');
      }
      for (final path in ['/login', '/register']) {
        expect(sessionRedirect(SessionPhase.signedOut, path), isNull);
        expect(sessionRedirect(SessionPhase.signedIn, path), '/home');
      }
      expect(sessionRedirect(SessionPhase.signedIn, '/home'), isNull);
    },
  );

  test(
    'refresh/error after a previous user never supplies a usable UID',
    () async {
      final fake = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
      );
      addTearDown(() async {
        container.dispose();
        await fake.dispose();
      });
      container.listen(authSessionProvider, (_, _) {});
      await container.read(authRepositoryProvider.future);
      await Future<void>.delayed(Duration.zero);
      fake.events.add(userA);
      await container.read(authSessionProvider.future);
      expect(container.read(authenticatedUidProvider), userA.uid);
      container.invalidate(authSessionProvider);
      final loading = container.read(authSessionProvider);
      expect(loading.isLoading, isTrue);
      expect(loading.hasValue, isTrue); // Riverpod retains the previous result.
      expect(sessionPhase(loading), SessionPhase.checking);
      expect(container.read(authenticatedUidProvider), isNull);
      expect(container.read(accountSessionProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      fake.events.addError(StateError('stream failed'));
      await Future<void>.delayed(Duration.zero);
      expect(
        sessionPhase(container.read(authSessionProvider)),
        SessionPhase.unavailable,
      );
      expect(container.read(authenticatedUidProvider), isNull);
      expect(container.read(accountSessionProvider), isNull);
    },
  );

  test(
    'Firebase error mapping covers duplicate email, network and credentials',
    () {
      expect(
        authErrorMessage('email-already-in-use'),
        contains('đã được đăng ký'),
      );
      expect(authErrorMessage('network-request-failed'), contains('mạng'));
      expect(
        authErrorMessage('invalid-credential'),
        authErrorMessage('user-not-found'),
      );
      expect(authErrorMessage('unknown'), contains('thử lại'));
    },
  );
}
