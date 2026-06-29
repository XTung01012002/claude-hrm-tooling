---
description: Review/refactor code PHP-Laravel theo quy trình dự án (giữ behavior, surgical, có mức độ)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/refactor.md` và thực thi đúng quy trình đó.

Đối tượng: file/class nêu trong yêu cầu (tham số `$ARGUMENTS`) nếu có; nếu không có thì xử lý đoạn code người dùng dán; nếu vẫn không rõ thì HỎI lại (đừng tự đoán).

Nguyên tắc bắt buộc: giữ nguyên behavior (không tự đổi response shape / status / message / enum / route / schema), bám code thật không bịa, ưu tiên Security → Multi-tenancy → Architecture → Validation → Transaction/Race → Bug → Performance → Clean code → Style. `kiểm tra giúp` = review trước (chưa sửa); `gửi bản hoàn chỉnh` = trả full code đã sửa. Báo cáo theo format + mức độ 🔴 Cao / 🟡 Trung bình / 🟢 Thấp trong prompt.
