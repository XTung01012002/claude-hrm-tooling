---
description: Review diff → verdict → branch name → commit message → PR summary
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/diff-review.md` và thực thi đúng prompt đó.

Phạm vi: mặc định là `git diff` + `git diff --staged`; nếu tham số `$ARGUMENTS` chỉ định file diff cụ thể thì review đó. **BẮT BUỘC** dùng `git ls-files --others --exclude-standard -z` để phát hiện file mới chưa track (KHÔNG dùng `git add`).

Bắt buộc: review diff TRƯỚC → verdict (`PASS` / `PASS_WITH_CONCERNS` / `REQUEST_CHANGES` / `BLOCKED_INSUFFICIENT_CONTEXT`) → rồi mới sinh branch + commit + PR summary. Không sinh commit message mà không review trước; chỉ đề xuất branch/commit khi verdict là `PASS` hoặc `PASS_WITH_CONCERNS` và không có `Merge blocking: Yes`.
