---
description: Review diff → verdict → branch name → commit message → PR summary
---

Đọc `docs/ai/PROJECT-CONVENTIONS.md` rồi `docs/ai/prompts/diff-review.md` và thực thi đúng prompt đó.

Phạm vi: mặc định là `git diff` + `git diff --staged`; nếu tham số `$ARGUMENTS` chỉ định file diff cụ thể thì review đó. **BẮT BUỘC** chạy `git status --short --untracked-files=all` trước để phát hiện file mới chưa track.

Bắt buộc: review diff TRƯỚC → verdict → rồi mới sinh branch + commit + PR summary. Không sinh commit message mà không review trước.
