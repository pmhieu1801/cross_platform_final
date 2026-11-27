enum PreferenceThemeMode { dark, light, system }

enum NotesViewMode { grid, list }

class UserPreferences {
  const UserPreferences({
    this.themeMode = PreferenceThemeMode.dark,
    this.noteFontScale = 1,
    this.notesViewMode = NotesViewMode.grid,
  });
  final PreferenceThemeMode themeMode;
  final double noteFontScale;
  final NotesViewMode notesViewMode;

  static const defaults = UserPreferences();
  static const minFontScale = 0.85;
  static const maxFontScale = 1.5;
  bool get isValid =>
      noteFontScale.isFinite &&
      noteFontScale >= minFontScale &&
      noteFontScale <= maxFontScale;

  UserPreferences copyWith({
    PreferenceThemeMode? themeMode,
    double? noteFontScale,
    NotesViewMode? notesViewMode,
  }) => UserPreferences(
    themeMode: themeMode ?? this.themeMode,
    noteFontScale: noteFontScale ?? this.noteFontScale,
    notesViewMode: notesViewMode ?? this.notesViewMode,
  );

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'themeMode': themeMode.name,
    'noteFontScale': noteFontScale,
    'notesViewMode': notesViewMode.name,
  };

  factory UserPreferences.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw['themeMode'] is! String ||
        raw['notesViewMode'] is! String ||
        raw['noteFontScale'] is! num) {
      throw const FormatException('Invalid preferences schema.');
    }
    try {
      final value = UserPreferences(
        themeMode: PreferenceThemeMode.values.byName(
          raw['themeMode'] as String,
        ),
        noteFontScale: (raw['noteFontScale'] as num).toDouble(),
        notesViewMode: NotesViewMode.values.byName(
          raw['notesViewMode'] as String,
        ),
      );
      if (!value.isValid) {
        throw const FormatException('Invalid preferences scale.');
      }
      return value;
    } on ArgumentError {
      throw const FormatException('Invalid preferences enum.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.themeMode == themeMode &&
      other.noteFontScale == noteFontScale &&
      other.notesViewMode == notesViewMode;
  @override
  int get hashCode => Object.hash(themeMode, noteFontScale, notesViewMode);
}

class PreferencesLoadResult {
  const PreferencesLoadResult(this.value, {this.recoveredCorruption = false});
  final UserPreferences value;
  final bool recoveredCorruption;
}

class PreferencesFailure implements Exception {
  const PreferencesFailure(this.message);
  final String message;
}

abstract interface class PreferencesRepository {
  Future<PreferencesLoadResult> load(String uid);
  Future<void> save(String uid, UserPreferences value);
}
