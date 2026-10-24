import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_note/main.dart';
import 'package:final_note/screens/notes_home_screen.dart';
import 'package:final_note/screens/register_screen.dart';

void main() {
  testWidgets('opens on the sign-in screen', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
  });

  testWidgets('registration can be opened and returns to sign in', (
    tester,
  ) async {
    await tester.pumpWidget(const NoteFlowApp());

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byKey(const Key('register-name')), findsOneWidget);
    expect(find.byKey(const Key('register-confirm-password')), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sign-in form shows an email validation message', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

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
}
