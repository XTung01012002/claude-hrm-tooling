# Format xuất kết quả review (Review vs Plan)

```markdown
## KẾT QUẢ REVIEW VS PLAN: <tên task/PR hoặc phạm vi>

### Phạm vi và giới hạn

- Plan: <file/nội dung/version>
- Code: <base/range/diff/files>
- Cảnh báo/giới hạn: <nếu có>

### 1. Đối chiếu Plan

| # | Yêu cầu nguyên tử | Trạng thái | Bằng chứng | Ghi chú |
|---|---|---|---|---|
| P1 | ... | ✅/⚠️/❌/❓ | `file.php:line` | ... |

### 2. Sai lệch so với Plan

- IMPORTANT [Pxx] [Plan] `file.php:line` — vấn đề → tác động → bằng chứng → hướng sửa
- Nếu không có: Không phát hiện sai lệch đáng kể so với Plan.

### 3. Thay đổi ngoài Plan

| Vị trí | Thay đổi | Đánh giá | Hành động đề xuất |
|---|---|---|---|
| `file.php:line` | ... | Hợp lý / Cần xác nhận / Scope creep / Nguy cơ regression | ... |

- Nếu không có: Không phát hiện thay đổi ngoài Plan.

### 4. Vấn đề chất lượng implementation

- BLOCKER/IMPORTANT/SUGGESTION/QUESTION [Pxx hoặc N/A] [Chất lượng/Convention/Security/Performance] `file.php:line` — vấn đề → tác động → bằng chứng → hướng sửa
- Nếu không có: Không phát hiện vấn đề chất lượng đáng kể.

### 5. Test coverage và bằng chứng chạy

- Test tìm thấy: ...
- Đã cover: ...
- Chưa cover: ...
- Chất lượng assert: ...
- Đã chạy: `<command>` → <kết quả>; hoặc `Chưa chạy` → <lý do>

### 6. Ngoài phạm vi diff — phát hiện thêm

- <chỉ ghi bug cũ đã verify có tác động đáng kể; nếu không có thì bỏ mục này>

### 7. Verdict

✅ PASS / ⚠️ PASS_WITH_CONCERNS / ❌ REQUEST_CHANGES / 🚫 BLOCKED_INSUFFICIENT_CONTEXT

<2–3 câu nêu lý do và điều kiện cần xử lý trước khi merge.>

### 8. Đề xuất ngoài phạm vi, không bắt buộc

- ...
- Nếu không có: Không có gợi ý thêm.
```
