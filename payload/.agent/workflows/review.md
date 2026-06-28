---
description: Review diff hiện tại theo checklist riêng của HRM API (reuse/layering/ORM/bẫy/convention)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/review.md` và thực thi đúng prompt đó trên thay đổi hiện tại.

Phạm vi review: output của `git diff` (nếu user nêu file/đường dẫn cụ thể trong `$ARGUMENTS` thì review phần đó).

Bắt buộc: verify mỗi finding bằng đọc/grep code thật trước khi báo (đặc biệt trước khi gắn mức Cao) — không suy đoán, không bịa. Xuất kết quả nhóm theo mức Cao / Trung bình / Thấp kèm `file:line` và cách sửa.
