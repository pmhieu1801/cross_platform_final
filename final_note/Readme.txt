================================================================================
503107 - CROSS-PLATFORM MOBILE APPLICATION DEVELOPMENT - FINAL PROJECT
Application Name : NoteFlow (final_note)
Semester         : Semester I / 2026-2027
Repository       : https://github.com/pmhieu1801/cross_platform_final
================================================================================

1. TEAM MEMBERS & ROLES
-----------------------
- Member 1 (M1): Phạm Minh Hiếu (GitHub: pmhieu1801)
  Authentication, Session Guard, Profile & Avatar Validation, Change Password,
  Account-Scoped User Preferences (Theme, Font Size, Default View Mode).
- Member 2 (M2): Huỳnh Nhật Tiến (GitHub: hnt0411)
  Notes CRUD, Auto-Save & AppLifecycle Flush, Grid/List Layouts, Pin/Unpin,
  Real-Time Search, Multi-Label Filtering & Label CRUD, Media/File Attachments,
  Special-Note Status Indicators (R18).
- Member 3 (M3) / Integrated Features:
  Individual Note Password Protection (Salted Hashing, Lock/Unlock, Change/Disable),
  Email-Based Note Sharing (Read-Only & Edit Permissions, "Shared with me"
  Section, Real-Time Collaboration Updates), AI Summary with Regenerate,
  AI Question Answering with Clickable Source-Note References, Offline Sync &
  Conflict Resolution.

2. SDK VERSIONS & SUPPORTED TARGET PLATFORMS
--------------------------------------------
- Flutter SDK : >= 3.29.0 (tested with Flutter 3.41.x / Dart >= 3.11.0 < 4.0.0)
- Dart SDK    : ^3.11.0
- Supported Platforms:
  1. Web (Chrome / Edge / Safari) — Primary web target
  2. Android (Phone & Tablet, minSdk 21+) — Primary mobile target
  3. macOS / Windows / iOS (Responsive desktop & mobile adaptive layouts)

3. ARCHITECTURE & STATE MANAGEMENT OVERVIEW
-------------------------------------------
- Architecture Pattern:
  Feature-first layered Clean Architecture under `lib/`:
  * `lib/core/`         : Environment & Firebase configuration (`FirebaseConfig`).
  * `lib/features/auth/`: Authentication domain contracts (`AuthRepository`,
                          `AvatarRepository`), Firebase & local implementations
                          (`FirebaseAuthRepository`, `LocalAvatarRepository`),
                          `AvatarImageValidator`, Riverpod controllers, and UI
                          screens (`AuthForm`, `ForgotPasswordScreen`,
                          `ProfileScreen`, `ChangePasswordScreen`).
  * `lib/features/notes/`: Account-scoped note & label domain contract
                          (`NoteRepository`), `LocalNoteRepository` with
                          `SharedPreferencesNoteStore`, attachment validation
                          (`NoteAttachmentValidator`), salted password hashing
                          (`NotePasswordSecurity`), AI summary & Q&A service
                          (`NoteAiService`), and Riverpod stream/action providers.
  * `lib/features/preferences/`: Account-scoped preferences domain
                          (`UserPreferences`), `LocalPreferencesRepository`,
                          and `PreferencesScreen`.
  * `lib/routing/`      : `GoRouter` configuration (`app_router.dart`) and
                          route-level authentication guard (`session_guard.dart`).
  * `lib/screens/` & `lib/widgets/`: Adaptive UI (`NotesHomeScreen`,
                          `NoteEditorPanel`, `NotePasswordDialogs`,
                          `NoteShareDialog`, `NoteAiQaDialog`).
- State Management:
  `flutter_riverpod` (`Provider`, `FutureProvider`, `StreamProvider.autoDispose`,
  `NotifierProvider`, `AsyncNotifierProvider`). All user data streams and caches
  depend on `accountSessionProvider` (keyed by authenticated Firebase `uid`),
  automatically cancelling subscriptions and disposing state on logout or
  account switch so cross-account data leakage is impossible.

4. LOCAL PERSISTENCE, OFFLINE SYNC & CONFLICT-HANDLING STRATEGY (R31)
---------------------------------------------------------------------
- Local Persistence Solution:
  `SharedPreferences` with schema-versioned JSON snapshots partitioned strictly
  by base64url-encoded Firebase `uid`:
  * Notes & Labels : `noteflow_account_notes_v1_<base64url(uid)>`
  * Preferences    : `noteflow.preferences.v1.<base64url(uid)>`
  * Custom Avatars : `noteflow_account_avatar_v1_<base64url(uid)>`
- Offline-First Auto-Save & Sync Lifecycle:
  * Every note create/edit/pin/label/attachment/password/share mutation writes
    immediately to local storage with `NoteSyncStatus.pending` and displays
    a live `NoteSyncStatusIndicator` (`Pending sync`, `Synced`, or `Sync failed`).
  * `NoteEditorPanel` debounces edits (400 ms) and registers an
    `AppLifecycleListener` (`onInactive`, `onHide`, `onPause`, `onDetach`) to
    flush unsaved drafts immediately when the app goes to background or closes.
  * Users can toggle `Offline mode` / `Online` and trigger `Sync now` in the
    `My Notes` header to synchronize pending notes (`synchronizeNotes(uid)`).
- Conflict-Handling Strategy (`LocalNoteRepository.resolveConflict`):
  * Deterministic Last-Write-Wins (LWW) based on `Note.updatedAt` timestamp to
    select the winning metadata (`title`, `colorIndex`, `status`, `isPinned`).
  * Non-destructive body & collection merge: if the older conflicting version
    contains distinct non-empty text not present in the newer version, its body
    is appended under a `--- [Conflict backup from <ISO-timestamp>] ---` divider,
    and both versions' labels and attachments are union-merged so zero user work
    is ever lost.

5. THIRD-PARTY PACKAGES & PURPOSE
---------------------------------
- `firebase_core` (^4.6.0)       : Firebase SDK initialization across platforms.
- `firebase_auth` (^6.3.0)       : Email/Password sign-in, registration, email
                                   verification, password reset, reauthentication.
- `flutter_riverpod` (^2.6.1)    : Reactive, account-scoped state management.
- `go_router` (^14.8.1)          : Declarative routing and `sessionRedirect` guard.
- `shared_preferences` (^2.5.3)  : Local offline persistence per UID.
- `http` (^1.2.2)                : Optional HTTPS client for Gemini AI REST API.
- `cupertino_icons` (^1.0.8)     : Platform icon support.

6. CONFIGURATION FILES & ENVIRONMENT VARIABLES (NO HARD-CODED SECRETS)
----------------------------------------------------------------------
- All runtime secrets and API keys are injected via `--dart-define` or
  `--dart-define-from-file` (never hard-coded in Dart source code):
  * Template file: `final_note/.env.example`
  * Firebase Web config file: `final_note/config/firebase.web.json`
    Keys:
    - `FIREBASE_API_KEY`
    - `FIREBASE_APP_ID`
    - `FIREBASE_MESSAGING_SENDER_ID`
    - `FIREBASE_PROJECT_ID`
    - `FIREBASE_AUTH_DOMAIN`
    - `FIREBASE_STORAGE_BUCKET`
  * Optional Gemini AI key for live LLM calls (falls back automatically to the
    built-in deterministic offline extractive engine when omitted):
    - `GEMINI_API_KEY`
    - `GEMINI_MODEL` (default: `gemini-2.5-flash`)

7. EXACT COMMANDS TO INSTALL, TEST, RUN & BUILD RELEASE ARTIFACTS
-----------------------------------------------------------------
All commands below should be executed from the `final_note/` directory:

  cd final_note

A) Install dependencies:
  flutter pub get

B) Static analysis & formatting check:
  dart format --output=none --set-exit-if-changed lib test integration_test
  flutter analyze

C) Run automated unit & widget test suite (138+ tests):
  flutter test

D) Run on Web (Chrome):
  flutter run -d chrome --dart-define-from-file=config/firebase.web.json

   (Optional: with live Gemini API key)
  flutter run -d chrome \
    --dart-define-from-file=config/firebase.web.json \
    --dart-define=GEMINI_API_KEY=your_gemini_api_key

E) Run on Android emulator / connected device:
  flutter run -d android --dart-define-from-file=config/firebase.web.json

F) Build Release Artifacts:
  - Web Release Build:
    flutter build web --release --dart-define-from-file=config/firebase.web.json

  - Android APK Release Build:
    flutter build apk --release --dart-define-from-file=config/firebase.web.json

8. TEST / GRADING ACCOUNTS & QUICK VERIFICATION GUIDE
-----------------------------------------------------
- Reviewers can register any two accounts directly from the `/register` screen
  (Firebase Email/Password authentication is live on project `final-432b3`), or
  use pre-registered test accounts:
  * Account 1 (Owner)Collaborator: `student1@noteflow.test` / `Password123!`
  * Account 2 (Collaborator)     : `student2@noteflow.test` / `Password123!`
- Note Password Protection (R23/R24):
  Open any note -> click the Lock icon (`Protect note with password`) -> enter
  and confirm a password (minimum 4 characters). Use `Lock now` inside the lock
  settings dialog to test unlocking and search-content masking.
- Note Sharing & Real-Time Collaboration (R25/R26):
  Open any note -> click the Share icon (`Share note`) -> enter a collaborator's
  email address and choose `Read-only` or `Can edit`. Sign in as the recipient
  account and open the `Shared with me` tab in the sidebar/bottom navigation.
- AI Summary (R27) & AI Question Answering (R28):
  * Inside any note editor, click the Sparkle icon (`AI Summary`) in the top
    toolbar, then click `Regenerate` to cycle through summary perspectives.
  * On the main `My Notes` screen, click `Ask AI` next to the search bar, type
    a question or click a suggested question chip, and click any cited source
    note chip to open that exact note directly.
================================================================================
