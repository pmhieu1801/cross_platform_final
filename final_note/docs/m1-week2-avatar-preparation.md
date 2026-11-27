# W2-05 — Chuẩn bị avatar, upload đang chờ storage

Ngày kiểm tra **22/11/2026**. M1 `pmhieu1801`, R06 [#8](https://github.com/pmhieu1801/cross_platform_final/issues/8). Nhánh `pmhieu1801/m1-week2-avatar-preparation`, base `34fd59b` của PR hồ sơ #36. GitHub main `36b734b`; PR #36 vẫn draft/chưa merge khi bắt đầu.

## Quyết định và blocker đã xác minh

Firebase Console của đúng project `noteflow-3f90d` hiển thị **Spark / No-cost**, trang Storage yêu cầu nâng Blaze. [Ảnh bằng chứng](evidence/w2/storage-spark-blocked.jpg). Đối chiếu [tài liệu Firebase](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

Owner chọn: **“Chưa chọn; giữ Spark, hoàn thiện phần độc lập trước”**. Vì vậy không nâng billing, tạo bucket, đổi backend, thêm Firebase Storage/picker hoặc mở rules để demo. Không dùng local path/base64 trong photoURL để giả lưu bền. **Toàn bộ W2-05/R06 chưa Done.**

## Phần đã triển khai độc lập

- `lib/features/auth/domain/avatar_repository.dart`: AvatarImage chứa bản copy bytes không cho sửa, MIME và chiều ảnh đã giải mã. AvatarUploadReceipt chứa ownerUid, storageKey opaque và HTTPS photoUrl; từ chối receipt thiếu identity hoặc URL có user-info. AvatarRepository là interface upload/deleteUploaded, chưa có implementation/provider production.
- `lib/features/auth/application/avatar_image_validator.dart`: không đọc file, không mạng, không đổi Auth. Chặn ảnh rỗng/quá dung lượng; nhận dạng chữ ký JPEG/PNG; MIME khai báo nếu có phải khớp; đọc encoded dimensions trước khi cấp phát frame; giải mã frame thật; trả thông báo cố định khi codec lỗi và dispose tài nguyên trong finally. Copy input trước await, trả payload immutable để caller không thay bytes sau validation.
- `test/avatar_image_validator_test.dart` và `test/support/avatar_test_images.dart`: ảnh 16×16 một màu tự sinh, không dùng ảnh cá nhân. Kiểm byte/dimension boundary, ảnh hỏng, GIF/SVG giả MIME, JPEG/PNG, buffer mutation và receipt hợp lệ.
- Default/loading/error avatar đã có trong W2-04, tiếp tục giữ nguyên. Không thêm nút upload giả hoặc tự công bố ảnh local là ảnh đã lưu.

Giới hạn mặc định **JPEG/PNG, 2 MiB, tối đa 4096×4096** là lựa chọn triển khai dựa trên plan, cần review, không phải số bắt buộc trong PDF. Picker tương lai phải kiểm dung lượng trước khi đọc toàn bộ file vào RAM; backend vẫn phải kiểm lại quyền/type/size và xử lý nội dung ảnh phù hợp. Validation ở client và receipt constructor không thay server authorization.

## Luồng khi backend sẵn sàng — contract, chưa phải implementation

Picker → AvatarImageValidator → AvatarRepository.upload(expectedUid,image) → receipt → kiểm lease/UID → cập nhật Auth.photoURL → SDK stream công bố avatar mới. Upload thành công chưa đủ để đổi ảnh đang hiển thị. Nếu metadata lỗi, giữ avatar cũ và cleanup đúng object bằng receipt; không suy target xóa từ URL avatar cũ. Nếu chuyển A→B, không công bố callback A hoặc cleanup A bằng credentials B. Cách lưu, read policy, path schema và cleanup retry cần owner backend/M3 chốt.

Ví dụ chọn một PNG nhỏ hợp lệ: validator trả bytes/MIME/width/height, không upload hay lưu avatar. File chỉ đổi đuôi thành .png nhưng dữ liệu là SVG bị chặn trước codec. PNG có header nhưng hỏng nội dung bị codec từ chối. Ảnh lớn hơn 2 MiB bị chặn trước giải mã.

## Acceptance → evidence → trạng thái

| Acceptance | Evidence | Trạng thái |
| --- | --- | --- |
| Xác minh nơi lưu/billing và giữ lựa chọn owner | Console đúng project, ảnh Spark/Blaze requirement, owner chọn giữ Spark | PASS kiểm tra; upload BLOCKED |
| Interface tách storage khỏi widget | AvatarRepository/upload receipt/immutable image; chưa cài backend production | PASS phần chuẩn bị |
| Type/MIME/dung lượng/dimension/ảnh hỏng | 11 tests với codec Flutter thật, gồm valid JPEG/PNG và lỗi/boundary | PASS engine host; Chrome kiểm riêng bên dưới |
| Default/error fallback | Source và tests W2-04 giữ nguyên, full suite chạy lại | PASS phần đã có |
| Chọn/hủy ảnh bằng picker thật | Chưa thêm picker trước quyết định storage | NOT RUN |
| Upload, metadata failure/cleanup, reopen/cross-platform avatar | Chưa có storage/rules/provider hoặc Auth photoURL mutation | BLOCKED / NOT RUN |
| B không sửa/xóa avatar A ở backend | Interface yêu cầu expectedUid, chưa triển khai backend/rules | NOT RUN; client tests không chứng minh denial |

## Kiểm thử

- Focused validator: **11/11 PASS** trên Flutter test engine, có giải mã ảnh thật.
- Full unit/widget suite: **105/105 PASS**; giữ 94 tests trước đó.
- Format phần thay đổi: **4 file, 0 thay đổi**; `flutter analyze --no-pub`: **PASS**, không có issue. Lượt analyze đầu cảnh báo ở file render tạm W2-04 trong tmp; đã dọn file helper sau khi ảnh render hoàn tất, không sửa/suppress analyzer hoặc assertions của tests production.
- Chrome unit runner: **CHƯA KẾT LUẬN**. Hai lượt kẹt ở loading suite; lượt verbose compile xong và mở Chrome headless nhưng không trả test result, kể cả khi đặt test timeout 60 giây. Đã dừng tiến trình test sau khi chẩn đoán, không skip hoặc đổi assertion, không ghi Web decoder PASS từ kết quả host engine. Đây là giới hạn còn phải kiểm tra khi tích hợp picker/storage.
- Không chạy lại build/runtime app Web/APK riêng cho slice này: chưa nối UI/SDK/picker/storage hoặc đổi dependency. Không dùng build cũ để claim avatar upload PASS. Library được compile/test riêng; Chrome decoder không đồng nghĩa backend avatar chạy thật.

```powershell
flutter test --no-pub test/avatar_image_validator_test.dart --reporter expanded
flutter test --no-pub --platform chrome test/avatar_image_validator_test.dart --reporter expanded
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
```

## Bàn giao và điều kiện tiếp tục

PR chuẩn bị phải giữ draft, ghi rõ thiếu upload. M2 review UI integration sau khi có picker/backend; M3 review storage ownership, read/write/delete, kiểm soát file và cleanup. Chưa đổi schema/rules, không close R06.

Để hoàn tất W2-05 cần owner chọn kho ảnh phù hợp Spark hoặc tự quyết định Firebase billing ngoài phạm vi đã chốt, rồi M3 xác nhận quyền và kiểm backend thật trên hai tài khoản. Trong lúc chờ có thể làm **W2-06 preferences** sau khi owner đọc tổng kết và đồng ý; không tự bắt đầu task mới trong lượt này.
