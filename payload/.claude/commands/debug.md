---
description: Chẩn đoán bug một cách có hệ thống qua 6 bước (Dựng test đỏ, Thu nhỏ, Giả thuyết, Instrument, Fix, Dọn dẹp).
---
Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi đọc nội dung skill tại `.claude/skills/diagnosing-bugs/SKILL.md` (hoặc `.agents/skills/diagnosing-bugs/SKILL.md`) và thực thi đúng quy trình 6 bước đó.

Mô tả bug từ user:
$ARGUMENTS

Nếu mô tả bug chưa đủ thông tin để viết test tạo tín hiệu đỏ (Phase 1), hãy HỎI lại user, KHÔNG ĐƯỢC tự đoán mò hay sửa code.
