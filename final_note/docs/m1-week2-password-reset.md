# W2-02 · Khôi phục mật khẩu

Lập ngày 15/11/2026, cập nhật ngày 18/11/2026 (Asia/Bangkok). Rubric R4, [issue #6](https://github.com/pmhieu1801/cross_platform_final/issues/6), [PR nháp #34](https://github.com/pmhieu1801/cross_platform_final/pull/34). Nhánh reset bắt đầu tại `65fecf7` trong worktree riêng và đã rebase lên `ec2ad9e` sau khi PR #33 merge.

Người dùng mở **Forgot password?** từ Login hoặc URL `/#/forgot-password`. Nếu Firebase đang khôi phục phiên, route giữ URL và hiển thị màn chờ. Khi phiên xác định signed-out, form kiểm email rồi gọi PasswordResetController → AuthRepository → FirebaseAuth.sendPasswordResetEmail.

Controller chặn nhiều request đồng thời và bỏ kết quả sau khi rời màn hoặc phiên đổi. Kết quả bình thường và lỗi `user-not-found` cũ có cùng hướng dẫn có điều kiện. Email sai, mạng và rate limit hiện lỗi để người dùng thử lại. Firebase tiếp nhận mã và mật khẩu mới tại trang HTTPS do Firebase host. Người dùng quay lại NoteFlow để đăng nhập thủ công. Source tham khảo ở [Auth contract](auth-contract.md) và [walkthrough mục 9](m1-code-walkthrough.md).

| Acceptance | Evidence |
| --- | --- |
| Route công khai, login link, validation, Enter, trạng thái đang gửi, chống gửi lặp, lỗi mạng/rate limit, retry | Tests trong `test/password_reset_test.dart` và `test/session_guard_test.dart`. Quan sát bản Web mở trực tiếp đúng form tại localhost:8082 |
| Thông báo có điều kiện cho địa chỉ chưa đăng ký và lỗi SDK được lọc | `test/firebase_password_reset_repository_test.dart` |
| Request không cấp phiên hay tự sign-in | Widget test kiểm session signed-out và số lần gọi sign-in. Trang Firebase chịu trách nhiệm kiểm link và cập nhật mật khẩu |
| Web và Android nhận thư thật, handler, mật khẩu cũ sai/mới đúng, link hết hạn/đã dùng | Chờ lượt owner với inbox thật. Tests cô lập chưa xác nhận delivery hay hành vi handler |

## Kiểm thử và giới hạn tích hợp

### Cập nhật 18/11/2026

Đã fetch lại GitHub, main vẫn là `ec2ad9e`, PR #34 còn draft và chưa có bình luận review. Sửa router `/home` dùng lại HomeScreen đã có. Adapter cấp user/UID, VerificationBanner, logout và các callback Notes theo UID cho NotesHomeScreen. Toàn bộ **68/68 tests PASS**, gồm 12 ca Auth/Verification từng lỗi dưới đây. Giữ nguyên các assertions hiện có.

`flutter analyze --no-pub` PASS. Web release và APK Android debug build lại PASS với config repo. Build Android dùng tùy chọn Kotlin tạm như ngày 15/11 và khôi phục file Gradle sau build.

Owner trả lời “ok het roi” sau checklist Web gồm nhận mail vào inbox test, đổi mật khẩu bằng handler, mật khẩu cũ bị từ chối, mật khẩu mới đăng nhập thủ công được và mở lại link đã dùng báo lỗi. Đây là xác nhận của owner cho các bước chứa mật khẩu/link. Quan sát trực tiếp bản Web ở form reset thấy đúng email test và thông báo request được chấp nhận. Chưa lưu ảnh trang handler hoặc ghi URL/mã. Link thực sự hết hạn do thời gian và hostname Web triển khai chưa kiểm tra trong lượt này. Android đang nghiệm thu riêng.

LocalNoteRepository hiện có của nhóm dùng key theo UID. Notes từng lưu ở key chung `noteflow_notes_v1` cần M2 quyết định owner và cách chuyển dữ liệu để xuất hiện trong store tài khoản. Lượt sửa router sử dụng store theo UID hiện có.

### Kết quả ngày 15/11/2026 trước khi sửa router

- Format 12 file Dart kiểm tra không đổi. Trên `ec2ad9e` sau rebase, `flutter analyze --no-pub` sạch và full suite có 56 pass, 12 fail. Cả 7 test reset mới đều pass, lượt riêng cùng route guard có 11/11 pass. Bản `65fecf7` nguyên gốc có 45 pass và cùng 12 ca Auth/Verification lỗi, gồm ca resume chạm timeout. Không skip hay sửa assertion cũ.
- `/home` trên `65fecf7` và `ec2ad9e` dựng trực tiếp NotesHomeScreen. Route bỏ qua adapter HomeScreen cấp UID, logout, VerificationBanner và repository theo UID. Đã tái hiện trên bản main gốc bằng các ca UID/banner và logout. Nhánh `origin/hnt` tại `4abf1b0` đã dùng HomeScreen. Khi tích hợp M2 cần xác nhận cách giữ notes đã lưu trước khi đổi đích `/home`.
- `flutter pub get` giải quyết và tải được dependency, sau đó báo thiếu quyền tạo symlink cho plugin desktop. Các lệnh kiểm tra dùng package config đã sinh và `--no-pub`.
- Web release và Android debug đã build lại với config repo sau rebase. Trên worktree ở ổ C: với Pub cache ở D:, Android cần tắt Kotlin incremental và dùng compiler in-process riêng cho lần build. File Gradle được khôi phục sau mỗi lượt. APK trước rebase đã cài/mở trên emulator, lần cài APK cuối gặp emulator mất kết nối. Chưa xác nhận luồng reset bằng inbox thật trên Android.

## Nghiệm thu bằng tài khoản test

1. Từ phiên signed-out trên mỗi nền tảng, bấm **Forgot password?**, nhập email test do owner kiểm soát và yêu cầu link. Kiểm hộp thư và spam.
2. Owner mở link bằng trình duyệt của nền tảng đang test, tự đặt mật khẩu mới trên trang Firebase, rồi quay lại NoteFlow. Kiểm app vẫn ở luồng công khai trước khi bấm **Sign in**.
3. Thử mật khẩu cũ, sau đó xác nhận mật khẩu mới đăng nhập được. Mở lại link đã dùng để xác nhận trang Firebase báo lỗi. Ghi kết quả và nền tảng, giữ URL có mã và mật khẩu ngoài evidence.

Review cần M2 cho form và tích hợp router, M3 cho cách dùng Firebase handler và thông báo khôi phục. Nhóm sẽ cập nhật issue R4 sau khi có evidence thật và review.
