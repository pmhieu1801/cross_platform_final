# Backlog 32 rubric - NoteFlow

ID và tên đã đối chiếu đề gốc mục IV (trang 9-14); ownership theo Workflow trang 1/5; username do M1 cung cấp. Bảng này bao phủ toàn dự án. Priority/reviewer/sprint/dependency là đề xuất điều phối, chưa được nhóm chốt. Không issue nào được đánh Done.

Theo lần kiểm tra ngày 24/10/2026, GitHub có 24 issue đã publish trong bảng; R25-R32 được chuẩn bị đầy đủ dưới đây và chưa có số issue để liên kết. Cập nhật 25/10: M3 đúng username CheetoBuri nhưng GitHub từ chối request-review 422 vì chưa nhận diện là collaborator; API permission=read trên repo công khai không chứng minh membership. M2 hnt0411 (write) đã nhận yêu cầu review PR #28. Owner cần kiểm tra/thêm invite M3 và M3 chấp nhận; không assign người khác thay owner.

Deadline và khoảng 4 tuần chính thức: **chưa xác nhận**. M1 nói hiện cuối W1. Đề gốc mục V xác nhận 4 tuần Monday-Sunday liên tiếp, mỗi thành viên >=2 meaningful commits mỗi tuần trong official period; không gán ngày hoặc chia commit vụn để đủ số.

Luồng tracker: Backlog → Ready → In Progress → PR → QA Web + Native → Demo Evidence → Done. Người khác review, PR merge, kiểm tra backend/UID và evidence thật trước Done. Fake tests/build không thay được runtime test.

| Rubric | Owner | Reviewer đề xuất | Sprint | Ưu tiên | GitHub / trạng thái |
| --- | --- | --- | --- | --- | --- |
| R01 - User registration | pmhieu1801 | hnt0411, CheetoBuri | W1 | P0 | [#3](https://github.com/pmhieu1801/cross_platform_final/issues/3) - Open |
| R02 - Account activation | pmhieu1801 | hnt0411, CheetoBuri | W2 | P1 | [#4](https://github.com/pmhieu1801/cross_platform_final/issues/4) - Open |
| R03 - User login and logout | pmhieu1801 | hnt0411, CheetoBuri | W1 | P0 | [#5](https://github.com/pmhieu1801/cross_platform_final/issues/5) - Open |
| R04 - Password reset | pmhieu1801 | hnt0411, CheetoBuri | W2 | P1 | [#6](https://github.com/pmhieu1801/cross_platform_final/issues/6) - Open |
| R05 - View profile and avatar | pmhieu1801 | hnt0411 | W2 | P1 | [#7](https://github.com/pmhieu1801/cross_platform_final/issues/7) - Open |
| R06 - Edit profile and avatar | pmhieu1801 | hnt0411, CheetoBuri | W2 | P1 | [#8](https://github.com/pmhieu1801/cross_platform_final/issues/8) - Open |
| R07 - Change password | pmhieu1801 | CheetoBuri | W2 | P1 | [#9](https://github.com/pmhieu1801/cross_platform_final/issues/9) - Open |
| R08 - User preferences | pmhieu1801 | hnt0411 | W2 | P1 | [#10](https://github.com/pmhieu1801/cross_platform_final/issues/10) - Open |
| R09 - Display notes in list view | hnt0411 | pmhieu1801 | W1-W2 | P1 | [#11](https://github.com/pmhieu1801/cross_platform_final/issues/11) - Open |
| R10 - Display notes in grid view | hnt0411 | pmhieu1801 | W1-W2 | P1 | [#12](https://github.com/pmhieu1801/cross_platform_final/issues/12) - Open |
| R11 - Create notes | hnt0411 | pmhieu1801, CheetoBuri | W1 | P0 | [#13](https://github.com/pmhieu1801/cross_platform_final/issues/13) - Open |
| R12 - Update notes | hnt0411 | pmhieu1801, CheetoBuri | W2 | P1 | [#14](https://github.com/pmhieu1801/cross_platform_final/issues/14) - Open |
| R13 - Delete notes | hnt0411 | pmhieu1801, CheetoBuri | W2 | P1 | [#15](https://github.com/pmhieu1801/cross_platform_final/issues/15) - Open |
| R14 - Auto-save notes and handle app lifecycle | hnt0411 | pmhieu1801, CheetoBuri | W2 | P0 | [#16](https://github.com/pmhieu1801/cross_platform_final/issues/16) - Open |
| R15 - Attach images/videos to notes | hnt0411 | CheetoBuri | W3 | P1 | [#17](https://github.com/pmhieu1801/cross_platform_final/issues/17) - Open |
| R16 - Attach files to notes | hnt0411 | CheetoBuri | W3 | P1 | [#18](https://github.com/pmhieu1801/cross_platform_final/issues/18) - Open |
| R17 - Pin and order notes | hnt0411 | pmhieu1801 | W2 | P1 | [#19](https://github.com/pmhieu1801/cross_platform_final/issues/19) - Open |
| R18 - Special-note status indicators | hnt0411 | CheetoBuri | W3 | P1 | [#20](https://github.com/pmhieu1801/cross_platform_final/issues/20) - Open |
| R19 - Live search for notes | hnt0411 | pmhieu1801, CheetoBuri | W2 | P1 | [#21](https://github.com/pmhieu1801/cross_platform_final/issues/21) - Open |
| R20 - Label management (list, add, rename, delete) | hnt0411 | pmhieu1801, CheetoBuri | W2 | P1 | [#22](https://github.com/pmhieu1801/cross_platform_final/issues/22) - Open |
| R21 - Attach labels to notes | hnt0411 | pmhieu1801, CheetoBuri | W2 | P1 | [#23](https://github.com/pmhieu1801/cross_platform_final/issues/23) - Open |
| R22 - Filter notes by labels | hnt0411 | pmhieu1801 | W2 | P1 | [#24](https://github.com/pmhieu1801/cross_platform_final/issues/24) - Open |
| R23 - Enable and disable note-password protection | CheetoBuri | pmhieu1801, hnt0411 | W3 | P0 | [#25](https://github.com/pmhieu1801/cross_platform_final/issues/25) - Open |
| R24 - Unlock notes and change note passwords | CheetoBuri | pmhieu1801, hnt0411 | W3 | P0 | [#26](https://github.com/pmhieu1801/cross_platform_final/issues/26) - Open |
| R25 - Share, receive, and manage note permissions | CheetoBuri | hnt0411, pmhieu1801 | W2 | P0 | Chuẩn bị cục bộ |
| R26 - Real-time collaboration and modification | CheetoBuri | hnt0411, pmhieu1801 | W3 | P1 | Chuẩn bị cục bộ |
| R27 - AI Summary | CheetoBuri | pmhieu1801, hnt0411 | W4 | P1 | Chuẩn bị cục bộ |
| R28 - AI Question Answering with source-note references | CheetoBuri | pmhieu1801, hnt0411 | W4 | P1 | Chuẩn bị cục bộ |
| R29 - UI, UX, accessibility, and adaptive cross-platform interface | hnt0411 | pmhieu1801, CheetoBuri | W1-W5 | P1 | Chuẩn bị cục bộ |
| R30 - Flutter architecture, state management, and automated testing | pmhieu1801 | hnt0411, CheetoBuri | W1-W5 | P0 | Chuẩn bị cục bộ |
| R31 - Offline persistence and synchronization | CheetoBuri, hnt0411 | pmhieu1801 | W3-W4 | P0 | Chuẩn bị cục bộ |
| R32 - Cross-platform build and web deployment | pmhieu1801 | hnt0411, CheetoBuri | W1-W5 | P0 | Chuẩn bị cục bộ |

## Acceptance và dependency

### R01 - User registration

- Dependency: Firebase client setup; Auth contract.
- Acceptance: Email, display name, password twice; validation; Firebase account and UID; auto-login and unverified banner. Email activation delivery is completed with R2 in W2.
- Evidence: xem m1-week1-verification.md cho W1 slice; chưa hoàn thành full rubric/DoD.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R02 - Account activation

- Dependency: R1; email delivery/link configuration.
- Acceptance: Send and handle activation link on Web/Android; persistent banner before activation, disappear after reload verification; never block unverified users from app features.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R03 - User login and logout

- Dependency: Firebase Auth Email/Password; UID isolation contract.
- Acceptance: Correct credentials establish real session; wrong credentials do not; restore on reload/restart; logout/Back/deep links stay blocked; account switch cancels old listeners.
- Evidence: xem m1-week1-verification.md cho W1 slice; chưa hoàn thành full rubric/DoD.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R04 - Password reset

- Dependency: R1; public recovery routes.
- Acceptance: Email link or OTP recovery works on both platforms; after reset user must login manually; invalid/expired action and network errors visible.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R05 - View profile and avatar

- Dependency: User contract; R3.
- Acceptance: Display current profile and avatar consistently; default avatar for absent image; no stale identity after switch.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R06 - Edit profile and avatar

- Dependency: R5; private avatar Storage rules M3.
- Acceptance: Edit display name and avatar with file validation, error/loading states and persistence across both platforms; backend ownership enforced.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R07 - Change password

- Dependency: R3; reauthentication policy.
- Acceptance: Require current password and matching new password twice; delegate secure handling to Firebase, reauthentication and post-change session behavior tested.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R08 - User preferences

- Dependency: User/preferences contract; R9/R10.
- Acceptance: Persist supported note font/color/theme preferences and restore on reopen; UI consistent with M2 layouts.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R09 - Display notes in list view

- Dependency: NoteRepository contract; R3; R8.
- Acceptance: Render account-scoped notes in list, loading/empty/error states; preserve selected view preference across compact and desktop screens.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R10 - Display notes in grid view

- Dependency: NoteRepository contract; R3; R8.
- Acceptance: Grid is default; switch to list and back; adaptive compact/tablet/desktop/Web; selected view persisted.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R11 - Create notes

- Dependency: UID/Note/NoteRepository contracts; M3 rules.
- Acceptance: Only title/content mandatory input; create uses same editor as update; persist via repository and enforce account ownership backend.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R12 - Update notes

- Dependency: R11; permission contract M3.
- Acceptance: Reuse create editor; changes persist; editable only for authorized users, failures retain valid edits with feedback.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R13 - Delete notes

- Dependency: R11; permission and attachment cleanup contracts.
- Acceptance: Confirm before deletion; cancellation changes nothing; ownership enforced and failures shown; related metadata cleanup behavior documented.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R14 - Auto-save notes and handle app lifecycle

- Dependency: R11/R12; local-store and sync contracts.
- Acceptance: Debounced autosave with saving/saved/failure feedback; pause/background/close/reopen retain latest valid changes within platform capabilities; no mandatory Save button.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R15 - Attach images/videos to notes

- Dependency: Attachment contract; M3 Storage access rules.
- Acceptance: Attach/view image and video on Web/native; validate type/size, upload failure/retry UX; unauthorized users cannot access private media.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R16 - Attach files to notes

- Dependency: Attachment contract; M3 Storage rules.
- Acceptance: Attach/open/download supported files across platforms; metadata and failure feedback; permission checks cover file bytes, not only note UI.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R17 - Pin and order notes

- Dependency: Note contract; R11/R12.
- Acceptance: Pinned state persists; pinned items sort consistently with documented ordering, including ties and reload.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R18 - Special-note status indicators

- Dependency: Note/Share/Lock/Attachment contracts.
- Acceptance: Show accurate special states such as protected/shared/attachments; responsive UI and access/revoke transitions must reflect current backend state.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R19 - Live search for notes

- Dependency: R11; permission-filtered repository.
- Acceptance: Live queries respond while typing; empty/no-result/error states; only permitted notes searchable; no locked/other-account content leak.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R20 - Label management (list, add, rename, delete)

- Dependency: Label contract; UID; M3 rules.
- Acceptance: List/add/rename/delete account labels; validate names; rename preserves associations; delete does not accidentally delete notes.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R21 - Attach labels to notes

- Dependency: R20; Note-Label relationship contract.
- Acceptance: Attach/detach label IDs with persistence; cannot use another account labels; reconcile deleted labels safely.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R22 - Filter notes by labels

- Dependency: R20/R21; repository queries.
- Acceptance: Filter permitted notes by chosen labels; show empty state and clear filter; preserve pin ordering and avoid account leakage.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R23 - Enable and disable note-password protection

- Dependency: W1 Lock flow; backend/rules; R11.
- Acceptance: Protect/unprotect notes using separate note-password flow; never plaintext or UI-only protection; test bypass and unauthorized content reads.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R24 - Unlock notes and change note passwords

- Dependency: R23; unlock-session/cache contract.
- Acceptance: Wrong password denied; authorized unlock/change succeeds; backend protects content, attachment and cache; logout/revoke ends applicable unlock context.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R25 - Share, receive, and manage note permissions

- Dependency: W1 Share contract; UID resolution; R11.
- Acceptance: Share with registered email; read/edit/revoke; denied direct API writes for read-only account; two-account Web/native evidence.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R26 - Real-time collaboration and modification

- Dependency: R25; repository events; conflict policy.
- Acceptance: Two authorized clients see edits without refresh; revoke closes access, ordering/conflicts documented; old account listeners cannot publish.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R27 - AI Summary

- Dependency: Backend secret protection; permission/unlock checks.
- Acceptance: Summarize authorized eligible notes; regenerate without overwriting note content; errors visible; LLM credentials server-only, no locked/forbidden note leak.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R28 - AI Question Answering with source-note references

- Dependency: R27; search and permission contracts.
- Acceptance: Answer from permitted eligible notes with clickable source-note references; exclude forbidden/locked notes; backend keys protected and failures handled.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R29 - UI, UX, accessibility, and adaptive cross-platform interface

- Dependency: All feature owners; responsive design contract.
- Acceptance: Consistent responsive Web/native layouts, loading/empty/error feedback, keyboard/mouse/touch and accessibility; no major overflow.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R30 - Flutter architecture, state management, and automated testing

- Dependency: All owners; contracts; CI.
- Acceptance: One project, clear layers and state; no critical analyze errors; final rubric needs 3 meaningful unit, 3 widget, 1 critical integration test. W1 verifies its own Auth slice without treating the W5 count as W1 quota.
- Evidence: xem m1-week1-verification.md cho W1 slice; chưa hoàn thành full rubric/DoD.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R31 - Offline persistence and synchronization

- Dependency: M2 local store/UI; M3 queue/retry/conflict/auth.
- Acceptance: Previously loaded notes available offline; edits durable across reopen/reconnect; pending/synced/failed and retry; isolated UID caches; documented conflict strategy on Web/native.
- Evidence: chưa kiểm chứng; owner bổ sung test Web/native, PR và demo timecode khi thực hiện.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.

### R32 - Cross-platform build and web deployment

- Dependency: Firebase access; all integrated features; hosting/signing.
- Acceptance: Same-source Web and Android build/run W1; final W5 stable public HTTPS and installable native release artifact with reproducible docs and working backend. Debug APK is not final release evidence.
- Evidence: xem m1-week1-verification.md cho W1 slice; chưa hoàn thành full rubric/DoD.
- DoD: loading/error/permission/UID isolation đúng phạm vi; relevant automated tests và hành vi Web/Android; reviewer khác xác nhận; PR merge và tracker/evidence cập nhật; schema đổi cần migration/rules/owner review.
