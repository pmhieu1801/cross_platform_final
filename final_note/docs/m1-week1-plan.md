# M1 / Leader / Auth - W1

## Nguồn và ranh giới

- Đã đọc đủ 6 trang `D:/cross-platform/NoteFlow_Team_Workflow_3_Members.pdf`, đối chiếu text và bản render.
- Có đề gốc `C:/Users/ADMIN/Downloads/503107-FinalProject-V1.pdf` (19 trang). Đã đối chiếu mục II.1, III, IV, V và VII: form đăng ký chỉ email/tên hiển thị/password/xác nhận; auto-login; chưa verify vẫn được dùng app; một source Flutter; 32 rubric; 4 tuần GitHub.
- PDF phân công trang 2 giao W1: foundation, Firebase, guard, register/login/logout, repo/templates. Trang 3 đặt định mức 3 unit/3 widget/1 integration ở W5. Không áp nó thành định mức W1.
- Gửi/xử lý activation link đầy đủ, reset/change password, profile/avatar/preferences thuộc W2. Banner và `emailVerified` là phần chuẩn bị W1. Chưa claim hoàn thành toàn bộ R1/R2.
- Flutter + Riverpod + Firebase + go_router là lựa chọn triển khai kế thừa dependency sẵn có, không phải stack bắt buộc của đề. Màn hình `/home` chỉ để kiểm tra UID/session; chưa có Notes.
- Hiện tại: cuối W1 theo M1 cung cấp ngày 24/10/2026 (Asia/Bangkok). Deadline và khoảng 4 tuần phát triển chính thức: **chưa xác nhận** từ giảng viên/e-learning. Không suy ra ngày từ roadmap 6 tuần.

## Kiểm tra ban đầu

- App root chính là `final_note/`, parent repo `D:/cross-platform/cross_platform_final/.git`. Không tạo project lồng nhau.
- Không tìm thấy AGENTS.md ở app, repo, các thư mục cha đã kiểm tra, hoặc dưới source.
- Ban đầu chỉ Flutter counter starter và test counter; README starter. Chưa có repository/provider/router/Auth hay contract M2/M3.
- Chưa có Firebase options, google-services.json, firebase.json, .firebaserc. M1 xác nhận chưa tạo Firebase khi bắt đầu.
- Git ban đầu: commit `0cecf75`; chỉ `final_note/pubspec.yaml` và `pubspec.lock` đã sửa chưa commit. Giữ nguyên dependency của người dùng: firebase_core ^5.1.0, firebase_auth ^7.0.1, flutter_riverpod ^3.4.3, go_router ^18.1.1.
- Remote xác minh: https://github.com/pmhieu1801/cross_platform_final ; default branch main. Tài khoản connector pmhieu1801 có admin/push. hnt0411 có write; cheertoburi chưa trả về collaborator permission, cần M1 kiểm tra invite/access.
- M1 pmhieu1801; M2 hnt0411; M3 cheertoburi (do M1 cung cấp). Không thay Git identity hoặc giả ngày/commit.
- Flutter 3.47.0, Dart 3.13.0; Android SDK 36.0.0, Android Studio JBR 25; có Chrome. Ban đầu chưa có thiết bị nối, có AVD `test_flutter`.

## Checklist triển khai

- [x] Dùng source Flutter hiện có cho Web/Android.
- [x] Tách UI / application providers / domain contract / Firebase adapter / routing.
- [x] Session stream, loading/signed-out/signed-in/error; guard fail-closed; private widget không render khi UID chưa hợp lệ.
- [x] Form register/login, tên và password confirmation, validation/loading/error/chống gửi lặp; logout.
- [x] Chuẩn bị activation flag/banner; không cấm user chưa verify.
- [x] UID/account lease cho M2/M3, test đóng lease và dispose provider phụ thuộc khi đổi account.
- [x] Test cô lập và build ban đầu Web release + Android debug; xem verification để biết lần chạy cuối.
- [ ] Chứng minh session Firebase thật và persistence trên cả hai nền tảng; theo evidence thực tế trong verification.
- [ ] M2/M3 review và chốt contract; không tự coi đề xuất schema là thống nhất.
- [ ] PR review bởi người khác; không self-approve/merge.

## Gate W1

Gate chỉ đạt khi (1) cả Web/Android chạy cùng source, (2) session thật được kiểm chứng, (3) UID/Note/Label/Share/Attachment/Sync được nhóm chốt. Code, fake tests hoặc build xanh riêng lẻ không chứng minh đủ Gate. Trạng thái hiện tại phải đọc cùng `m1-week1-verification.md`.

## Bàn giao W1 - cập nhật 25/10/2026

- Firebase project thật: noteflow-3f90d, hai app Web/Android; Email/Password Enabled. Web session/UID/reload/logout/account switch đã kiểm chứng ngày 24/10. Android build pass, runtime vẫn chưa kiểm chứng do ADB.
- Đã chuẩn bị đủ 32 rubric; theo lần kiểm tra 24/10 có 24 issue GitHub, R25-R32 mới có nội dung trong backlog. Chưa có review hoặc DoD toàn phần.
- Commit nền tảng Auth: [5178a89](https://github.com/pmhieu1801/cross_platform_final/commit/5178a892e213329420df3e842dc8a9bb3f7516e1), nhánh pmhieu1801/m1-week1-auth. Phần bàn giao tiếp theo gồm integration test, contract, README, evidence, backlog và root Issue/PR templates.
- Không đưa desktop registrant tự sinh, build/cache, ảnh render PDF hoặc log thô lên Git. Chỉ giữ ảnh evidence liên quan với báo cáo nêu giới hạn.
- Integration test dùng tài khoản ngẫu nhiên và cleanup theo UID/email của chính lượt test; teardown được đăng ký trước khởi tạo để vẫn dọn tài nguyên khi test thất bại. Chưa có kết quả chạy thật Android, không suy từ analyzer hoặc build thành integration pass.
- M2 review UI/Auth, Note/Label/Repository/Attachment; M3 review security, User/Share/Lock/Sync. Chưa tự nhận nhóm đã chốt contract và không merge khi thiếu review.
- Hai phần việc thực chất được chuẩn bị riêng: nền tảng Auth và kiểm thử/bàn giao. Việc tính đủ GitHub contribution còn phụ thuộc official period, review/merge và lịch sử được giữ trong bài nộp; ngày của official period vẫn chưa xác nhận.
