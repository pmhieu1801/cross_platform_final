# W2-06 — Cài đặt giao diện theo UID

Ngày kiểm tra **22/11/2026**, M1 `pmhieu1801`; R08 [#10](https://github.com/pmhieu1801/cross_platform_final/issues/10), tích hợp Grid/List R09/R10. Nhánh `pmhieu1801/m1-week2-preferences`, base `5e95386` của PR #37. GitHub main `36b734b`; PR #37 còn draft khi bắt đầu. Contract này là implementation chờ M2 review, chưa phải signoff của nhóm.

## Hành vi và phạm vi

- Settings private `/preferences`: theme Dark/Light/System, cỡ chữ ghi chú 85–150%, Grid/List. Defaults Dark/100%/Grid giữ nền hiện có và yêu cầu Grid mặc định. Giới hạn font là lựa chọn triển khai, không phải số bắt buộc của PDF.
- Lưu local bằng dependency `shared_preferences` đã có: mỗi Firebase UID có key `noteflow_user_preferences_v1_<base64url(uid)>`, payload schemaVersion 1. Không dùng email làm khóa, không có password/token, không đổi namespace/cache Notes hoặc backend/rules/billing.
- Lưu riêng từng thiết bị/trình duyệt/origin, **không đồng bộ cloud giữa Web và Android**. Logout giữ dữ liệu dưới UID của account đó để phục hồi khi quay lại; UI bỏ lựa chọn A ngay khi phiên mất/đổi/loading/error, rồi đọc B.
- Save chỉ áp dụng theme/font/view sau khi store trả thành công. Lỗi giữ draft và giá trị đang áp dụng, có retry; Restore defaults ghi riêng key UID hiện tại. Dữ liệu hỏng/unknown version dùng defaults, báo warning, không tự ghi đè; explicit Save/Restore mới thay payload.
- Toggle Grid/List ở Notes dùng cùng controller/repository; lưu lỗi không giả đã chuyển và hiện thông báo ngay gần control. Standalone Notes preview không có account vẫn giữ local layout như trước.
- Notes nhận props viewMode/onViewModeChanged/noteFontScale; font áp dụng ở title/content của card/list và editor, tăng chiều cao grid khi chữ lớn. Notes đã dùng theme tokens; MaterialApp đọc theme qua provider. Không thay NoteRepository, CRUD, autosave, label, sharing hoặc sync của M2/M3.

## File và luồng

`lib/features/preferences/domain/user_preferences.dart` giữ model/enum/schema và repository contract. `data/local_preferences_repository.dart` đọc/ghi store; `application/preferences_providers.dart` điều phối theo lease; `presentation/preferences_screen.dart` giữ draft. App/router/Home nối settings vào giao diện Notes hiện có, không tạo Notes screen thay thế.

Ví dụ Linh chọn Light, 130%, List → form giữ draft → AccountPreferences.save → LocalPreferencesRepository ghi JSON dưới UID Linh → thành công mới publish value → MaterialApp đổi theme, Notes đổi list và chữ lớn hơn. Đóng/mở lại, repository đọc đúng key; đổi sang B thì defaults hoặc lựa chọn đã lưu của B được dùng. Toggle Notes cũng đi qua luồng save này, không còn chỉ setState cục bộ trong production.

`effectivePreferencesProvider` là projection an toàn bắt buộc cho consumer: checking/loading/error/UID không khớp trả defaults, không đọc stale AsyncValue của A. AsyncNotifier build theo account lease; callback save kiểm generation/lease/ref.mounted. Repository xếp FIFO theo UID, kể cả A→logout→A, và load đợi write đang chờ; B không bị queue A chặn. Settings screen có key UID để bỏ draft A.

Giữ legacy SharedPreferences API cùng app để tránh đổi backend/prefix hoặc migration Notes ngoài phạm vi; reload cache trước read và kiểm bool trả về của write. [Tài liệu plugin](https://pub.dev/packages/shared_preferences) khuyến nghị API Async/WithCache cho ứng dụng mới; migration/multiple-engine use cần review riêng. Dữ liệu ở đây là cài đặt không nhạy cảm. Kiểm thử persistence dưới đây là normal process restart, không phải reboot OS hoặc bảo đảm trước mất điện.

## Acceptance → evidence → trạng thái

| Acceptance | Evidence | Trạng thái |
| --- | --- | --- |
| Private screen, defaults, save/reset, keyboard/layout | Guard + widget tests; 360×800 text scale 1.6; draft mất khi rời trang | PASS cô lập |
| Theme Dark/Light/System và font được consumer dùng | Widget tests root theme, platform brightness System, grid/list title/content và editor; [dark preview](evidence/w2/preferences-dark-preview.png), [light preview](evidence/w2/preferences-light-preview.png) | PASS cô lập; ảnh render dùng fixture, không phải backend evidence |
| Grid/List giữ sau load lại, lưu lỗi không chuyển giả | Widget UI toggle/save failure/retry/reload và repository tests | PASS |
| Lỗi đọc/ghi, dữ liệu hỏng/default/version | Fake store tests bool=false/throw, invalid JSON/type/enum/version/scale; không ghi đè tự động; retry/reset theo UID | PASS cô lập |
| A/B và callback muộn không lẫn settings | Widget late A→B loading, A→null→A, FIFO; Android SDK account switch | PASS các ca đã chạy |
| Android giữ lựa chọn sau tắt tiến trình | Real Auth/UI/plugin seed, force-stop, lượt verify mới đọc đúng A/B rồi cleanup | PASS 2/2 lượt, xem chi tiết |
| Web reload/reopen | Web release build + Login thật đã quan sát; [ảnh Login](evidence/w2/preferences-web-login-ready.jpg). Chờ owner tự login/save/reload Settings | PENDING; không suy Web persistence từ Android |
| Nhóm chốt API và peer review/merge | Cần M2 review consumer/theme/font/layout; M3 review UID/session boundary | PENDING |

## Kết quả kiểm tra

- Full unit/widget suite cuối: **121/121 PASS** (105 trước + 5 repository + 11 widget mới). Không bỏ assertion hoặc skip test cũ.
- `flutter analyze --no-pub`: **PASS**, không có issue. Format trong phạm vi: **15 file, 0 thay đổi**. Format drift có sẵn ở LocalNoteRepository và test/widget_test.dart không sửa trong task.
- Android real integration, run `1795339368162`: **seed 1/1 PASS, 14 giây**; **verify 1/1 PASS, 1 giây**. Seed dùng repository/controller/form production, Firebase Auth thật và SharedPreferences plugin thật. Hai account mới có cài đặt khác nhau; A→B nhận defaults B, B lưu riêng, quay A phục hồi đúng. Notes content dùng InMemoryNoteRepository fixture, không claim persistence/backend Notes.
- Seed cleanup xóa đúng hai account vừa tạo theo UID/email và Firebase app phụ; primary owner Auth session không bị tác động. Chỉ để lại marker chứa runId/UIDs (không mật khẩu) và hai key prefs test. Sau force-stop, verify khởi động tiến trình mới, reload store, đối chiếu hai payload; finally xóa đúng các key từ marker của lượt seed và marker. Password ngẫu nhiên chỉ ở RAM, không chuyển sang verify.
- Web release main build **PASS**, phục vụ lại trên port 8085 để dùng cùng origin; các server thử cũ đã dừng. Chờ owner QA Settings trong browser, không claim UI Web đã lưu/reload khi chưa nhận kết quả.
- Bản main Android debug APK **build PASS**, cài cập nhật `adb install -r` thành công; force-stop và mở MainActivity bằng lệnh thành công. Chưa có lượt quan sát cold-launch bằng công cụ chụp cửa sổ sau cài, giữ giới hạn capture đã ghi ở W2-04. Debug APK không phải release ký để nộp final. Tùy chọn Kotlin local C:/D: chỉ áp trong lượt build/test và khôi phục nguyên bytes gradle.properties trong finally; warning KGP/native-access vẫn thuộc toolchain.
- Ca Grid/List phát hiện vòng phụ thuộc khi controller đọc provider projection phụ thuộc ngược chính nó; sửa callback dùng current controller state. Test Notes cuộn đúng ListView, tránh scrollable nội bộ SelectableText/tooltip và giữ các assertions dữ liệu/UI. Preview helper chỉ dùng render ảnh với font app/dữ liệu giả, đã dọn khỏi source sau render.

## Tái kiểm thử

```powershell
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
flutter build web --release --no-pub --dart-define-from-file=config/firebase.web.json
flutter build apk --debug --no-pub --dart-define-from-file=config/firebase.android.json
$preferencesTestRun = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
flutter test --no-pub --no-uninstall integration_test/preferences_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --dart-define=PREFS_PHASE=seed --dart-define=PREFS_TEST_RUN=$preferencesTestRun --reporter expanded
# Chỉ verify sau seed PASS; không uninstall vì sẽ xóa dữ liệu cần kiểm chứng.
adb -s emulator-5554 shell am force-stop com.example.final_note
flutter test --no-pub --no-uninstall integration_test/preferences_real_test.dart -d emulator-5554 --dart-define-from-file=config/firebase.android.json --dart-define=PREFS_PHASE=verify --dart-define=PREFS_TEST_RUN=$preferencesTestRun --reporter expanded
```

## Bàn giao và phần tiếp theo

M2 review API props/provider và xác nhận consumer Notes phù hợp ownership; M3 review lease/UID isolation. Không tự approve/merge. Local schema mới chỉ thuộc cài đặt, không thay schema backend hay Note store. Avatar W2-05 vẫn chờ kho ảnh theo quyết định giữ Spark; chưa có upload thật.

Sau tổng kết và owner xác nhận mới làm **W2-07 — Auth regression/evidence**. Các lượt QA chủ tài khoản ở Web/change password/profile/reset Android còn thiếu phải giữ PENDING, không tự suy PASS từ việc owner cho tiếp task khác. W2-08 Gate nhóm còn phụ thuộc demo CRUD/share/API denial/autosave của đúng owner M2/M3.
