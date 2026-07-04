---
description: Đối chiếu code đã implement với Plan cuối và convention HRM API
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/review-vs-plan.md` và thực thi đúng prompt đó.

Input trong `$ARGUMENTS` phải xác định Plan bản cuối (nội dung hoặc đường dẫn) và phạm vi code (PR/diff/range/file). Nếu thiếu phạm vi code thì dùng cơ chế mặc định trong prompt; nếu thiếu Plan thì yêu cầu bổ sung, không suy ngược Plan từ code.

Đây là reviewer độc lập, chỉ đọc và báo cáo: không sửa code, tạo test, format, commit hoặc đổi trạng thái Git. Bắt buộc verify từng trạng thái Plan và finding bằng code thật, ghi `file:line`; tách rõ sai lệch Plan, thay đổi ngoài Plan, vấn đề chất lượng và bằng chứng chạy test.
