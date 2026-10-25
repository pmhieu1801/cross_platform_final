# M1 W1 - kiểm chứng và bàn giao

Evidence runtime/build ghi nhận **24/10/2026**; tài liệu và kiểm tra source cập nhật **25/10/2026, Asia/Bangkok**. M1 cho biết đang cuối W1; chưa có nguồn giảng viên/e-learning xác nhận deadline hoặc khoảng 4 tuần chính thức.

## Kết luận có giới hạn

Auth/guard/forms và điểm tích hợp UID đã triển khai. Web đã kiểm tra với Firebase thật; build Web release và Android debug đã thành công từ cùng source. **Chưa xác nhận hành vi Firebase trên Android, chưa đạt Gate W1, chưa Done theo DoD nhóm.** M2/M3 chưa review/chốt các contract dữ liệu. Không có note repository/cache/listener nghiệp vụ để claim đã kiểm tra isolation toàn dự án.

## Môi trường

- Windows 11; Flutter 3.47.0 stable / Dart 3.13.0.
- Android SDK 36.0.0, platform 34 được Gradle cài cho Firebase plugin; JBR 25.0.2. Licenses đã được doctor xác nhận.
- Web chạy bản release tại `http://127.0.0.1:5137/` trong in-app browser. Đây là local runtime, chưa phải public HTTPS deployment.
- AVD `test_flutter`, serial emulator-5554, không có thiết bị vật lý. Đã thử headless, restart ADB và cold boot/software renderer. Emulator có lúc báo device, sau đó offline hoặc không đọc được properties.
- Firebase thật: `noteflow-3f90d`; Web/Android app IDs trong README/config. Console xác nhận Spark và Email/Password Enabled. Không tạo Firestore/Storage rules hoặc cho phép truy cập công khai.

## Lệnh và kết quả

| Kiểm tra | Lệnh đã chạy | Kết quả |
| --- | --- | --- |
| Format | `dart format --output=none --set-exit-if-changed lib test integration_test` | PASS: 16 files, 0 changed |
| Analyze | `flutter analyze --no-pub` | PASS: No issues found; lần cuối gồm integration test source |
| Test cô lập | `flutter test --no-pub test --reporter expanded` | PASS: 12/12; dùng fake test-only, không chứng minh Firebase thật |
| Web build | `flutter build web --release --dart-define-from-file=config/firebase.web.json` | PASS; build/web; Wasm dry run cũng thành công; chạy thực tế riêng như bảng dưới |
| Android build | `flutter build apk --debug --dart-define-from-file=config/firebase.android.json` | PASS; build/app/outputs/flutter-apk/app-debug.apk; chưa claim native release hoặc install/runtime pass |
| Integration Android | `flutter test --no-pub integration_test/auth_real_test.dart -d emulator-5554 --device-timeout 20 --dart-define-from-file=config/firebase.android.json --reporter expanded` | CHƯA PASS: tool/device bị chặn; xem chi tiết dưới |

Build đầu tiên không có config cũng thành công nhưng **không** được dùng làm bằng chứng backend. Hai build được ghi ở bảng là các build sau khi có config thật. Sau đó chỉ thêm dev dependency integration_test/test và tài liệu; analyzer/test cô lập đã chạy lại. Build artifacts không đưa lên Git.

Flutter pub get đã resolve thêm 8 dependency của integration_test nhưng cảnh báo Windows cần symlink support/Developer Mode; không tự đổi thiết lập máy. Dùng --no-pub với package config đã resolve. Lần Android test tiếp theo lỗi: `Error 1 retrieving device properties`, `protocol fault (couldn't read status): connection reset`; Flutter nhận emulator là `Android null (API null) (unsupported)` rồi báo `No supported devices found`. Cold boot sau đó vẫn cần đọc properties ổn định trước khi có thể claim test chạy. Không bỏ assertion hoặc làm yếu test để xanh.

Gradle build đã báo cảnh báo tương thích tương lai KGP ở firebase_auth/firebase_core, và JDK native access warning; build hiện tại vẫn thành công. Không sửa dependency Flutter/Firebase hoặc SDK chỉ để giấu warning.

## Ca nghiệm thu M1

| # | Yêu cầu | Bằng chứng / bước thực hiện | Trạng thái |
| --- | --- | --- | --- |
| 1 | Signed-out mở app/private URL bị chặn | Web mở `/#/home` → `/#/login`; guard unit/widget tests gồm route lạ và direct route | PASS Web + tests; Android behavior chưa kiểm chứng |
| 2 | Khởi tạo không lộ private UI | Web reload đã quan sát `/session` và dòng “Đang xác định phiên đăng nhập…” trước home; widget test trì hoãn first event; provider test refresh giữ previous user nhưng UID vẫn null | PASS Web + tests; Android pending |
| 3 | Register thật, auto-login, UID, banner | Web đăng ký A, hiện W1 Web Test và UID `ncPrIHxrQAglYcZiALLaCpfaIKm1`; Console Users đối chiếu đúng UID; banner xuất hiện | PASS Web Firebase thật; Android pending; activation email W2 |
| 4 | Input sai / email trùng | Widget test bắt email/tên/password/confirmation sai trước request; Web dùng lại email A → “Email này đã được đăng ký. Hãy đăng nhập.”, vẫn ở register | PASS validation tests + Web duplicate; chưa test mọi policy Firebase |
| 5 | Login đúng/sai | Web password sai → “Email hoặc mật khẩu không đúng.” và ở login; nhập đúng → home cùng UID A | PASS Web Firebase thật; Android pending |
| 6 | Khôi phục phiên | Web reload → session checking → cùng UID A và tên A; SDK default persistence, không lưu password riêng | PASS Web; Android đóng/mở chưa kiểm chứng |
| 7 | Mạng/gửi lặp | Unit/widget giữ request pending, submit/keyboard duplicate chỉ gọi 1 lần; fake network error trả UI về enabled rồi retry thành công | PASS cô lập; **chưa thử cắt mạng thật trên Web/Android** |
| 8 | Logout rồi Back/URL cũ | Web logout → login; Back và mở lại `/#/home` vẫn login, không có UID/private content; widget cũng kiểm pop + direct path | PASS Web + tests; Android pending |
| 9 | A → B không giữ A | Web logout A, đăng ký B → tên B, UID khác `ctIxGbOjqDaUIZUTI9MhZmn3b1A3`, không còn A; UID B đã đối chiếu Console Users; fake dependent-provider test chứng minh dispose/close lease A/B | PASS phần M1 đã tích hợp; M2/M3 listener/cache chưa tồn tại/chưa kiểm chứng |

Hai account Web test dùng địa chỉ `@example.test`, password ngẫu nhiên chỉ ở RAM phiên kiểm thử; có thể còn trong Console cho owner đối chiếu, không phải tài khoản chấm bài. Không có password trong source/log/evidence bàn giao. Android integration test được viết để tạo/cleanup đúng account của nó, không xóa user có sẵn; hiện chưa có kết quả pass.

## Evidence giữ lại

- [Email/Password Enabled trên Console](evidence/firebase-email-password-enabled.jpg)
- [Console có hai account test; UID trong ảnh được hiển thị rút gọn](evidence/firebase-real-user.jpg). Giá trị UID đầy đủ trong bảng nghiệm thu đã được đối chiếu qua nội dung văn bản của Console.
- [Web sau reload, session được phục hồi](evidence/web-restored-session.jpg)
- [Logout/URL riêng bị chuyển về login](evidence/web-logout-guard.jpg)
- [Tài khoản B sau khi đổi A](evidence/web-account-b.jpg)

Chỉ giữ ảnh liên quan kiểm chứng, không commit ảnh render PDF/build/cache/log thô. Ảnh không thay được các ca behavior chưa chạy; không có video demo hoặc GitHub Insights evidence ở W1 này.

## W1 requirement → evidence → trạng thái

| Hạng mục | Evidence | Trạng thái |
| --- | --- | --- |
| Một Flutter source Web/Android | cùng lib/main.dart; hai build có config thật | Implemented + build verified; Android runtime pending |
| Auth thật / UID | Firebase adapter + Web UI + Console Users | Verified Web; Android pending |
| Session loading / restore / guard | providers, session_guard, 12 tests + Web reload/logout/deep link | Verified phần M1/Web; Android pending |
| Register/login/logout form | 4 inputs register, Firebase SDK, error/busy, Web thật và widget tests | Implemented + Web verified; full R1 activation còn W2 |
| Banner unverified | emailVerified từ SDK, ảnh Web | Verified W1 slice; activation đầy đủ W2 |
| Repo/templates/backlog | root .github; rubric-backlog có 32 tiêu chí; 24 issue published, 8 prepared do lệnh tiếp bị từ chối | Prepared/published một phần; chưa Done/review |
| UID + Note/Label/Share/Attachment/Sync contract | auth-contract.md có API thật và bảng đề xuất schema | Chờ M2/M3 review/chốt; chưa Gate |
| User/Lock kickoff | proposal/owner trong auth-contract.md | Chờ owners, chưa tạo schema/rules |
| Deadline / 4 tuần chính thức | đề gốc mục V xác nhận quy tắc, M1 nói cuối W1 | Ngày/khoảng tuần chính thức chưa xác nhận |

## Cần review và phần tiếp theo

hnt0411: UI form, mobile layout, Note/Label/Repository/Attachment contracts, provider cancellation và partition cache. cheertoburi: Firebase/UID isolation, guard vs rules, User/Share/Lock/Sync contracts và backend authorization; M1 cần kiểm tra collaborator invitation/quyền M3.

M1 cần một Android device/AVD có ADB ổn định để chạy integration test, restart session, Back/deep link và network failure thực tế. Cả Web/Android còn thiếu ca cắt mạng thật. Chưa có review M2/M3 hoặc merge; các issue vẫn Open, chưa tạo PR. Activation links, reset/change password, profile/avatar/preferences, Notes/sharing/lock/realtime/attachments/offline/AI không được tự nhận hoàn thành ở W1 M1.

## Bàn giao lên Git

Nền tảng Auth được push trong commit [5178a89](https://github.com/pmhieu1801/cross_platform_final/commit/5178a892e213329420df3e842dc8a9bb3f7516e1), nhánh pmhieu1801/m1-week1-auth. Phần tiếp theo bổ sung SDK integration_test và lockfile, test Firebase thật opt-in, README đầy đủ, contract/plan/walkthrough, backlog và các ảnh evidence trên đây; root .github có Issue/PR templates. PR template dùng Refs để việc bàn giao W1 không tự đóng một issue rubric còn acceptance của tuần sau.

Không đưa file desktop tự sinh, build/cache/tmp hoặc bản nháp issue trùng lặp vào commit. Không sửa Git identity/ngày/lịch sử. Chưa có PR/review/merge hoặc xác nhận Gate W1. Một test tích hợp đã viết và được analyzer kiểm tra vẫn chưa được tính là test chạy thành công trên thiết bị.

Kiểm tra lại ngày 25/10/2026 trước commit bàn giao: `flutter analyze --no-pub` không có issue; `flutter test --no-pub test --reporter expanded` qua 12/12; format lib/test/integration_test có 16 file, 0 thay đổi. Đã sửa teardown của test tích hợp để đăng ký cleanup trước khởi tạo, ghi nhận account sớm, kiểm tra UID trước xóa và báo lỗi cleanup riêng với lỗi assertion. README/docs không có relative link trỏ tới file thiếu; phần source/tài liệu được chọn không có private-key hoặc service-account fields. Không chạy lại build hoặc test Android thật trong lượt chuẩn bị commit này; các giới hạn runtime phía trên vẫn còn.
