# NoteFlow - M1 W1

Một Flutter project chung cho Web và Android. W1 gồm Firebase Email/Password register/login/logout, guard, banner chưa xác minh và private shell hiển thị UID. Notes thuộc M2; share/rules/lock/sync/AI thuộc M3, chưa triển khai ở đây. **Chưa claim Gate W1/Done**; xem [verification](docs/m1-week1-verification.md).

## Môi trường và kiến trúc

Đã dùng Flutter **3.47.0 stable**, Dart **3.13.0**, Android SDK/build-tools **36.0.0**, Android Studio JBR **25.0.2**. Giữ Firebase Core/Auth, Riverpod 3 và go_router 18 mà người dùng đã khai báo; commit pubspec.lock để tái lập dependency. Android applicationId/namespace: `com.example.final_note`.

App root là thư mục này; Git repo root là thư mục cha `cross_platform_final/`. Chạy Flutter commands tại app root, Git tại repo root. Issue/PR templates ở `.github/` **repo root**, không ở app con.

- `features/auth/domain`: AuthUser, AuthRepository và lỗi.
- `features/auth/data`: adapter duy nhất gọi Firebase SDK.
- `features/auth/application`: bootstrap, session, UID/account lease và action state.
- `features/auth/presentation`: adapter AuthForm nối provider/router vào form chung và màn hình chờ/lỗi. `screens/login_screen.dart`/`register_screen.dart` giữ UI Midnight Glow, shared Validators/widgets/fonts từ main; mặc định theme dark.
- `routing`: guard/router. `features/home`: private shell W1, chưa có Notes.
- `test`: test cô lập dùng fake test-only. `integration_test`: opt-in với Firebase thật.

Để hiểu code, đọc [walkthrough M1](docs/m1-code-walkthrough.md) rồi [Auth contract](docs/auth-contract.md). M2/M3 lấy UID qua provider; không import widget login.

## Firebase thật

Project **noteflow-3f90d**, billing Spark đã xác minh trên Console; Email/Password đã Enabled.

| Nền tảng | App ID |
| --- | --- |
| Web | `1:317164297475:web:a608dcbade81b8e4345d36` |
| Android | `1:317164297475:android:617820eacac044e1345d36` |

`config/firebase.web.json` và `config/firebase.android.json` chứa client identifiers thật, không có quyền Admin. App khởi tạo explicit FirebaseOptions; bộ core/auth hiện tại không đọc google-services.json hay cần Google Services Gradle plugin. Main Android manifest đã có INTERNET. Console có Analytics property tạo trong setup tương tác; Flutter app không cài/khởi tạo Analytics SDK và không truyền measurementId. Không bật billing/Blaze hoặc triển khai Firestore/Storage/rules.

Thiết lập lại project khác:

1. Owner đăng nhập Firebase Console, tạo/chọn project; đăng ký Web + Android đúng package ID.
2. Bật Authentication → Email/Password. Kiểm tra authorized domains/action-link domain khi triển khai hostname thật ở W2/W5.
3. Lấy **giá trị thật** từ Console hoặc chạy `flutterfire configure --project=<project-id> --platforms=web,android`. Chuyển options tương ứng vào JSON: FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID; Web thêm FIREBASE_AUTH_DOMAIN. FIREBASE_STORAGE_BUCKET tùy chọn. File `*.local.json` được ignore.
4. Không đặt service-account key, password/token, server/LLM key trong dart-define, source hoặc log. Client config không thay thế backend rules.

Thiếu config → báo lỗi ở /session; không giả user. Firebase SDK quản lý session persistence mặc định; app chờ first event từ userChanges() khi reload/restart. Không có chế độ fake hoặc emulator trong production.

## Lệnh chạy/test/build

Từ app root, PowerShell:

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub test --reporter expanded
flutter run -d chrome --dart-define-from-file=config/firebase.web.json
flutter run -d emulator-5554 --dart-define-from-file=config/firebase.android.json
flutter build web --release --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --dart-define-from-file=config/firebase.android.json
```

Web dùng hash URLs: `/#/login`, `/#/register`, `/#/home`. Không dùng /home path khi chưa có rewrite/path strategy. Khi signed-out mở /#/home phải về login.

Android device ID tùy máy, xem flutter devices. Windows có thể yêu cầu quyền symlink/Developer Mode khi pub get; owner tự thiết lập theo chính sách máy. --no-pub chỉ dùng sau khi dependency đã resolve. Web release/APK debug đã build thành công. Android AVD test_flutter (API 37) đã qua Auth thật, restore session và lỗi mất mạng; xem verification để biết giới hạn từng ca.

Test thật Android tạo hai account tạm với password sinh trong RAM, cleanup chỉ account vừa tạo, không dùng grading account:

```powershell
flutter test --no-pub integration_test/auth_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded
```

Test khôi phục phiên chạy **hai tiến trình**, giữ dữ liệu app bằng --no-uninstall ở cả hai lượt. Seed in UID công khai; thay UID bên dưới bằng đúng giá trị đó, không dùng password/token:

```powershell
flutter test --no-pub --no-uninstall integration_test/auth_persistence_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --dart-define=AUTH_PERSISTENCE_PHASE=seed --reporter expanded
adb -s emulator-5554 shell am force-stop com.example.final_note
flutter test --no-pub --no-uninstall integration_test/auth_persistence_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --dart-define=AUTH_PERSISTENCE_PHASE=verify '--dart-define=AUTH_EXPECTED_UID=<UID-seed>' --reporter expanded
```

Nếu adb chưa có trong PATH, dùng platform-tools/adb.exe trong Android SDK. Chỉ chạy verify khi seed pass. Gỡ app giữa hai lượt sẽ xóa session và làm sai điều kiện kiểm thử. Verify xóa đúng account test sau khi đối chiếu UID.

Test lỗi mạng: ghi nhận trạng thái Wi-Fi/mobile data của emulator, tắt cả hai trong guest rồi chạy lệnh dưới; luôn khôi phục trạng thái cũ trong finally (không tắt mạng Windows). Môi trường kiểm thử ngày 25/10 đã khôi phục cả hai về enabled.

```powershell
flutter test --no-pub integration_test/auth_network_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded
```

Không đặt password account thật vào tham số lệnh/source/screenshot/tài liệu. Hai account m1-web-...@example.test của Web test thủ công có thể còn trong Console để đối chiếu; không dùng làm grading accounts. Test tự động không xóa user có sẵn. Các lượt persistence lỗi trước đó có thể để account m1-persistence-...@example.test cho owner kiểm tra trong Console.

Outputs ignored: `build/web/`, `build/app/outputs/flutter-apk/app-debug.apk`. APK debug là kiểm tra W1, không phải release nộp. HTTPS public hosting, release signing và bộ nộp cuối thuộc các tuần sau. Không commit keystore/key.properties.

## Bàn giao

- [Phạm vi/checklist](docs/m1-week1-plan.md)
- [Contract Auth và schema đề xuất cần owner chốt](docs/auth-contract.md)
- [Kiểm thử, evidence, giới hạn](docs/m1-week1-verification.md)
- [Backlog 32 rubric và issue links](docs/rubric-backlog.md)
- [Giải thích để đọc hiểu code](docs/m1-code-walkthrough.md)

M1 pmhieu1801; M2 hnt0411; M3 CheetoBuri. M2 review UI/Auth, M3 review security; M3 đã xác nhận username CheetoBuri. Review và câu trả lời contract theo dõi ở PR #28; không tự xác nhận thay owner hoặc merge khi thiếu review. Activation đầy đủ, reset/change password, profile/avatar/preferences thuộc W2. Deadline và official four-week period: **chưa xác nhận** với giảng viên/e-learning.

Nguồn kỹ thuật: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup), [Auth streams/persistence](https://firebase.google.com/docs/auth/flutter/start), [Email/Password](https://firebase.google.com/docs/auth/flutter/password-auth), [go_router](https://pub.dev/packages/go_router). Nguồn yêu cầu PDF được đối chiếu trong plan; toàn bộ rubric không phải phạm vi W1.
