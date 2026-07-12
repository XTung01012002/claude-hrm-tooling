---
description: Adversarial verification — kiểm định cuối cùng trước khi merge (chỉ kiểm, không sửa)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/adversarial-verify.md` và thực thi đúng prompt đó.

Input mặc định: diff hiện tại. Nếu tham số `$ARGUMENTS` chỉ định file/commit cụ thể thì dùng đó.

Yêu cầu gốc được lấy theo thứ tự ưu tiên:
1. Nội dung user truyền vào `$ARGUMENTS`.
2. Final Plan đã được xác nhận.
3. Task/spec/ticket được user chỉ định.
4. Nếu không có các nguồn trên → `BLOCKED_INSUFFICIENT_CONTEXT`. (Tuyệt đối KHÔNG dùng commit message làm nguồn sự thật cho yêu cầu gốc).

Bắt buộc: KHÔNG sửa code. Chỉ báo cáo theo format Adversarial Verification Report. Duyệt đủ 12 chiều kiểm tra.
