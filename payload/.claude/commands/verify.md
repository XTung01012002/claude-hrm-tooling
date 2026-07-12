---
description: Adversarial verification — kiểm định cuối cùng trước khi merge (chỉ kiểm, không sửa)
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/adversarial-verify.md` và thực thi đúng prompt đó.

Input: diff hiện tại (mặc định `git diff` + `git diff --staged`; nếu tham số `$ARGUMENTS` chỉ định file/commit cụ thể thì dùng đó). **BẮT BUỘC** chạy `git status --short --untracked-files=all` trước để phát hiện file mới chưa track. Yêu cầu gốc: lấy từ commit message gần nhất hoặc từ mô tả user cung cấp.

Bắt buộc: KHÔNG sửa code. Chỉ báo cáo theo format Adversarial Verification Report. Duyệt đủ 12 chiều kiểm tra.
