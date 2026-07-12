# PROMPT: Triển khai yêu cầu — PHP Requirement Implementer (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/implement`. Với AI khác: dán file này + mô tả yêu cầu.
>
> **Đọc trước:** `docs/ai/PROJECT-CONVENTIONS.md` (đặc biệt §0 cấm bịa, §1 reuse, §2 layering, §3 khuôn feature, §11 giữ behavior).

## Nhiệm vụ
Triển khai yêu cầu theo quy trình 10 bước. **KHÔNG được code ngay.** Phải qua giai đoạn phân tích trước.

---

## GIAI ĐOẠN 1 — PHÂN TÍCH (bước 1–7, chưa sửa code)

### Bước 1: Đọc code hiện tại
- Đọc các file liên quan (Controller, Handler, Repository, Model, Validation, Test).
- `grep` xác nhận class/method/field tồn tại (§0).
- Tìm reuse candidates (§1): quét `Core/<Module>/Shared/`, `Infrastructure/<Module>/Repositories/`, `Helper.php`, `*Trait` — liệt kê interface/method có thể tái dùng.

### Bước 2: Viết lại yêu cầu
Diễn đạt lại yêu cầu theo cách AI hiểu, bằng tiếng Việt. Format:

```
## Yêu cầu (AI hiểu)
<1-3 câu mô tả mục tiêu thực sự của thay đổi>
```

### Bước 3: Xác định Acceptance Criteria
Liệt kê ít nhất 3 acceptance criteria (AC) dạng Given-When-Then:

```
## Acceptance Criteria
- AC1: Given [điều kiện], When [hành động], Then [kết quả]
- AC2: ...
- AC3: ...
```

### Bước 4: Liệt kê Happy path, Error path, Edge cases

```
## Các nhánh xử lý

### Happy path
- <mô tả luồng chính>

### Error path
- <mỗi BusinessException / validation fail / external API fail>

### Edge cases
- Null/empty input → hành vi gì?
- Duplicate request → idempotent hay lỗi?
- Race condition → cần lock?
- Webhook event trễ/lặp → downgrade status?
- Dữ liệu legacy/cũ → tương thích?
- Timezone → UTC hay local?
```

### Bước 5: Nêu giả định chưa xác minh

```
## Giả định (CẦN XÁC NHẬN)
- [ ] <giả định 1 — ảnh hưởng gì nếu sai>
- [ ] <giả định 2>
```

Nếu có giả định quan trọng (ảnh hưởng schema, API contract, behavior) → **HỎI user trước khi code** (§11).

### Bước 6: Liệt kê file dự kiến thay đổi

```
## Files dự kiến
| File | Hành động | Lý do |
|---|---|---|
| source/src/Core/.../XCommand.php | Tạo mới | DTO cho feature |
| source/src/Core/.../XHandler.php | Tạo mới | Logic nghiệp vụ |
| ... | | |
```

### Bước 7: Đề xuất giải pháp tối thiểu
Chọn giải pháp **thay đổi ít nhất** mà đạt yêu cầu. Nếu có nhiều cách → liệt kê 2-3 option, nêu trade-off, đề xuất 1.

```
## Giải pháp đề xuất
<mô tả approach chọn + lý do>

### Alternatives đã xem xét (nếu có)
- Option B: ... — không chọn vì ...
```

**⏸️ DỪNG ĐÂY — Xuất kết quả bước 1–7 cho user xem.**
Nếu có giả định cần xác nhận (bước 5), chờ user trả lời trước khi tiếp.

---

## GIAI ĐOẠN 2 — TRIỂN KHAI (bước 8–10, sau khi user đồng ý)

### Bước 8: Sửa/tạo code
- Theo khuôn feature §3: Command/Query + Handler + ValidationInterface.
- `declare(strict_types=1)`, `readonly class`, inject interface, `validate()` đầu tiên.
- `BusinessException(<message tiếng Việt>, <httpCode>)` cho lỗi nghiệp vụ.
- Reuse interface/repo có sẵn (bước 1), KHÔNG tạo mới nếu đã có.

### Bước 9: Viết/chỉnh test
- Theo prompt `docs/ai/prompts/generate-test.md` (test matrix 14 nhóm).
- Tối thiểu: happy path + mỗi nhánh BusinessException + edge cases từ bước 4.

### Bước 10: Chạy Quality Gate

```bash
# Lint syntax PHP 8.2
make -f Makefile.ai ai-lint FILE=source/path/to/File.php

# Format
make -f Makefile.ai ai-pint FILE=source/path/to/File.php

# Test
make -f Makefile.ai ai-test TEST=tests/Unit/XTest.php
```

**Bắt buộc** chạy cả 3 lệnh. Nếu fail → sửa → chạy lại.

---

## Format xuất kết quả cuối

```markdown
## Tóm tắt thay đổi
- <mô tả ngắn>

## Files đã thay đổi
| File | Hành động |
|---|---|
| ... | Tạo mới / Sửa |

## Acceptance Criteria — Kết quả
- AC1: ✅ / ❌
- AC2: ✅ / ❌

## Quality Gate
- Lint: ✅ / ❌
- Pint: ✅ / ❌
- Test: ✅ / ❌ (<n> passed, <m> failed)

## Lưu ý
- <behavior giữ nguyên>
- <rủi ro cần test thêm>
- <tài liệu cần cập nhật>
```
