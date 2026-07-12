---
description: Bẻ việc / bóc task / estimate theo rule HRM API (Size×Effort→Point, reuse-first, không cộng trùng, mỗi task ≤ 2 Point)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi áp dụng skill `task-breakdown` tại `.agents/skills/task-breakdown/SKILL.md` và các tài liệu tham khảo trong skill đó để thực thi.

Phạm vi: bám đúng scope user gửi, KHÔNG tự mở rộng. Thiếu thông tin nhưng vẫn xác định được phạm vi → ưu tiên estimate theo giả định và ghi rõ giả định; chỉ hỏi lại khi thiếu thông tin làm đổi hoàn toàn phạm vi.

Bắt buộc: bám code thật để phân biệt reuse vs viết mới; mỗi task verify độc lập được và ≤ 2 Point; chốt 1 point cụ thể theo ma trận Size×Effort, KHÔNG để range; không cộng trùng logic giữa các task và giữa nhiều file trong cùng phiên. Xuất bảng `[DEV]` đúng format kèm cột File/Dependency liên quan + Lý do point.
