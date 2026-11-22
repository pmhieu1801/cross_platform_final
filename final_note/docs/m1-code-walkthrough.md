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

## 9. Khôi phục mật khẩu W2-02

Ví dụ Linh đã đăng xuất và quên mật khẩu. Linh bấm **Forgot password?** ở LoginScreen. AuthForm điều hướng đến `/forgot-password` và session guard cho phép phiên signed-out đi vào form. ForgotPasswordScreen kiểm email, rồi gọi PasswordResetController. Controller đặt trạng thái loading trước khi đợi repository để ngăn gửi hai lần, kể cả khi bấm Enter và nút cùng lúc.

FirebaseAuthRepository gọi `sendPasswordResetEmail`. Nếu request được chấp nhận, màn hình hướng dẫn Linh kiểm tra inbox hoặc spam nếu email có tài khoản. Lỗi `user-not-found` từ backend đời cũ cũng dẫn đến hướng dẫn này. Lỗi mạng hoặc rate limit hiện lỗi phù hợp và bật lại nút. Khi Linh rời form trong lúc request đang chạy, provider bỏ kết quả UI của request đó.

Linh mở email bằng trình duyệt. Trang HTTPS của Firebase kiểm link một lần và cho nhập mật khẩu mới. Sau khi đổi thành công Linh quay lại NoteFlow, bấm **Back to sign in** và đăng nhập bằng mật khẩu mới. Quyết định mở home vẫn đến từ Firebase session stream. API W2-02 không gọi signIn hoặc ghi session, và mã khôi phục chỉ được xử lý tại trang Firebase.

Đọc theo đường đi `lib/screens/login_screen.dart` → `lib/features/auth/presentation/auth_form.dart` → `lib/routing/session_guard.dart` và `app_router.dart` → `forgot_password_screen.dart` → `password_reset_controller.dart` → `firebase_auth_repository.dart`.

## 10. Đổi mật khẩu W2-03

Ví dụ Linh đang ở Notes, bấm biểu tượng **Change password** và nhập mật khẩu hiện tại cùng hai lần mật khẩu mới. Router chỉ cho phiên signed-in vào `/change-password`; key UID ngăn form A được dùng lại cho B. Form kiểm mật khẩu mới tối thiểu 8 ký tự theo Validators hiện có, confirmation phải khớp, và giữ nguyên khoảng trắng trong mật khẩu.

Screen gọi ChangePasswordController, đặt busy rồi dùng repository reauthenticate bằng email từ Firebase và mật khẩu hiện tại. Sai mật khẩu hiện tại dừng trước update. Reauthentication là yêu cầu xác nhận lại danh tính cho thao tác nhạy cảm, khác với việc chỉ thấy app đang đăng nhập. Firebase vẫn có quyền từ chối mật khẩu mới theo policy backend.

Update thành công chưa phải toàn bộ luồng hoàn tất: controller yêu cầu signOut tại client này, đợi SDK stream phát null để guard đóng private route. Login hiện lời nhắc dùng mật khẩu mới; app không tự đăng nhập lại. Nếu bước signOut lỗi sau update, UI nói rõ mật khẩu đã đổi và chỉ thử lại signOut, không yêu cầu nhập lại mật khẩu cũ. Không suy từ client signOut rằng mọi thiết bị khác đã bị thu hồi phiên.

Provider chỉ giữ phase, UID và thông báo an toàn. Mật khẩu được xóa khỏi form sau request hoặc dispose. Khi lease A bị đóng, generation làm mất hiệu lực callback chậm kể cả khi cùng UID A đăng nhập lại. Controller watch lease và trả state từ build, thay vì ghi state trong listener bị kích hoạt lúc Home đang build; regression đăng ký kiểm đúng trường hợp này.

Đọc theo luồng: `lib/features/auth/presentation/change_password_screen.dart` → `application/change_password_controller.dart` → `domain/auth_repository.dart` → `data/firebase_auth_repository.dart`. Điểm mở form ở `lib/features/home/home_screen.dart`, route ở `lib/routing/app_router.dart`. `test/change_password_test.dart` kiểm form/state/races bằng fake; `test/firebase_change_password_repository_test.dart` kiểm thứ tự SDK và UID bằng stub. `integration_test/change_password_real_test.dart` dùng SDK/Firebase thật với app Firebase thứ hai và account mới chỉ thuộc lượt test, không đăng xuất tài khoản đang có của owner. Evidence của test này không thay bằng chứng thao tác giao diện Web/Android.

## 11. Hồ sơ W2-04

Ví dụ Linh mở **Profile** bằng biểu tượng người dùng ở header Notes. Router chỉ cho phiên signed-in vào và dùng key UID để form Linh không được tái dùng khi đăng nhập B. Màn hình hiển thị tên/email/UID từ Auth snapshot; email và UID không có ô sửa. Ảnh HTTPS từ Auth.photoURL được hiển thị nếu tải được, còn lại dùng avatar mặc định. Đây chưa phải upload avatar thật của W2-05.

Mở Profile gọi refresh sau frame đầu để không cập nhật provider trong lúc dựng widget. `ProfileActions` gọi repository → `User.reload()` → `userChanges()` trả snapshot mới. Nếu Linh sửa tên trên thiết bị khác, quay lại Profile hoặc bấm **Refresh profile** sẽ đọc lại từ Firebase; stream của client không tự nhận mọi chỉnh sửa từ xa ngay lập tức.

Linh bấm **Edit display name**, nhập `  Linh Nguyễn  ` rồi Save. Form/controller/adapter chặn tên chỉ có khoảng trắng. Adapter gửi `Linh Nguyễn` bằng `User.updateDisplayName`, không tự tạo document User hoặc đổi email. Firebase stream cập nhật tên trên Profile và lời chào Home. Hoàn tất Future không được dùng để giả session mới. Lưu lỗi giữ bản nhập để retry; Cancel hoặc rời màn hình bỏ draft. Callback muộn kiểm lease/generation/ref.mounted để không báo kết quả cho B.

Đọc `lib/features/auth/presentation/profile_screen.dart` → `application/profile_controller.dart` → `data/firebase_auth_repository.dart`; `profile_avatar.dart` chứa default/loading/error fallback. Các test `test/profile_test.dart`, `test/firebase_profile_repository_test.dart` kiểm form, SDK boundary và account switch. `integration_test/profile_real_test.dart` chạy form production với Firebase thật bằng account tạm và hai Firebase app phụ: client thứ hai đăng nhập mới đọc tên đã lưu, đổi tên rồi client đầu reload để nhận thay đổi. Hai client trên Android không tự chứng minh lượt Web hoặc reboot hệ điều hành.

## Tự kiểm tra trước vấn đáp

Cập nhật tích hợp 18/11/2026: `/home` đi qua HomeScreen trước khi dựng NotesHomeScreen. HomeScreen đọc phiên Firebase, cấp UID/banner/logout và nối các provider Notes theo account. Nếu router dựng NotesHomeScreen trực tiếp, widget nhận thiếu user và callbacks, nên đăng nhập đúng vẫn thiếu UID, banner và đăng xuất. Đổi lại điểm nối này làm 12 ca Auth/Verification lỗi trước đó qua trở lại, full suite đạt 68 tests. Phần lưu Notes theo UID thuộc repository nhóm đã có; dữ liệu key chung cũ cần M2 chốt cách gán owner khi chuyển store.

1. Vì sao loading không được coi là signed-out?
2. Nếu Firebase tạo account xong nhưng updateDisplayName lỗi, UI phải nói gì?
3. Tại sao callback login thành công không tự điều hướng?
4. Nếu chỉ ẩn nút sửa note thì người có quyền read có gọi API sửa được không?
5. Provider nào phải watch để không giữ listener tài khoản A khi đăng nhập B?
6. Tại sao API key client Firebase được dùng trong app nhưng service-account key không được?

Mở source theo thứ tự: main → app/theme → domain/auth_repository → data/firebase_auth_repository → application/auth_providers → routing/session_guard → routing/app_router → auth_form → screens/login_screen và register_screen → home → tests.
