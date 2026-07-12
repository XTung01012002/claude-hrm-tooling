# PROMPT: Review diff + sinh commit / branch (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/diff-review`. Với AI khác: dán file này + diff cần review.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` (đặc biệt §0 cấm bịa, §11 giữ behavior).

## Nhiệm vụ
Khi nhận diff (từ `git diff`, file diff dán vào, hoặc yêu cầu review thay đổi hiện tại): **review trước, sinh commit/branch sau**.

**KHÔNG được sinh commit message mà không review diff.**

---

## Bước 0 (BẮT BUỘC trước mọi bước khác): Thu thập ĐẦY ĐỦ thay đổi

`git diff` **không thấy file untracked** (file mới chưa `git add`). Vì vậy:

1. Chạy `git ls-files --others --exclude-standard -z` trước.
2. Đọc trực tiếp các file untracked liên quan để review cùng, KHÔNG yêu cầu user chạy `git add -A`.

Input sẽ bao gồm:
- `git diff`
- `git diff --staged`
- Nội dung các file untracked (đọc trực tiếp)
4. Nếu **không có thay đổi gì** (cả diff lẫn untracked): cảnh báo user, dừng.

> ⚠️ Bỏ qua bước này = có thể review thiếu toàn bộ file mới.

---

## Quy trình 6 bước

### Bước 1: Đọc và review diff
Áp dụng checklist từ `docs/ai/prompts/review.md` (11 mục: reuse, layering, convention, ORM, DRY, multi-tenancy, transaction, list, giữ behavior, bẫy, test).

### Bước 2: Xác định mục tiêu thực sự của thay đổi
- Thay đổi này **thực sự** làm gì? (không phải commit message tự nhận)
- Thuộc loại gì: `fix` | `feat` | `refactor` | `test` | `docs` | `chore`?
- Scope: module/feature nào bị ảnh hưởng?

### Bước 3: Kiểm tra thiếu / thừa
- Có file **cần sửa nhưng chưa sửa** không? (vd: sửa Handler mà chưa sửa test, sửa API mà chưa sửa docs)
- Có thay đổi **ngoài phạm vi** yêu cầu không? (scope creep)
- Có sửa **response shape / enum / status** ngoài yêu cầu không? (§11)

### Bước 4: Kiểm tra test và docs
- Logic thay đổi có test tương ứng chưa?
- API contract thay đổi có docs FE cập nhật chưa? (`api-docs/`)
- Code docs cần cập nhật không? (`docs/`)

### Bước 5: Kết luận có thể commit hay chưa

```
### Review Status: ✅ PASS | ⚠️ PASS WITH CONCERNS | ❌ REQUEST CHANGES
```

Nếu `REQUEST CHANGES`: liệt kê cụ thể phải sửa gì trước khi commit.

### Bước 6: Sinh branch name + commit message + PR summary

**Chỉ sinh khi status = PASS hoặc PASS WITH CONCERNS.**

---

## Format đầu ra

```markdown
## Review Diff

### Review Status: ✅ PASS | ⚠️ PASS WITH CONCERNS | ❌ REQUEST CHANGES

### Change Type: fix | feat | refactor | test | docs | chore

### Scope: <Module/Feature>

### Findings (nếu có)

#### 🔴 Blocker
- [file.php:line] <vấn đề> → <cách sửa>

#### 🟡 Important
- ...

#### 🟢 Suggestion
- ...

### Files that may still need changes
- <file> — lý do

### Tests that should be added
- test_<scenario>_<outcome> — lý do

### Remaining risks
- <mô tả rủi ro> — mức độ ảnh hưởng

---

### Suggested branch
`<type>/<module>-<mô-tả-ngắn>`

Ví dụ: `fix/zalo-system-message-reminder`, `feat/omnichannel-send-broadcast`

### Suggested commit
```
<type>(<scope>): <message tiếng Việt súc tích>

- <bullet 1 mô tả thay đổi chính>
- <bullet 2>
- <bullet 3 nếu cần>
```

Convention: `type(scope): message tiếng Việt` (tham khảo commit mẫu `0f366572`).

### PR Summary (nếu cần)
```
## Mô tả
<1-2 câu mục tiêu>

## Thay đổi
- <liệt kê file + thay đổi chính>

## Test
- <test nào đã chạy>

## Lưu ý cho reviewer
- <rủi ro / breaking change / cần test thêm>
```
```

## Quy tắc

1. **Branch + commit phải phản ánh diff thực tế**, không chỉ phản ánh mô tả user gửi kèm.
2. **Commit message tiếng Việt**, súc tích, mô tả sự thay đổi thay vì liệt kê file.
3. **Không sinh commit nếu diff có Blocker** — yêu cầu sửa trước.
4. **Nếu diff trống**: cảnh báo user, kiểm tra cả `git diff --staged` và `git ls-files --others --exclude-standard -z`.
