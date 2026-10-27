# Đọc hiểu phần M1 W1

Tài liệu này giải thích code hiện có để M1 tự đọc, debug và trình bày; không thay thế việc chạy app và đọc source.

## 1. Luồng tổng thể

`main.dart` tạo ProviderScope (vùng chứa state Riverpod) và chạy NoteFlowApp. `app.dart` chỉ cấu hình theme và MaterialApp.router. Không đặt logic Firebase trong widget root.

`firebase_config.dart` nhận client identifiers thật lúc build qua dart-define. Khác với biến môi trường runtime trên server, các giá trị này được nhúng vào app; vì vậy chỉ đưa config client công khai, không đưa admin key/password/LLM key. Thiếu config thì báo lỗi và giữ app ở màn hình session.

## 2. Tại sao cần repository?

`AuthRepository` là hợp đồng của tầng Auth (W2-01 bổ sung gửi mail và reload). `FirebaseAuthRepository` là implementation dùng Firebase SDK. UI không gọi trực tiếp FirebaseAuth.instance. Test có thể thay implementation bằng fake để tái hiện lỗi mạng và giữ request đang chạy; app production không có chế độ fake.

Đăng ký W2-01: SDK tạo account → Firebase tự đăng nhập → updateDisplayName → sendEmailVerification. Các bước không phải transaction: account có thể tạo thành công nhưng đổi tên/gửi mail thất bại. RegistrationResult giữ UID, verificationSent và warning để UI báo đúng; thử đăng ký lại cùng email sẽ sai. Lỗi tên không ngăn thử gửi mail.

UID là định danh Firebase cấp, không phải email hay ID mình tự sinh. `AuthUser` là snapshot nhỏ để module khác không phải import SDK Firebase và không cầm password/token.

## 3. Provider và stream

Future trả một kết quả; stream trả nhiều sự kiện theo thời gian. Login/logout/reload/token update đều có thể đổi session, kể cả từ tab khác. Bởi vậy điều hướng nghe stream `userChanges()` thay vì chỉ chuyển trang sau khi nút login trả về.

`authSessionProvider` có loading, error hoặc data. `data(null)` nghĩa là đã xác định chưa đăng nhập; loading nghĩa là chưa biết. Không đánh đồng hai trạng thái này khi phục hồi phiên.

Riverpod có thể giữ giá trị user cũ trong khi refresh. `sessionPhase` kiểm tra loading/error **trước** khi đọc data; `authenticatedUidProvider` vì thế không đưa UID cũ cho module khác.

## 4. Guard làm gì?

`session_guard.dart` là hàm quyết định redirect độc lập, dễ test. `app_router.dart` nghe session để yêu cầu go_router đánh giá lại. Không tạo một router mới mỗi lần session đổi, tránh mất history không cần thiết.

Guard dùng allowlist public: chỉ login/register được public trong W1. Thêm route mới mặc định phải login. `/session` không chứa dữ liệu riêng nên có thể hiện khi chưa xác định được phiên. Home còn kiểm tra authenticatedUserProvider để không lộ dữ liệu ở một frame trước redirect.

Backend không biết người dùng có đi qua guard không. Người ta có thể gọi API trực tiếp; vì vậy M3 phải kiểm UID/quyền bằng backend/rules. Guard và rules giải quyết hai lớp khác nhau.

## 5. Form và busy

`auth_form.dart` là adapter provider/router; `screens/login_screen.dart` và `screens/register_screen.dart` giữ TextEditingController trong đời widget và dispose khi rời form. Các screen nhận callback, isLoading/error từ adapter để giữ UI tách Firebase. Validation kiểm email, tên, password đăng ký và confirmation trước request. Không trim password vì khoảng trắng có thể là ký tự người dùng chọn.

`AuthActions._run`: đặt busy trước await, chặn gọi lặp ngay cả khi UI chưa kịp repaint, đổi lỗi thành thông báo, luôn kết thúc busy khi request hoàn tất/lỗi. UI disable cả field/nút khi bận. Không tự dùng timeout rồi cho gửi request thứ hai khi SDK vẫn còn thao tác tạo account chưa hủy được.

Không tạo session chỉ vì Future hoàn tất: nguồn sự thật vẫn là Firebase stream. Lỗi không in input hoặc SDK raw message ra log.

## 6. Đổi tài khoản và cleanup

`accountSessionProvider` tạo một lease theo UID. Khi A mất phiên/đổi sang B, lease A đóng; callback chậm cần kiểm isActive trước cập nhật. M2/M3 watch provider và dùng ref.onDispose hủy listener của mình. Một ValueKey(uid) ở widget không tự dọn database cache hoặc sync queue; việc đó nằm ở owner repository.

## 7. Các loại bằng chứng

- Unit test: kiểm quyết định guard, state và lifecycle provider.
- Widget test: bơm thao tác vào form và kiểm nội dung/nút/error/navigation bằng fake.
- Build: chứng minh trình biên dịch đóng gói source được; chưa chứng minh server nhận account.
- Chạy Firebase thật: tạo user, đối chiếu UID, reload/restart/logout/Back/mạng trên Web/Android; mới chứng minh luồng tích hợp thực tế.
- Gate W1 còn cần nhóm review/chốt contracts, không thể được thay bằng số lượng test.

Ba file integration có mục đích khác nhau: auth_real_test gõ/bấm form thật và đối chiếu Firebase UID; auth_persistence_test giữ session ở phase seed rồi đối chiếu UID ở tiến trình verify; auth_network_test gọi controller/SDK khi guest emulator mất mạng và kiểm tra lỗi/loading trên UI. Persistence dùng --no-uninstall vì gỡ app sẽ xóa dữ liệu phiên; force-stop mới đúng tình huống đóng app cần kiểm tra. Password test sinh ngẫu nhiên chỉ ở RAM, chỉ UID công khai được chuyển giữa hai tiến trình.

## 8. Email verification W2-01: đọc theo ví dụ

Ví dụ Linh đăng ký bằng inbox mình sở hữu:

1. RegisterScreen kiểm input rồi gọi AuthForm → AuthActions.register. Repository tạo account thật; SDK stream đưa Linh vào home ngay, dù email chưa verify. Không chờ Future gửi mail để quyết định session.
2. Repository thử lưu tên và gửi mail. Nếu mạng lỗi sau khi account đã tạo, RegistrationResult báo warning “Không đăng ký lại”; banner có nút gửi lại. Nếu request mail thành công, chỉ nói đã yêu cầu gửi: SDK không chứng minh inbox đã nhận.
3. Future và stream không có thứ tự bảo đảm. AuthActions theo dõi UID transitions trong lúc đăng ký, giữ kết quả vào verificationActionsProvider(uid) kể cả khi session event đến sau. Nếu đã đổi account/logout thì bỏ kết quả. Test chủ động tái tạo race này.
4. VerificationBanner hiển thị địa chỉ nhận từ SDK để đối chiếu inbox, gọi controller resend → repository kiểm expectedUid trùng SDK currentUser → sendEmailVerification(). Controller chặn gửi lặp ngay, bật busy, rồi cooldown 60 giây sau request thành công. Nút kiểm tra vẫn dùng được trong cooldown. Firebase có rate limit độc lập; reload app có thể reset cooldown UX.
5. Linh mở link trong email: trang HTTPS Firebase xử lý code ngoài Flutter. Không cần tạo route activation trong app. Quay lại app phát lifecycle resumed hoặc nhấn “Kiểm tra xác minh” → controller.refresh → repository.refreshCurrentUser(uid) → User.reload() → userChanges() phát snapshot emailVerified mới → banner biến mất.
6. Refresh lỗi giữ banner/session, hết loading và báo lỗi. Không tự đặt verified=true để tạo cảm giác thành công. Nếu Linh logout hoặc chuyển sang B khi request đang chạy, lease cũ bị đóng; controller bỏ callback đó, B dùng state riêng theo UID. Cùng UID đăng nhập lại cũng là lease mới.

Đọc các file: domain/auth_repository.dart (RegistrationResult/API) → data/firebase_auth_repository.dart (SDK và lỗi từng bước) → application/auth_providers.dart (đăng ký/Future-stream) → application/verification_providers.dart (busy/cooldown/lease) → presentation/verification_banner.dart (nút/lifecycle) → features/home/home_screen.dart (shell). Các đường dẫn Auth bắt đầu ở lib/features/auth/.

Tests mới: test/firebase_verification_repository_test.dart kiểm các bước SDK bằng stub; test/verification_test.dart kiểm UI/state/lifecycle/account switch. Đây là tests cô lập. Email thật, handler thật, native/browser và reload phải đối chiếu riêng trong m1-week2-verification.md. Khi M2 đưa Notes vào shell, cần giữ banner này; banner ở HomeScreen không tự bảo đảm Notes consumer đã tích hợp.

## Tự kiểm tra trước vấn đáp

1. Vì sao loading không được coi là signed-out?
2. Nếu Firebase tạo account xong nhưng updateDisplayName lỗi, UI phải nói gì?
3. Tại sao callback login thành công không tự điều hướng?
4. Nếu chỉ ẩn nút sửa note thì người có quyền read có gọi API sửa được không?
5. Provider nào phải watch để không giữ listener tài khoản A khi đăng nhập B?
6. Tại sao API key client Firebase được dùng trong app nhưng service-account key không được?

Mở source theo thứ tự: main → app/theme → domain/auth_repository → data/firebase_auth_repository → application/auth_providers → routing/session_guard → routing/app_router → auth_form → screens/login_screen và register_screen → home → tests.
