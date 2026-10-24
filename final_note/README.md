# NoteFlow - Auth foundation (M1 W1)

One Flutter project for Web and Android. This change replaces the counter starter with Firebase Email/Password registration, login/logout, session restoration, guarded routes and a minimal private home showing the Firebase UID. Notes and backend data rules are owned by M2/M3 and are not implemented here.

## Environment and setup

Verified toolchain: Flutter 3.47.0 stable / Dart 3.13.0; Android SDK/build-tools 36.0.0; Android Studio JBR 25.0.2. Use the committed pubspec.lock. Run Flutter commands from this final_note directory; the Git repository root is its parent.

Firebase project: noteflow-3f90d. Email/Password is enabled. config/firebase.web.json and config/firebase.android.json contain actual non-privileged client identifiers, with distinct app IDs for each platform. Android package: com.example.final_note. See config/README.md for configuration details. Do not put service-account keys, passwords, tokens or server API keys in client config or source.

Initialization uses explicit FirebaseOptions. Missing configuration shows a setup error and does not simulate authentication. Firebase SDK persistence is retained; session state comes from userChanges(), which includes authStateChanges events. Registration asks for email, display name, password and confirmation; unverified accounts can enter the app with a persistent banner. Sending/handling activation links is deferred to W2.

## Run and verify

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test --reporter expanded
flutter run -d chrome --dart-define-from-file=config/firebase.web.json
flutter run -d <android-device-id> --dart-define-from-file=config/firebase.android.json
flutter build web --release --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --dart-define-from-file=config/firebase.android.json
```

On Windows, Flutter pub may require symlink support/Developer Mode or appropriate system permissions. Configure that according to the machine policy. After dependencies are resolved, --no-pub can be used for analyze/test/build.

Web uses hash routes: /#/login and /#/register are public; /#/home and new feature routes require a confirmed session. Loading/error sessions go to /#/session. A route guard protects UI; M3 must still enforce authorization in backend/security rules.

## Architecture and integration

lib/features/auth/domain defines AuthUser and AuthRepository. The data adapter calls Firebase; application providers expose session/UID/action state; presentation contains forms. lib/routing owns redirects. Widgets do not act as the authentication source of truth.

M2/M3 should watch authenticatedUidProvider or accountSessionProvider from auth_providers.dart. Watch accountSessionProvider in account-bound services, cancel subscriptions/timers with ref.onDispose, and ignore late callbacks if the old account lease is inactive. Partition cache/queue data by UID; a widget key does not clear backend or local-store data by itself.

## Validation and limits

Format/analyzer are clean; 12 isolated tests pass. They cover guard/loading/refresh/error, form validation, duplicate submit/network failure, logout and account lease disposal. Test fakes exist only under test/; production uses FirebaseAuthRepository.

Web registration/UID, correct and incorrect login, duplicate email, reload persistence, logout/Back/private URL and switching accounts were checked against real Firebase. Web release and Android debug APK builds succeeded from the same source. Android runtime/persistence and real network-disconnection behavior remain unverified because ADB was offline or failed to read device properties. A build or fake test is not proof of Firebase behavior on Android.

No Gate W1/Done claim: Android runtime verification and M2/M3 contract review are still required. No Notes, sharing, lock, attachments, offline sync or AI is included. Public HTTPS deployment and native release signing are later work; build/cache/tmp outputs are ignored.
