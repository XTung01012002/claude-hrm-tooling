---
description: Review/refactor code PHP-Laravel theo quy trình dự án (giữ behavior, surgical, có mức độ)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/refactor.md` và thực thi đúng quy trình đó.

Đối tượng: file/class nêu trong yêu cầu (tham số `$ARGUMENTS`) nếu có; nếu không có thì xử lý đoạn code người dùng dán; nếu vẫn không rõ thì HỎI lại (đừng tự đoán).

Mode thực thi (mặc định là `REVIEW_ONLY` nếu user không chỉ định):
- `REVIEW_ONLY`: Chỉ đánh giá, báo cáo lỗi và đề xuất sửa đổi, không trả về full code.
- `PATCH`: Chỉ xuất phần code thay đổi.
- `FULL_REWRITE`: Trả về toàn bộ class/file đã được refactor.

Nguyên tắc bắt buộc: giữ nguyên behavior (không tự đổi response shape / status / message / enum / route / schema), bám code thật không bịa, ưu tiên Security → Multi-tenancy → Architecture → Validation → Transaction/Race → Bug → Performance → Clean code → Style. Báo cáo theo format + severity `BLOCKER` / `IMPORTANT` / `SUGGESTION` / `QUESTION` trong prompt.
