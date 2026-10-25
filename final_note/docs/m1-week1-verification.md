# M1 W1 — kiểm chứng và bàn giao

Cập nhật **25/10/2026, Asia/Bangkok**. Web runtime kiểm tra ngày 24/10; tích hợp UI chung và Android runtime kiểm tra ngày 25/10. Deadline/khoảng 4 tuần chính thức: **chưa xác nhận** từ giảng viên/e-learning.

## Kết luận

Firebase Auth thật đã chạy trên Web và Android từ cùng Flutter source. Android đã qua form đăng ký/đăng nhập/đăng xuất, UID/banner, lỗi xác thực, đổi tài khoản, khôi phục phiên qua hai tiến trình và lỗi mất mạng thật. **Gate W1 còn chờ M2/M3 review và chốt contracts; chưa Done theo DoD nhóm, chưa merge vào main.**

Không có NoteRepository/cache/listener nghiệp vụ trong phần M1 để tuyên bố đã kiểm tra isolation toàn dự án. Model/Notes UI demo trên main được giữ nguyên, chưa nối vào private Auth shell.

## Môi trường và source

- Windows 11; Flutter 3.47.0 / Dart 3.13.0; Android SDK/build-tools 36.0.0, JBR 25.0.2.
- Firebase thật noteflow-3f90d, Email/Password Enabled, Spark. Config client trong config/; không có Admin key, không mở rules.
- Web release local http://127.0.0.1:5137/; chưa kiểm tra hosting HTTPS công khai.
- Android AVD test_flutter, serial emulator-5554, API 37; user mở từ Android Studio Device Manager vào Home, ADB đọc boot_completed=1. Không có thiết bị vật lý.
- Nhánh pmhieu1801/m1-week1-auth tích hợp main 3486542 (PR #1/#2/#27). Giữ theme/fonts/shared widgets, Note model, NotesHomeScreen và assertion test của nhóm. Login/Register Midnight Glow nối callback vào Firebase Auth qua adapter.

## Kiểm tra tự động

Chạy từ app root; dùng config client thật. Test cô lập vẫn dùng fake test-only.

| Kiểm tra | Lệnh / cách chạy | Kết quả |
| --- | --- | --- |
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test` | **PASS: 40 files, 0 changed**, lần cuối 25/10 |
| Analyze | `flutter analyze --no-pub` | No issues found sau tích hợp |
| Unit/widget | `flutter test --no-pub test --reporter expanded` | **31/31 PASS**; giữ test main, không coi là Firebase evidence |
| Web release | `flutter build web --release --no-pub --dart-define-from-file=config/firebase.web.json` | PASS sau tích hợp UI |
| Android debug | `flutter build apk --debug --no-pub --dart-define-from-file=config/firebase.android.json` | PASS sau tích hợp UI; không phải bản release ký để nộp |
| Android Auth thật | `flutter test --no-pub integration_test/auth_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded` | **1/1 PASS**, khoảng 42 giây runtime; cleanup hai account của lượt test |
| Android restore seed | `flutter test --no-pub --no-uninstall integration_test/auth_persistence_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --dart-define=AUTH_PERSISTENCE_PHASE=seed --reporter expanded` | **1/1 PASS**, 9 giây runtime; để session cho verify |
| Android restore verify | Cùng lệnh seed, đổi phase thành verify, thêm `--dart-define=AUTH_EXPECTED_UID=<UID-seed>`, sau `adb -s emulator-5554 shell am force-stop com.example.final_note` | **1/1 PASS**, 5 giây runtime; đúng UID, home hiện, cleanup account |
| Android offline | `flutter test --no-pub integration_test/auth_network_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded` sau tắt Wi-Fi/mobile data trong guest | **1/1 PASS**, 4 giây runtime; khôi phục Wi-Fi=1/mobile-data=1 trong finally |

Persistence đối chiếu UID công khai 6eCWEinwjKWxmT9o6U5QQT2zaOF2 ở seed và verify. Không truyền password/token giữa tiến trình; password ngẫu nhiên chỉ trong RAM. Bài này kiểm tra đóng tiến trình/mở lại khi giữ dữ liệu app, không kiểm tra gỡ/cài mới hoặc reboot emulator.

Offline test gọi production AuthActions/Firebase SDK, chặn action trùng khi pending và kiểm tra UI lỗi, nút hết loading, UID null. Không mock mạng/repository. Gõ và bấm nút thật được kiểm tra ở auth_real_test; offline test gọi controller trực tiếp. Chưa cắt mạng thật trên Web.

## Ca nghiệm thu

| # | Yêu cầu | Evidence | Trạng thái/giới hạn |
| --- | --- | --- | --- |
| 1 | Signed-out bị chặn private route | Web /#/home → login; Android đi /home trước login và sau logout | PASS Web + Android; Android external App Links chưa cấu hình W1 |
| 2 | Checking không lộ private UI | Widget trì hoãn first event; provider loại dữ liệu cũ trong loading/error; Web quan sát /session khi reload | PASS test/Web; Android có startup thật, chưa cố tình trì hoãn native stream |
| 3 | Register thật, auto-login, UID/banner | Web UI + Console UID; Android form thật, SDK email/displayName/UID khớp UI, banner | PASS hai nền tảng; activation đầy đủ W2 |
| 4 | Input sai/email trùng | Shared Validators/widget tests; Web/Android duplicate trả lỗi, session null | PASS phạm vi đã thử, không claim mọi Firebase policy |
| 5 | Login đúng/sai | Web/Android sai → lỗi/null; retry đúng → cùng UID | PASS Firebase thật |
| 6 | Khôi phục phiên | Web reload cùng UID; Android seed → force-stop → verify cùng UID | PASS phạm vi trên; chưa reboot hệ điều hành |
| 7 | Mất mạng/gửi lặp | Android offline + controller/UI thật; fake pending/duplicate/retry | PASS Android thật + cô lập; Web offline thật chưa thử |
| 8 | Logout/Back/URL cũ | Web browser Back/direct URL vẫn login; Android logout + go('/home') không có UID/private content; widget pop tests | PASS các bước này; Android nút Back hệ thống chưa thử riêng |
| 9 | A → B không giữ A | Android A/logout/B, UID khác, lease A đóng; Web A→B; dependent-provider dispose tests | PASS M1; cache/listener M2/M3 cần tích hợp/test riêng |

## Evidence Web giữ lại

Android production APK đã được cài/mở sau khi chạy test; [ảnh màn hình signed-out](evidence/android-signed-out.png) ngày 25/10 xác nhận UI Midnight Glow đang chạy. Ảnh login không tự chứng minh đăng ký/persistence; các kết quả đó đến từ integration tests phía trên.

Ảnh ngày 24/10 dùng UI trước tích hợp Midnight Glow, chỉ là evidence backend/session của lần đó. UI chung đã qua widget/Android integration; chưa chạy lại toàn bộ Web end-to-end trên UI mới.

- [Email/Password Enabled](evidence/firebase-email-password-enabled.jpg)
- [Console Users, UID rút gọn](evidence/firebase-real-user.jpg)
- [Web khôi phục session](evidence/web-restored-session.jpg)
- [Web logout/guard](evidence/web-logout-guard.jpg)
- [Web đổi sang B](evidence/web-account-b.jpg)

Web A UID ncPrIHxrQAglYcZiALLaCpfaIKm1, B UID ctIxGbOjqDaUIZUTI9MhZmn3b1A3 đã đối chiếu Console. Hai account m1-web-...@example.test có thể còn cho owner đối chiếu, không phải grading accounts. Lần persistence lỗi trước khi sửa runner có thể để lại account m1-persistence-...@example.test; owner có thể kiểm tra/xóa đúng account test trong Console. Không có password/admin key trong bàn giao; không tự xóa user ngoài test.

## Chẩn đoán và giới hạn

- AVD headless trước đó không trả getprop/boot hoàn chỉnh. Sau khi user mở Device Manager, ADB hoạt động; không đổi Windows security/virtualization, không wipe AVD.
- Native IME/scroll làm input/tap ban đầu không ổn định. Test thêm chờ input, dismiss focus, ensureVisible và bắt buộc hit-testable trước tap; giữ toàn bộ assertion, không gọi thẳng onPressed để né UI.
- Persistence lần đầu sai vì Flutter test mặc định uninstall app, xóa dữ liệu phiên. Dùng **--no-uninstall ở cả hai phase**, force-stop giữa chúng rồi test pass. Đây là sửa fixture đúng hành vi đóng/mở.
- Gradle có cảnh báo KGP tương lai ở firebase_auth/firebase_core và JDK native access; build hiện tại pass. Không đổi SDK/dependency để giấu warning.
- Formatter chỉnh khoảng trắng ở một số file UI/test từ main; giữ logic/behavior và toàn bộ assertion test. Hai build ở bảng đã chạy lại sau lượt source cuối, APK đã trở lại entrypoint production sau khi integration runner dùng test target.
- Windows pub get từng cảnh báo symlink support; không tự đổi Developer Mode. --no-pub dùng sau khi resolve dependency.
- Không có public HTTPS deployment, release signing, thiết bị Android vật lý hoặc video demo trong lượt W1 này.

## W1 requirement → evidence → trạng thái

| Hạng mục | Evidence | Trạng thái |
| --- | --- | --- |
| Một source Web/Android | lib/main.dart, hai build, Web runtime/Android integration | Đã triển khai/kiểm chứng theo phạm vi trên |
| Auth thật/UID/restore/guard | Firebase adapter, 31 tests, Web evidence, Android Auth/persistence/offline | Đã kiểm chứng M1; giới hạn ở bảng nghiệm thu |
| Forms/banner | Midnight Glow adapter + native UI tests | Đã triển khai; full activation W2 |
| Repo/templates/backlog | root .github; 32 rubric backlog, 24 issue published theo snapshot 24/10 | Chuẩn bị/publish một phần; R25–R32 local, chưa DoD |
| UID/Note/Label/Share/Attachment/Sync | auth-contract.md có API thật, model main và câu hỏi owner | **Chờ M2/M3 chốt**, Gate chưa đạt |
| User/Lock kickoff | proposal/owner trong contract | Chờ owner, chưa tạo schema/rules |
| Cross-review | PR #28 | Chờ review; không tự approve/merge |
| Deadline/4 tuần | quy tắc đề gốc + M1 nói cuối W1 | Ngày/khoảng tuần chính thức chưa xác nhận |

## Bàn giao Git và review

Hai commit thực chất đã push: [5178a89 — Auth foundation](https://github.com/pmhieu1801/cross_platform_final/commit/5178a892e213329420df3e842dc8a9bb3f7516e1) và [1b72868 — test/contracts](https://github.com/pmhieu1801/cross_platform_final/commit/1b72868d620a3887a89af57655f0bc742d74bec6). Lượt tiếp theo tích hợp main và bổ sung bằng chứng Android, giữ lịch sử nhóm, không chia nhỏ để đủ số lượng/đổi identity/ngày.

[PR #28](https://github.com/pmhieu1801/cross_platform_final/pull/28) là nơi yêu cầu hnt0411/CheetoBuri review. M3 đúng username CheetoBuri (read permission); M2 có write. Xác nhận username không phải chốt contract. Không merge khi thiếu review.

Không commit build/APK/cache/AVD/log thô/tmp hoặc desktop registrants tự sinh. Không sửa Note schema/rules/migration. Activation links/reset/change password/profile/avatar/preferences thuộc W2; Notes/sharing/lock/realtime/attachments/offline sync/AI thuộc owners khác.
