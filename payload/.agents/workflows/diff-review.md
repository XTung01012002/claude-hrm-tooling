---
description: Review diff → verdict → branch name → commit message → PR summary
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/diff-review.md` và thực thi đúng prompt đó.

Phạm vi: mặc định `git diff` + `git diff --staged`; nếu `$ARGUMENTS` chỉ định file diff cụ thể thì review đó. **BẮT BUỘC** chạy `git ls-files --others --exclude-standard -z` và đọc file mới liên quan để phát hiện file chưa track (KHÔNG dùng `git add`).

Bắt buộc: review diff TRƯỚC → verdict (`PASS` / `PASS_WITH_CONCERNS` / `REQUEST_CHANGES`) → rồi mới sinh branch + commit + PR summary. Chỉ đề xuất branch/commit khi verdict là `PASS` hoặc `PASS_WITH_CONCERNS` và không có bất kỳ finding nào được đánh dấu `Merge blocking: Yes`.
