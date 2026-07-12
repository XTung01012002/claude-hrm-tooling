# PROMPT: Review / Refactor code (HRM API)

> Prompt trung lập — dùng được với mọi AI. Trong Claude Code gọi qua `/refactor`. Với AI khác: dán file này + code cần xử lý.
>
> **Đọc trước & tuân thủ:** `docs/ai/PROJECT-CONVENTIONS.md` — file đó chứa toàn bộ RULE chi tiết (§0 cấm bịa, §1 reuse+DRY, §2 layering, §4 ORM, §8 multi-tenancy, §9 transaction/webhook, §10 list, §11 giữ behavior). Prompt này chỉ là **quy trình + format**, không lặp lại rule.

## Kích hoạt
Khi người dùng gửi code PHP/Laravel kèm: `refactor`, `tối ưu`, `kiểm tra giúp`, `gửi bản hoàn chỉnh`, hoặc tương tự.

## Mode Thực Thi
Theo yêu cầu của người dùng, xác định mode:
- **REVIEW_ONLY** (Mặc định nếu user không chỉ định rõ): Chỉ soát lỗi, đánh giá và đề xuất cách sửa (không xuất toàn bộ code).
- **PATCH**: Chỉ xuất snippet / diff phần code thay đổi.
- **FULL_REWRITE**: Xuất toàn bộ file / class đã refactor đầy đủ.

## Mặc định
- Review / refactor **THEO logic hiện tại** — KHÔNG tự đổi nghiệp vụ, KHÔNG thêm feature ngoài yêu cầu, KHÔNG lan sang phần không liên quan.
- **Refactor = giữ nguyên behavior, làm code sạch hơn.** (Không phải viết lại.)
- Trước khi sửa, xác định behavior gốc (§11): input/null/empty, exception, status, response shape, query filter, event/transaction. Thiếu thông tin có thể đổi behavior → **HỎI trước**.

## Thứ tự ưu tiên khi soát
1. Security  2. Multi-tenancy / data isolation (§8)  3. Architecture (§2)  4. Validation  5. Transaction / race (§9)  6. Bug  7. Performance (N+1, §10)  8. Clean code (DRY §1, early-return, bớt nested, enum thay magic string)  9. Laravel/Pint style.

> Không làm code "đẹp" nếu có nguy cơ đổi behavior. Không over-engineer (§1).

## Cấm bịa (§0)
Mọi nhận định phải truy được về code thật (đọc/grep). Không chắc symbol có tồn tại → xác nhận rồi mới kết luận.

## Format trả lời

**Khi ở mode REVIEW_ONLY**:
```markdown
## Kết luận
<1-2 câu: có/không vấn đề nghiêm trọng>

## Vấn đề
### [🔴/🟡/🟢] <tên vấn đề>
- Vị trí: `file.php:line`
- Vấn đề: <mô tả, đã verify bằng ...>
- Ảnh hưởng:
- Đề xuất:
```php
// code sửa
```

## Ghi chú
<điểm ngoài phạm vi — chỉ nêu, không tự sửa>
```

**Khi ở mode FULL_REWRITE hoặc PATCH**:
```markdown
## Điểm refactor chính
- <giữ logic / tách DRY / bớt nested / gom validate — KHÔNG đổi response shape>

## Bản đã refactor
```php
// full code
```

## Lưu ý
- Behavior giữ nguyên: ...
- Rủi ro cần bạn confirm (nếu có): ...
```

## Mức độ
- **🔴 Cao**: lỗi production / security / sai hoặc mất dữ liệu / rò rỉ tenant.
- **🟡 Trung bình**: bug edge-case, khó maintain, performance kém.
- **🟢 Thấp**: style, readability, cleanup nhỏ.
