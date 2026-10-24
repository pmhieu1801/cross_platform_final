import 'package:final_note/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('dark and light themes expose NoteFlowTokens', () {
      expect(AppTheme.dark.extension<NoteFlowTokens>(), isNotNull);
      expect(AppTheme.light.extension<NoteFlowTokens>(), isNotNull);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
    });

    test('noteAccent wraps any index safely', () {
      const tokens = NoteFlowTokens.dark;
      final count = tokens.noteAccents.length;
      expect(tokens.noteAccent(0), tokens.noteAccents.first);
      expect(tokens.noteAccent(count), tokens.noteAccents.first);
      expect(tokens.noteAccent(-1), tokens.noteAccents[1]);
    });

    test('breakpoints map widths to window sizes', () {
      expect(AppBreakpoints.of(390), WindowSize.compact);
      expect(AppBreakpoints.of(800), WindowSize.medium);
      expect(AppBreakpoints.of(1280), WindowSize.expanded);
      expect(AppBreakpoints.of(1920), WindowSize.large);
    });
  });
}
