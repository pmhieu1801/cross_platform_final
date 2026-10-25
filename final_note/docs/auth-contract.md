# Auth contract W1 - bàn giao M1 → M2/M3

**Trạng thái: triển khai M1, chờ M2/M3 review. Không phải biên bản nhóm đã chốt.**

## API đang tồn tại

Source: `lib/features/auth/domain/auth_repository.dart`, `application/auth_providers.dart`.

| Thành phần | Contract |
| --- | --- |
| AuthUser | uid:String, email:String?, displayName:String?, emailVerified:bool; snapshot bất biến, không có password/token |
| AuthRepository | watchSession(), signIn(email,password), register(email,displayName,password), signOut() |
| authSessionProvider | AsyncValue<AuthUser?>: loading chưa biết phiên; data(null) signed out; data(user) signed in; error không xác định được phiên |
| authenticatedUserProvider | Chỉ trả user khi có dữ liệu phiên chắc chắn; null cả khi loading/error dù Riverpod đang giữ kết quả cũ |
| authenticatedUidProvider | UID Firebase nguyên bản hoặc null; không dùng email làm khóa dữ liệu |
| accountSessionProvider | AccountSession(uid,isActive); lease cũ bị đóng khi UID đổi/null/error/loading |
| authActionsProvider | busy/error của thao tác Auth; duplicate calls bị bỏ qua; lỗi SDK được đổi thành thông báo an toàn |

Firebase adapter dùng `userChanges()`: bao gồm các sự kiện của `authStateChanges()` cộng profile/reload/token events. Chỉ dùng stream làm nguồn session; hoàn tất Future login chưa đủ để mở route. Firebase SDK giữ persistence mặc định Web và Android. Không lưu password, token hay biến boolean login trong app. Thay đổi profile từ Admin/Console cần `User.reload()` ở W2; không tự giả định verify flag luôn cập nhật theo thời gian thực.

## Khởi tạo và điều hướng

1. ProviderScope → Firebase.initializeApp(options client thật) → FirebaseAuth.instanceFor → session stream.
2. Chờ sự kiện đầu tiên để quyết định signed-out/signed-in. Firebase phục hồi phiên của lần chạy trước ở bước này.
3. Public W1: `/login`, `/register`. Private: `/home`; route mới mặc định private. `/session` là màn hình kỹ thuật chờ/error, không chứa dữ liệu người dùng.
4. Checking/error → `/session`; signed out + private URL/Back → `/login`; signed in + auth route → `/home`. Guard không giữ return URL và luôn về home sau login (lựa chọn W1).
5. Web dùng URL hash mặc định `/#/home`; không đổi sang path strategy khi chưa cấu hình hosting rewrite. Unknown route với signed-in có trang not-found; signed-out vẫn redirect.
6. W2 phải bổ sung activation/reset public routes vào allowlist khi thật sự có implementation.

Guard chỉ bảo vệ UI. M3 vẫn phải kiểm tra `request.auth.uid` và quyền note/share/attachment ở backend/rules. Hiện M1 không tạo rules, không mở Firestore/Storage và không triển khai schema dữ liệu.

## Activation

Tài khoản đăng ký thành công tự có session. Adapter cập nhật displayName vào Firebase Auth; nếu bước đó lỗi sau khi tạo account, UI báo rõ account đã tạo, tránh khuyến khích đăng ký trùng. `emailVerified == false` hiển thị banner thường trực ở private shell, không chặn chức năng. W1 chưa gửi email/xử lý link/reload verify state tự động; các phần đó thuộc W2 và cần test cả Web/native. R1/R2 vì thế chưa hoàn thành toàn phần theo đề gốc.

## Logout và ranh giới tài khoản

- UI gọi `authActionsProvider.notifier.signOut()`, repository gọi Firebase.signOut(). Khi thất bại, báo lỗi và giữ session đúng SDK; không giả thành công.
- Khi stream phát null, guard đóng private UI ngay; Auth action feedback được xóa, form cũ dispose các TextEditingController chứa password.
- Khi A → B trực tiếp, provider lấy UID B, lease A có `isActive == false`; Home dùng key UID để không tái sử dụng state gắn account.
- M2/M3 phải **watch** accountSessionProvider trong provider dịch vụ của mình và đăng ký `ref.onDispose` để cancel stream/subscription/debounce/timer. `read` một lần không theo dõi chuyển tài khoản.
- Callback bất đồng bộ đã chạy có thể trả về muộn: kiểm tra `session.isActive` và `ref.mounted` trước publish kết quả. Không cho queue của A chạy bằng credentials của B.
- M2 quản lý dữ liệu hiện trong UI/cache local; M3 quản lý listener/rules/sync queue. Prefix cache/queue theo UID, bỏ dữ liệu đang hiển thị ngay khi phiên mất. Chính sách giữ/xóa cache offline và pending ops phải do owner chốt; M1 chưa triển khai hoặc bảo đảm dọn cache của module chưa có.

Ví dụ tích hợp provider (minh họa, tên repository là chỗ M2 điền, không phải API đã tồn tại):

```dart
final itemsProvider = StreamProvider.autoDispose((ref) {
  final session = ref.watch(accountSessionProvider);
  if (session == null) return const Stream<List<Note>>.empty();
  final repository = ref.watch(noteRepositoryProvider);
  // SDK stream tự cancel khi provider dispose/recompute.
  // Nếu tự listen ngoài stream trả về: ref.onDispose(subscription.cancel).
  return repository.watchForUser(session.uid);
});
```

UI consumer phải bỏ kết quả trước khi loading/error hoặc session không hợp lệ; không hiển thị `.value` cũ từ AsyncValue khi đổi UID. Có thể tạo provider family theo UID và key subtree theo UID; vẫn bắt buộc cancellation và partition storage ở tầng repository. Test mẫu lifecycle nằm trong `test/auth_actions_test.dart`.

## Contracts dữ liệu cần owner xác nhận

Đã đối chiếu lại main `3486542` khi tích hợp PR #28. Nhóm đã có `lib/models/note.dart`: id, title, content, labels (List<String>), colorIndex, updatedAt, isPinned và pinnedAt; `createDemoNotes()` và NotesHomeScreen hiện dùng dữ liệu mẫu trong bộ nhớ. Model chưa có ownerUid, NoteRepository, Label/Share/Attachment/Sync contracts. M1 giữ nguyên model/Notes UI và không tự thêm schema/backend. Các điểm bổ sung dưới đây là **đề xuất để owner review**, chưa phải quyết định nhóm.

| Contract | Owner / review | Đề xuất tối thiểu và câu hỏi chốt |
| --- | --- | --- |
| UID | M1; M2/M3 review | Firebase Auth UID; string không đổi; email chỉ để tìm user khi chia sẻ, backend resolve UID an toàn |
| User | M1 + M3 | Auth giữ email/displayName/verified; profile Firestore có cần users/{uid} không? ai được đọc trường nào? Không đưa password/token vào document |
| Note / NoteRepository | M2; M3 review | Giữ Note hiện có; cần owner chốt ownerUid, createdAt/version, UID-scoped repository stream, autosave/shared behavior, timestamp/delete. Chưa áp migration hoặc thêm trường tùy ý |
| Label | M2; M3 review | Note hiện chứa List<String> labels và demo dùng tên label. Cần chốt giữ tên hay chuyển ID, ownership, rename/delete/shared-note semantics và migration trước khi triển khai |
| Share | M3; M2 review | noteId, recipientUid, permission read/edit, revoke semantics; server/rules là nguồn quyền; không dựa vào việc ẩn nút |
| Lock | M3; M2 review | password-note tách Auth password; không lưu plaintext; chốt unlock lease, backend canRead/canEdit, key/cache khi logout và revoke |
| Attachment | M2 + M3 | id, noteId, storagePath, MIME, size, upload state; private path; M3 chốt authorization/download behavior; không public URL vĩnh viễn |
| Sync | M3 engine, M2 local store | operationId, actorUid, noteId, baseVersion, pending/synced/failed; retry/idempotency/conflict policy cần owner quyết định |

Thay đổi schema chung cần PR liên quan migration, rules và review owner. Gate contracts chưa đạt cho đến khi M2/M3 xác nhận các quyết định cụ thể bằng PR/issue. Không có migration trong W1 M1 vì chưa triển khai schema chung.

## Review bắt buộc

- hnt0411 (M2): UX form, mobile layout, cách nhận UID/session, cancellation/local partition, Note/Label/Repository/Attachment contract.
- CheetoBuri (M3): guard fail-closed, SDK Auth/persistence, UID isolation, backend boundaries, User/Share/Lock/Sync/rules proposal. Đã đọc được collaborator permission: read; M2 hnt0411: write.
- Chưa có review/chốt contract từ hai owner. PR #28 là nơi ghi câu trả lời và review; không tự phê duyệt.

## Tích hợp giao diện chung ngày 25/10/2026

AuthForm là adapter Riverpod giữa router và LoginScreen/RegisterScreen trên main. Hai widget UI nhận callback onSubmit, callback chuyển trang, isLoading và error; không tự tạo session hoặc chuyển tới home khi Future hoàn tất. Thay delay placeholder bằng callback tới AuthActions; giữ thiết kế Midnight Glow và các widget/theme/fonts của nhóm. Khi không được nối callback (ví dụ preview widget độc lập), form chỉ báo chưa cấu hình, không đăng nhập giả.

Main vẫn bọc ProviderScope; NoteFlowApp dùng AppTheme light/dark, mặc định dark theo main. Route /home vẫn là private Auth shell W1; NotesHomeScreen và demo model được giữ nguyên để owner tích hợp repository thực ở bước tiếp theo. Validation dùng Validators chung của UI; password đăng ký tối thiểu 8 ký tự, đồng thời Firebase vẫn có quyền từ chối nếu policy backend chặt hơn.
