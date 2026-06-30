---
description: Bẻ việc / bóc task / estimate theo rule HRM API (Size×Effort→Point, reuse-first, không cộng trùng, mỗi task ≤ 2 Point)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/task-breakdown.md` và thực thi đúng rule đó cho phạm vi user cung cấp (file / code snippet / User Story / task `[BE]` trong `$ARGUMENTS`).

Phạm vi: bám đúng scope user gửi, KHÔNG tự mở rộng (§1, §1.3). Thiếu thông tin nhưng vẫn xác định được phạm vi → ưu tiên estimate theo giả định và ghi rõ giả định (§1.4); chỉ hỏi lại khi thiếu thông tin làm đổi hoàn toàn phạm vi.

Bắt buộc: bám code thật để phân biệt reuse vs viết mới (§6, §6.5 — không tính lại logic interface/hàm đã có); mỗi task verify độc lập được và ≤ 2 Point (§4); chốt 1 point cụ thể theo ma trận Size×Effort, KHÔNG để range (§9); không cộng trùng logic giữa các task và giữa nhiều file trong cùng phiên (§10, §6.5). Xuất bảng `[DEV]` đúng format §14 kèm cột File/Dependency liên quan + Lý do point.
