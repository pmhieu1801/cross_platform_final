# W2-01 — Email verification / activation

Kiểm tra ngày 27/10/2026 (Asia/Bangkok), M1 pmhieu1801. **Đã triển khai; chưa đánh Done toàn bộ R1/R2/DoD.** Chỉ W2-01 trong lượt này; W2-02 và các task sau chưa bắt đầu.

## Nền tảng và phạm vi

- Fetch origin/main thật trước khi sửa: `06ea8f86b0bdd0a09d419713b299241bd79f132e`; connector xác nhận PR #28 merged ngày 25/10/2026. Không suy contract signoff từ merge.
- Nhánh `pmhieu1801/m1-week2-account`, tạo từ main trên. Giữ nguyên README thêm link plan, docs/m1-week2-plan.md chưa tracked và ba desktop registrants local của W1; không đưa chúng vào commit W2-01.
- Đọc README, plan W2, auth-contract, walkthrough, verification W1; không tìm thấy AGENTS.md áp dụng. Đối chiếu đề gốc trang 2-3 và workflow trang 2,4-5: tự đăng nhập khi đăng ký, gửi mail xác minh, user chưa verify vẫn dùng app, banner biến mất sau activation; phải kiểm cả Web/native và có owner khác review.
- Chỉ sửa account Auth/banner; không sửa Note model, Notes UI/CRUD, sharing, rules/schema, storage/billing hoặc preferences. Không thêm dependency.

## Hành vi đã triển khai

RegisterScreen → AuthForm → AuthActions → FirebaseAuthRepository tạo account/session, thử updateDisplayName rồi sendEmailVerification. RegistrationResult phân biệt account đã tạo và bước sau thất bại; lỗi mail cho phép resend, không đăng ký lại. Lỗi tên vẫn thử gửi mail. Thông báo request thành công không tự chứng minh email delivery.

VerificationBanner hiển thị địa chỉ nhận lấy từ SDK để đối chiếu inbox → verificationActionsProvider(uid) → sendVerificationEmail(expectedUid) hoặc refreshCurrentUser(expectedUid). Controller giữ busy trước await, chống gọi lặp, cooldown gửi lại 60 giây sau request thành công (lựa chọn UX local trong tiến trình, reset khi restart/logout; không thay server rate limit). Refresh vẫn dùng được trong cooldown. Callback kiểm UID/lease/generation, account switch và cả A → null → A không nhận kết quả lease cũ.

Kiểm tra lại bằng nút hoặc app resumed → User.reload() → SDK userChanges() → AuthUser.emailVerified mới → banner biến mất. Không tự gán true, không dùng email làm key/session flag. Feedback đăng ký xử lý cả trường hợp Future xong trước SDK stream và bỏ kết quả sau switch.

Lựa chọn triển khai: handler HTTPS mặc định Firebase, không truyền ActionCodeSettings/continue URL, không tạo custom Flutter action route/App Links/Dynamic Links. Handler chạy trong browser bên ngoài app và không bị signed-in guard của Flutter nuốt link. Nguồn kỹ thuật: [Firebase manage users](https://firebase.google.com/docs/auth/flutter/manage-users), [Auth streams/reload](https://firebase.google.com/docs/auth/flutter/start), [email action handler](https://firebase.google.com/docs/auth/custom-email-handler); đã đối chiếu SDK firebase_auth 7.0.1 đang cài. Đây là lựa chọn M1 cần review, không gán thành yêu cầu PDF.

## Kết quả tự động

| Kiểm tra | Kết quả / giới hạn |
| --- | --- |
| Format lib/test/integration_test | PASS, 44 files, 0 changed (kiểm tra --output=none --set-exit-if-changed sau lượt source cuối) |
| flutter analyze --no-pub | PASS, No issues found |
| flutter test --no-pub test --reporter expanded | PASS **47/47**; gồm 31 tests cũ + 6 adapter + 10 verification tests |
| Web release build, config thật | PASS, build/web; không đồng nghĩa đã deploy/runtime production |
| Android debug production build | PASS, build/app/outputs/flutter-apk/app-debug.apk; không phải bản release ký nộp |
| Android auth_real_test, emulator-5554, Firebase thật | PASS **1/1**: native forms/register/UID/banner, login sai/đúng, duplicate account, logout/private route và A→B; cleanup đúng hai account vừa tạo |
| Native inbox/SDK activation mới | PASS: owner xác nhận nhận mail alias; mở link trên máy tính; nút kiểm tra trên Android bỏ banner theo SDK. Handler Chrome emulator NOT RUN |

Tests cô lập kiểm network/rate-limit, partial register (mail lỗi hoặc tên lỗi), request lặp, cooldown hết hạn, refresh lỗi/retry, resume, SDK-only flag, compact layout/text scale 1.6, UID mismatch, callback cũ/resend và registration result đến muộn. Không skip/bỏ assertion cũ. Fixture chờ bounded pump khi session chưa có event (spinner không settle); dispose container trong test trước invariant timer của Flutter.

Hai lỗi build/test fixture lúc phát triển đã được sửa: await callback lifecycle trả void; pumpAndSettle khi session đang loading và container cleanup timer quá muộn. Tests còn bắt được race thật Future/stream làm mất feedback đăng ký; source đã sửa, có regression test. Kết quả PASS chỉ từ lượt chạy sau sửa, không che các lượt lỗi.

## Evidence thực tế Web

Owner tự đăng ký bằng inbox do mình kiểm soát, tự nhập password; xác nhận trong chat “đã nhận mail và lỡ mở link”. Không yêu cầu/gửi/lưu password hoặc link chứa code vào chat/repo.

Quan sát trực tiếp IAB localhost:8080 sau khi owner mở link: home hiển thị UID, banner đã biến mất. Chủ động reload và thấy cùng UID trên ảnh, vẫn không banner. Ảnh [sau xác minh](evidence/w2/web-verified.png), [sau reload](evidence/w2/web-verified-reloaded.png). UI chỉ bỏ banner khi SDK emailVerified=true.

Giới hạn: chưa lưu ảnh trước verify của chính inbox này vì owner đã mở link trước khi quan sát. Chưa quan sát trực tiếp trang handler/nhấn nút kiểm tra của ca owner, nên không khẳng định đã phân biệt auto-resume với refresh thủ công. Banner trước verify có widget tests + native SDK regression, nhưng đó không thay thế evidence trước/sau cùng một inbox. Không truy cập URL chứa action code để tạo evidence. Chưa có HTTPS Web deployment; phải test hostname bản nộp riêng.

## Acceptance → evidence → trạng thái

Android production APK đã cài/mở trên AVD test_flutter sau integration runner. Owner tự đăng ký bằng alias của inbox mình và xác nhận đã nhận mail. Quan sát trực tiếp banner chưa xác minh, đúng địa chỉ nhận lấy từ SDK và home/UID vẫn truy cập được. Ảnh [Android trước verify](evidence/w2/android-unverified.png) lấy sau khi cập nhật APK bằng install -r: cùng session được giữ, banner chưa verify vẫn đúng. Owner xác nhận mở link bằng **trình duyệt máy tính**, sau đó nhấn “Kiểm tra xác minh” trên Android; banner biến mất. Quan sát/lưu ảnh [Android sau verify](evidence/w2/android-verified.png) cùng UID với trước verify. Không suy ca này thành PASS cho handler trong Chrome emulator: phần đó **NOT RUN**. Không gửi lại vào địa chỉ nhập nhầm ở lần đầu, không xóa account owner/ngoài hai account tự tạo của integration runner.

| Acceptance W2-01 | Evidence | Trạng thái |
| --- | --- | --- |
| Account/session thật và gửi mail sau register | Adapter + Android SDK regression; owner xác nhận nhận email Web | PASS phần đã quan sát/xác nhận |
| Inbox thật nhận mail/link có tác dụng | Owner xác nhận nhận/mở link cho hai account; SDK-backed Web/Android UI không banner | PASS delivery + link mở trên máy tính; handler Chrome emulator NOT RUN |
| Banner trước verify, không chặn app | Widget + Android native register/UID/banner | PASS các ca này; thiếu ảnh trước verify inbox Web owner |
| Refresh bỏ banner, reload/reopen giữ state | Tests + Web reload cùng UID; Android nút kiểm tra bỏ banner sau link thật; adb force-stop rồi mở app lại vẫn cùng UID, không banner ([ảnh](evidence/w2/android-verified-reopened.png)) | PASS Web reload/native refresh và reopen; chưa reboot OS |
| Resend loading/duplicate/cooldown/mạng/rate-limit | Tests hành vi provider/widget/adapter | PASS cô lập; chưa ép lỗi mail/network/rate-limit thật trên hai nền tảng |
| Không tự gán verified, không lẫn A/B | SDK snapshot/reload; expectedUid + lease/generation; tests A/B, late register | PASS source/tests; module cache/listener M2/M3 chưa thuộc phạm vi |
| Đủ Web deployed + submitted native + review/merge | Localhost evidence, SDK regression, native inbox/refresh, PR draft | NOT RUN deployed Web/handler Chrome emulator; review/merge chưa có |

## Lệnh tái kiểm thử

Chạy từ app root:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub test --reporter expanded
flutter build web --release --no-pub --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --no-pub --dart-define-from-file=config/firebase.android.json
flutter test --no-pub integration_test/auth_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define-from-file=config/firebase.web.json
```

Native test tự tạo email example.test và password random chỉ ở RAM, xóa đúng account vừa tạo; không chứng minh email delivery. Ca inbox thật cần owner tự nhập mật khẩu và mở link, không xóa account owner sau test. Build/cache/log thô không commit. SDK/Gradle có warning KGP/native-access từ dependency; không đổi SDK hoặc làm yếu kiểm tra để giấu warning.

## Bàn giao và phần còn lại

Code/test đã push trong commit `2c704b3` trên nhánh `pmhieu1801/m1-week2-account`; evidence native sau verification được bổ sung sau khi owner hoàn tất thao tác. Contract mới nằm trong auth-contract.md; ví dụ đọc code trong m1-code-walkthrough.md mục 8. M2 review UI/banner placement khi tích hợp Notes; M3 review SDK/UID/session boundary và handler. Không tự approve/merge, không close issue #4 khi thiếu DoD. Permission API của M3 vẫn trả read; điều đó không chứng minh collaborator membership trên repo công khai.

Chỉ sau khi tổng kết W2-01 và owner đồng ý mới bắt đầu W2-02 (forgot/reset). Prerequisite W2-02: lựa chọn handler đã kiểm chứng, inbox owner, public forgot route mới và policy thông báo chống dò account; chưa code task đó trong lượt này.
