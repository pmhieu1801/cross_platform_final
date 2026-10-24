import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_note/main.dart';

void main() {
  testWidgets('shows the responsive notes dashboard', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

    expect(find.text('NoteFlow'), findsOneWidget);
    expect(find.text('Your notes'), findsOneWidget);
    expect(find.text('Ideas for the weekend'), findsOneWidget);
    expect(find.byTooltip('Grid view'), findsOneWidget);
  });

  testWidgets('search filters notes by title and content', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();

    expect(find.text('Ideas for the weekend'), findsOneWidget);
    expect(find.text('Project kickoff'), findsNothing);
  });

  testWidgets('label chips filter notes', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

    await tester.tap(find.widgetWithText(FilterChip, 'Work'));
    await tester.pumpAndSettle();

    expect(find.text('Project kickoff'), findsOneWidget);
    expect(find.text('Ideas for the weekend'), findsNothing);
  });

  testWidgets('switches to list view', (tester) async {
    await tester.pumpWidget(const NoteFlowApp());

    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();

    expect(find.text('Project kickoff'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });
}
