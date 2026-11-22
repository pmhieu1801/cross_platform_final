# W2-03 — Đổi mật khẩu tài khoản đang đăng nhập

Ngày kiểm tra: **22/11/2026**, owner M1 `pmhieu1801`. Rubric R07, [issue #9](https://github.com/pmhieu1801/cross_platform_final/issues/9). Base GitHub `main` là `36b734b`, PR reset #34 đã merge. Nhánh `pmhieu1801/m1-week2-change-password`. Chưa đánh Done khi còn QA giao diện hoặc peer review.

## Phạm vi và luồng

HomeScreen nối một callback mở `/change-password` vào header NotesHomeScreen, giữ nguyên module Notes của M2. Private screen có current/new/confirmation, validation, chống submit lặp và password không trim. Fields chỉ giữ credential trong đời form/request và được xóa khi request kết thúc hoặc rời màn hình. Nút chung GradientButton được sửa để chữ lớn xuống dòng và tăng chiều cao thay vì tràn ngang; vùng bấm vẫn bao phủ padding.

Screen → ChangePasswordController → AuthRepository → Firebase reauthenticate → updatePassword → scoped signOut → SDK userChanges → guard Login. Khi update đã thành công nhưng signOut lỗi, báo đúng kết quả từng bước và cho retry riêng signOut. Login cần thao tác thủ công, có lời nhắc dùng mật khẩu mới. Không có claim thu hồi mọi session trên thiết bị khác.

File chính: `lib/features/auth/application/change_password_controller.dart`, `presentation/change_password_screen.dart`, `domain/auth_repository.dart`, `data/firebase_auth_repository.dart`, router, HomeScreen và AuthForm. Không đổi schema, rules, backend, billing hoặc dependency version.

## Acceptance và evidence

| Acceptance | Evidence | Trạng thái |
| --- | --- | --- |
| Route private, entry từ home, current/new/confirmation hợp lệ | Guard và widget tests; confirmation sai/ít hơn 8 ký tự/field rỗng không gọi SDK | PASS cô lập |
| Reauth trước update; sai current không đổi; mật khẩu không trim | Adapter stub tests và SDK thật Android | PASS |
| Loading, duplicate, lỗi SDK không báo thành công giả | Widget/controller tests; adapter network/policy cases | PASS cô lập; lỗi mạng thật trong lượt W2-03 NOT RUN |
| Update thành công nhưng logout lỗi có thông báo và retry riêng | Widget test kiểm số lần changePassword không tăng khi retry | PASS cô lập; không cố gây lỗi native signOut |
| Đợi session stream, yêu cầu đăng nhập thủ công, old sai/new đúng | Widget test giả lập Future trước stream; Android Firebase thật kiểm controller/repository/session | PASS phần SDK; QA giao diện chủ tài khoản còn chờ |
| Callback A không đăng xuất B hoặc ảnh hưởng lease A mới | Adapter + widget tests A→B, A→null→A | PASS cô lập |
| Xóa input và hỗ trợ màn nhỏ/chữ lớn | Widget test 360×800, text scale 1.6; back/reroute theo UID | PASS cô lập |
| Web/Android UI, peer review và merge | Đang chuẩn bị nghiệm thu | PENDING |

## Kết quả kiểm tra

- Full unit/widget suite sau sửa regression đăng ký: **83/83 PASS**. Regression là provider listener ghi state trong lúc widget build; sửa bằng dependency watch và trả state từ build, không bỏ assertion cũ.
- `flutter analyze --no-pub`: **PASS**, không có issue.
- Web release build với `config/firebase.web.json`: **PASS**. Panel debug có lỗi disposed EngineFlutterView sau hot restart; chuyển sang release server để nghiệm thu, không coi build là runtime PASS.
- Android real Firebase SDK integration: **1/1 PASS**, 21 giây cho test và cleanup. Dùng production repository/controller với Firebase app thứ hai; account email example.test mới, password ngẫu nhiên chỉ trong RAM. Kiểm wrong-current, original còn đúng sau lần sai, đổi thành công, signed-out thật, old-password bị từ chối đúng lỗi credential, new-password login cùng UID. Cleanup xóa đúng UID account vừa tạo và Firebase app phụ; không signOut/xóa tài khoản có sẵn của owner. Test không kiểm email delivery.
- Lần Android đầu lỗi channel initializeCore trước tạo account vì worktree thiếu Android GeneratedPluginRegistrant.java bị ignore. `flutter pub get --offline` sinh lại plugin, lượt sau PASS. Không hard-code đăng ký plugin trong MainActivity.
- Gradle trên worktree C: và Pub cache D: cần tạm tắt Kotlin incremental/dùng compiler in-process cho build/test. Khôi phục nguyên bytes gradle.properties trong finally; không commit workaround. Warning KGP/native-access từ toolchain vẫn còn.
- APK app bình thường `lib/main.dart`: **build PASS**, cài cập nhật (`adb install -r`) và mở MainActivity thành công sau integration test. Không gỡ app hoặc xóa dữ liệu owner. QA giao diện đổi mật khẩu còn chờ owner. APK debug không phải bản release ký để nộp final.
- Formatter toàn repo phát hiện format lệch có sẵn tại `lib/features/notes/data/local_note_repository.dart` và `test/widget_test.dart`. Hai file này không thay đổi trong task; giữ nguyên cho M2. Kiểm format trong phạm vi file Auth/task được báo riêng, không ghi toàn repo sạch.

## Tái kiểm thử và nghiệm thu

```powershell
flutter pub get --offline
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --no-uninstall integration_test/change_password_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded
flutter build web --release --no-pub --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --no-pub --dart-define-from-file=config/firebase.android.json
```

Owner tự nhập password trên Web/Android: đăng nhập account test → Change password → confirmation sai và current sai → current đúng/new khớp → Login → old bị từ chối/new thành công. Không gửi password vào chat, không chụp/link dữ liệu chứa credential. CLI SDK test và widget tests không thay thế kết quả QA giao diện này.

## Bàn giao và phần còn lại

Chờ M2 review UI/router/shared button và M3 review Firebase reauthentication, scoped signOut, lease/session boundary. Không tự approve/merge. Tracker R07 cần evidence và peer signoff trước Done.

W2-02 Android reset còn thiếu xác nhận owner từ lượt trước; PR #34 merge không tự chứng minh đã nghiệm thu. W2-01 Android mở link trên trình duyệt máy tính, refresh và reopen app Android đã kiểm; handler Chrome emulator chưa chạy. Đây là giới hạn carry-over, không gán thành PASS của W2-03.

Task kế tiếp sau khi owner đọc tổng kết và đồng ý: **W2-04 view/edit profile** dùng Auth profile hiện có; W2-05 upload avatar phụ thuộc storage/billing/rules được owner M3 xác nhận. Không triển khai task mới trong W2-03.
