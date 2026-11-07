import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:final_note/features/auth/application/auth_providers.dart';

import 'support/fake_auth_repository.dart';

import 'package:final_note/main.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/screens/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> pumpSignedOut(WidgetTester tester) async {
    final fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWith((ref) async => fake)],
    );
    addTearDown(() async {
      container.dispose();
      await fake.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NoteFlowApp(),
      ),
    );
    await container.read(authRepositoryProvider.future);
    await tester.pump();
    fake.events.add(null);
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the sign-in screen', (tester) async {
    await pumpSignedOut(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
  });

  testWidgets('registration can be opened and returns to sign in', (
    tester,
  ) async {
    await pumpSignedOut(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byKey(const Key('register-name')), findsOneWidget);
    expect(find.byKey(const Key('register-confirm-password')), findsOneWidget);

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign-in form shows an email validation message', (tester) async {
    await pumpSignedOut(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('registration rejects passwords that do not match', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.enterText(find.byKey(const Key('register-name')), 'Sam');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'sam@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password')),
      'different123',
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('notes dashboard search filters title and content', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotesHomeScreen()));

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();

    expect(find.text('Ideas for the weekend'), findsOneWidget);
    expect(find.text('Project kickoff'), findsNothing);
  });

  testWidgets('notes dashboard switches to list view', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesHomeScreen()));

    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();

    expect(find.text('Project kickoff'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('notes dashboard can create a new note', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesHomeScreen()));

    await tester.tap(find.byKey(const Key('create-note-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-title-input')), 'Launch plan');
    await tester.enterText(
      find.byKey(const Key('note-content-input')),
      'Finalize the roadmap and confirm milestones with the team.',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Launch plan'), findsOneWidget);
  });

  testWidgets('notes are auto-saved to local storage', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotesHomeScreen()));

    await tester.tap(find.byKey(const Key('create-note-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-title-input')), 'Saved note');
    await tester.enterText(
      find.byKey(const Key('note-content-input')),
      'This should persist',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString('noteflow_notes_v1');

    expect(payload, isNotNull);
    expect(payload, contains('Saved note'));
    expect(payload, contains('This should persist'));
  });
}
