---
description: Sinh tài liệu API contract-only cho FE vào api-docs/<Module>/<Endpoint>.md
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/generate-api-docs.md` và thực thi đúng prompt đó.

Endpoint cần viết docs: tên Controller/đường dẫn nêu trong yêu cầu (tham số `$ARGUMENTS`) nếu có. Nếu người dùng chưa chỉ định Controller hoặc endpoint thì hỏi lại để xác định phạm vi; không tự suy luận endpoint từ `git diff` và không tự mở rộng sang Controller khác.

Bắt buộc bám code thật: đọc Controller → Command/Query → **Validation implementation** (không phải Interface) → Handler → Resource/Mapper (nếu Controller có bọc) để lấy đúng field/rule/response/lỗi. Không bịa field. Ghi 1 file/endpoint vào `api-docs/<Module>/<Endpoint>.md` theo khuôn contract-only, văn phong ngắn gọn, không thừa; cập nhật `api-docs/README.md`.
