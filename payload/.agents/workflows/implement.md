---
description: Triển khai yêu cầu theo quy trình 10 bước — phân tích trước, code sau
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/implement-requirement.md` và thực thi đúng prompt đó.

Yêu cầu: nội dung mô tả trong yêu cầu (tham số `$ARGUMENTS`) nếu có; nếu không có thì HỎI lại.

Bắt buộc: qua đủ GIAI ĐOẠN 1 (phân tích 7 bước: đọc code → viết lại yêu cầu → acceptance criteria → edge cases → giả định → files → solution) trước. Sau bước 7, hành động theo mode trong prompt: PLAN_ONLY/STRICT thì dừng chờ duyệt; AUTO/AUTO_WITH_ESCALATION không có trigger rủi ro thì tiếp tục code ngay.
