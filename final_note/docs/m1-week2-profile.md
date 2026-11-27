# W2-04 — Xem và sửa hồ sơ

Kiểm tra **22/11/2026**, M1 `pmhieu1801`; R05 [#7](https://github.com/pmhieu1801/cross_platform_final/issues/7), phần tên của R06 [#8](https://github.com/pmhieu1801/cross_platform_final/issues/8). Nhánh `pmhieu1801/m1-week2-profile`, dựa trên `5670ff4` của W2-03. GitHub main vẫn `36b734b`, PR #35 đang draft/chưa merge khi bắt đầu; PR hồ sơ được tách diff bằng base nhánh W2-03, không tự merge PR trước.

## Phạm vi và file

- AuthUser thêm `photoUrl` optional, adapter map từ Firebase User.photoURL. Source hồ sơ vẫn là Auth, không tạo User collection hoặc schema trùng lặp.
- AuthRepository thêm `updateDisplayName(expectedUid,displayName)`; controller và adapter chặn tên rỗng/trim khoảng trắng, adapter kiểm UID hiện tại trước ghi.
- `lib/features/auth/application/profile_controller.dart` điều phối refresh/save, loading/error/duplicate và lease boundary. Profile hiển thị từ SDK stream; không tự ghi snapshot giả theo input.
- `lib/features/auth/presentation/profile_screen.dart`: private route `/profile`, UID/email chỉ đọc, sửa tên có Save/Cancel. Mở màn hình tự reload SDK sau frame đầu; Refresh nhận thay đổi từ thiết bị khác. Lỗi save giữ draft; cancel/rời màn hình/đổi UID bỏ draft.
- `profile_avatar.dart`: avatar mặc định khi vắng URL, URL không phải HTTPS hợp lệ hoặc tải lỗi. Key theo UID/URL tránh tái dùng ảnh tài khoản cũ. Chưa chọn/upload ảnh hoặc thay photoURL; không đánh hoàn tất toàn bộ R06.
- HomeScreen/NotesHomeScreen chỉ thêm callback/nút Profile; không đổi CRUD/local store của M2.
- Compact test phát hiện Login bị overflow khi rời Profile với text scale 1.6. Sửa BrandBadge cho text co/đổi dòng, Password/Forgot dùng Wrap và nhãn divider co theo chiều rộng. Không bỏ hoặc giảm assertion kiểm layout.

## Ví dụ luồng

Linh mở Profile → ProfileActions.refresh → repository.refreshCurrentUser(uid) → Firebase reload/userChanges → thông tin mới. Linh nhập `  Linh Nguyễn  ` → form/controller validate → repository.updateDisplayName(uid, `Linh Nguyễn`) → Firebase updateDisplayName → SDK stream cập nhật tên ở Profile và lời chào Notes. Khi SDK báo lỗi, draft vẫn còn để retry; chỉ thành công mới đóng form. Auth profile của client khác cần reload/fresh sign-in, không tự claim realtime.

## Acceptance → evidence → trạng thái

| Acceptance | Evidence | Trạng thái |
| --- | --- | --- |
| UID/email/name đúng tài khoản, default avatar, route private | Guard + widget tests; real Android form kiểm UID/email/default | PASS |
| Tên rỗng bị chặn, tên hợp lệ lưu thật | Widget/adapter tests; form production + Firebase thật nhận tên Unicode đã trim | PASS Android SDK/UI; Web owner QA chờ |
| Reload và client khác đọc đúng profile | Android test mở Firebase app phụ thứ hai, fresh sign-in đọc đúng tên đã lưu; sửa từ client thứ hai rồi Refresh trên form client đầu nhận đúng tên | PASS hai client SDK Android; chưa phải Web↔Android hoặc OS cold restart |
| SDK/lưu lỗi không giả thành công, cho retry | Tests network error giữ tên cũ trong snapshot/draft, không hiện success; duplicate gửi đúng một request | PASS cô lập; mạng thật W2-04 NOT RUN |
| Logout/A→B không hiện profile/draft/feedback A | Widget late A failure, key UID, private route/guard; controller autoDispose + lease generation | PASS cô lập |
| Avatar vắng/hỏng có fallback | Widget test invalid URL và HTTPS image HTTP 400; Android default avatar | PASS fallback; upload/persistence ảnh W2-05 NOT RUN |
| Responsive và keyboard | Widget 360×800, text scale 1.6, edit/cancel/logout không exception; onFieldSubmitted gọi cùng save guard | PASS cô lập; Web keyboard owner QA chờ |
| Peer review/merge | Cần M2 UI và M3 Auth boundary | PENDING |

## Kết quả kiểm tra

- Full unit/widget suite: **94/94 PASS** (83 trước + 11 ca hồ sơ). Giữ toàn bộ assertions Auth/Notes đã có.
- `flutter analyze --no-pub`: **PASS**, không có issue. Đã bỏ unnecessary non-null assertion trong integration test.
- Format trong phạm vi task: **25 file, 0 thay đổi**. Toàn repo còn format drift có sẵn ở `lib/features/notes/data/local_note_repository.dart` và `test/widget_test.dart`; hai file không sửa trong task.
- Web release với `config/firebase.web.json`: **build PASS**, server tại `http://127.0.0.1:8085`. Lượt login/edit/reload Web và đối chiếu Android do owner thực hiện, chưa nhận kết quả.
- Android integration `profile_real_test.dart`: **1/1 PASS, 26 giây**, dùng form production, repository/controller thật và Firebase thật; không fake repository. Hai Firebase app phụ tách khỏi primary owner session. Password random chỉ ở RAM. Xóa đúng account vừa tạo theo UID/email và xóa app phụ trong cleanup. Không chứng minh email delivery, Web runtime hoặc OS restart.
- Android test APK build/install PASS. Bản app entrypoint `lib/main.dart` build PASS, `adb install -r` thành công, force-stop và gửi lệnh mở MainActivity thành công sau test. Không gỡ app/xóa dữ liệu owner. Công cụ chụp cửa sổ emulator trả khung đen hoặc nhầm cửa sổ Codex sau khi thử lại, nên chưa xác nhận giao diện cold launch bằng quan sát thủ công. SDK/UI integration PASS ở trên không tự chứng minh lượt cold launch này. APK debug không phải release ký nộp final.
- Giữ workaround Kotlin C:/D: chỉ trong lượt chạy và khôi phục nguyên bytes gradle.properties bằng finally. Không đổi SDK/dependency/schema/rules/billing; warning KGP/native-access vẫn thuộc toolchain.

## Tái kiểm thử

```powershell
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
flutter test --no-pub --no-uninstall integration_test/profile_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --reporter expanded
flutter build web --release --no-pub --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --no-pub --dart-define-from-file=config/firebase.android.json
```

QA Web/Android owner: login account test → Profile → sửa tên → reload/reopen → mở cùng account trên nền tảng kia/Refresh để đối chiếu. Không gửi password vào chat hoặc evidence. CLI hai client trên Android chứng minh persistence backend, không thay lượt cross-platform này.

## Bàn giao

API implementation M1 chờ review; chưa phải contract signoff của nhóm. M2 review header/profile/shared Auth layout, M3 review UID/session/Firebase boundary. Không tự approve/merge hoặc close toàn bộ R06 khi thiếu avatar upload.

Task kế tiếp sau khi owner tổng kết và xác nhận: **W2-05 avatar**. Cần kiểm tra storage/billing hiện tại và chốt quyền upload/delete với M3; không tự bật Blaze hoặc đổi backend. Các lượt QA giao diện W2-03 và reset Android W2-02 còn chờ kết quả, không tự đổi thành PASS.
