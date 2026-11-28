# W2-07 — M1 regression and release evidence

The M1 branch includes `64034d1`, which brings in the M2 file picker,
5 MiB avatar input limit, sidebar and account dialog updates, and thumbnail
normalization shared by local and cloud avatars.

## Verified on the updated M1 code

| Check | Result |
| --- | --- |
| `flutter pub get` | Resolved Firestore while retaining the existing Firebase Auth and file picker versions. |
| `flutter analyze --no-pub` | No issues. |
| `flutter test --no-pub` | 145 unit and widget tests passed. Avatar cases cover legacy fallback, cross-session reads and reset, retaining the previous avatar on a failed write, and portrait thumbnail bounds. |
| Flutter Web release | Built successfully with the Web Firebase config and `FIREBASE_CLOUD_AVATARS=true`. |
| Flutter Android release | Built and signed version 1.0.0 (1) with the Android Firebase config and cloud avatars enabled. APK Signature Scheme v2, Android API 24 minimum and target API 36 were verified. |
| Firebase Emulator Suite | Registration, activation, email reset and manual sign-in passed. Avatar save/reset across two owner sessions, denial for another account and rejection of a malformed avatar passed. |
| Hosting emulator | Served the release bundle and returned HTTP 200 for the `/profile` route. |
| Chrome Web UI integration | Passed with ChromeDriver and the Firebase emulators. The app registered and verified an account, edited the display name, saved and reset the avatar across two Firebase sessions, changed the password, and completed an email reset followed by manual login. |

## Cross-device avatar setup

The cloud avatar is a private PNG thumbnail with a maximum dimension of 256 px.
The picker accepts validated PNG/JPEG sources up to 5 MiB and 8192 px. Firestore rules
permit only the matching Firebase UID to read or write the avatar document.
An explicit cloud reset takes precedence over avatars from earlier local
installs. Without the cloud flag, the app uses the existing local store.

To run the local Auth and Firestore rules smoke check from `final_note/`:

```powershell
firebase emulators:exec --project demo-noteflow --only auth,firestore "pwsh -NoProfile -File tool/check_firebase_emulator.ps1"
```

The emulator check covers registration, activation, password reset and a manual
sign-in. It also checks that a second session for the owner can read the saved
avatar and reset, while another UID cannot read or modify that record.

Run the Web UI integration check with matching Chrome and ChromeDriver versions.
Start `firebase emulators:start --project demo-noteflow --only auth,firestore`
and `chromedriver --port=4444` in separate terminals. Run the driver from
`final_note/`:

```powershell
flutter drive -d web-server --headless --browser-name=chrome --driver=test_driver/integration_test.dart --target=integration_test/m1_web_emulator_test.dart --dart-define=FIREBASE_CLOUD_AVATARS=true
```

Pass `--chrome-binary` when using a portable Chrome build. The test initializes
the `demo-noteflow` Firebase project and checks the Auth and Firestore emulators
in an independent browser session.

## Final verification

- Firebase Hosting and Firestore deployment require a signed-in account with
  deployment access to `noteflow-3f90d`.
- The signed `NoteFlow-Android-release.apk` is 60,255,900 bytes. Android device
  installation and runtime checks are pending.
- APK SHA-256 is
  `1D0B20F5F9899DB3AE22571240CA6C58A144822217653BF82C47A37D583FF89E`.
- Recheck login, sign-out, activation, reset, password change and profile on
  the public Web release and a signed Android APK with disposable accounts.
- Use the same account on Web and Android to save, reload and reset its avatar.
  Check the default avatar and verify that another account sees its own image.
- Record the public URL, release APK details and demo timestamps in the
  submission evidence after checking both releases.

Follow [Readme.txt](../Readme.txt) to configure and build the releases.
