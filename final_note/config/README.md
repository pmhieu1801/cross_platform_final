# Firebase client configuration

Hai file JSON là client identifiers thật đọc từ Firebase Console project `noteflow-3f90d` ngày 24/10/2026; không phải cấu hình giả và không có quyền Admin. App ID Android được đối chiếu package `com.example.final_note` trong Project Settings. Cùng API key project từ cấu hình Web được truyền vào FirebaseOptions cho cả hai nền tảng; chưa có restriction riêng theo app ở lượt setup đầu.

Đưa file phù hợp vào `--dart-define-from-file`. Không nhầm App ID Web và Android. Đổi backend cần thay cả hai file hoặc dùng `*.local.json` đã ignore. Không thêm service-account key, refresh/access token, mật khẩu hay server API key vào thư mục này.

App khởi tạo Firebase bằng explicit FirebaseOptions, không đọc google-services.json và không cần Google Services Gradle plugin cho bộ `firebase_core` + `firebase_auth` hiện tại. Nếu sau này dùng sản phẩm yêu cầu plugin/resources khác, chạy lại FlutterFire configure theo tài liệu chính thức và review diff.

Console đã có Analytics property trong quá trình setup tương tác; Flutter app không cài firebase_analytics, không truyền measurementId và không khởi tạo Analytics SDK. Billing vẫn Spark theo Console; không bật billing/Blaze. Storage bucket identifier chưa chứng minh dịch vụ Storage đã được tạo hoặc có rules; phần đó thuộc M3.
