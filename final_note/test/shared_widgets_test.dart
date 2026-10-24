import 'package:final_note/theme/theme.dart';
import 'package:final_note/utils/validators.dart';
import 'package:final_note/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Shared UI State Views', () {
    testWidgets('EmptyStateView renders title, message and triggers action', (
      tester,
    ) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        _wrap(
          EmptyStateView(
            title: 'No notes yet',
            message: 'Create your first note to get started.',
            actionLabel: 'New Note',
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.text('Create your first note to get started.'), findsOneWidget);
      expect(find.text('New Note'), findsOneWidget);

      await tester.tap(find.text('New Note'));
      await tester.pumpAndSettle();

      expect(actionTriggered, isTrue);
    });

    testWidgets('ErrorStateView renders message and triggers retry', (
      tester,
    ) async {
      var retryTriggered = false;

      await tester.pumpWidget(
        _wrap(
          ErrorStateView(
            message: 'Failed to load notes.',
            onRetry: () => retryTriggered = true,
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to load notes.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(retryTriggered, isTrue);
    });

    testWidgets('LoadingStateView renders progress indicator and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LoadingStateView(message: 'Syncing your notes...'),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Syncing your notes...'), findsOneWidget);
    });

    testWidgets('PasswordStrengthBar shows correct label for strength', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PasswordStrengthBar(strength: PasswordStrength.good),
        ),
      );

      expect(find.text('Password strength'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
    });
  });
}
